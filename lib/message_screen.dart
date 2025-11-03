// lib/message_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/scheduler.dart';

const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C);

class MessageScreen extends StatefulWidget {
  final String? targetUserId;
  final String? targetUserName;

  const MessageScreen({super.key, this.targetUserId, this.targetUserName});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  User? _currentUser;

  String? _chatId;
  String _currentUserName = 'Bạn';

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      // SỬA: Lấy tên người dùng từ Firestore
      _firestore.collection('users').doc(_currentUser!.uid).get().then((doc) {
        if (mounted && doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _currentUserName = data['displayName'] ?? 'Bạn';
          });
        }
      });
      _getOrCreateChatId();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _getOrCreateChatId() async {
    if (_currentUser == null) return;

    if (widget.targetUserId == null) {
      if (mounted) setState(() => _chatId = 'LIST_VIEW');
      return;
    }

    final currentUserId = _currentUser!.uid;
    final targetUserId = widget.targetUserId!;
    final participants = [currentUserId, targetUserId]..sort();

    final querySnapshot = await _firestore.collection('chats').where('participants', isEqualTo: participants).limit(1).get();

    if (querySnapshot.docs.isNotEmpty) {
      if (mounted) setState(() => _chatId = querySnapshot.docs.first.id);
    } else {
      final newChat = await _firestore.collection('chats').add({
        'participants': participants,
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() => _chatId = newChat.id);
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _chatId == null || _currentUser == null || _chatId == 'LIST_VIEW') return;

    // SỬA: Đảm bảo _currentUserName đã được cập nhật trước khi gửi
    final messageContent = {
      'senderId': _currentUser!.uid,
      'senderName': _currentUserName, // Tên này đã được lấy từ Firestore
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'isRead': false,
    };

    try {
      await _firestore.collection('chats').doc(_chatId).collection('messages').add(messageContent);
      await _firestore.collection('chats').doc(_chatId).update({
        'lastMessage': text,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });
      _messageController.clear();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi: Không thể gửi tin nhắn.'), backgroundColor: topazColor));
    }
  }
  Widget _buildMessageBubble(String senderId, String text, Timestamp timestamp) {
    final bool isMe = senderId == _currentUser?.uid;
    final String timeString = TimeOfDay.fromDateTime(timestamp.toDate()).format(context);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? topazColor.withOpacity(0.9) : darkSurface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15), topRight: const Radius.circular(15),
            bottomLeft: isMe ? const Radius.circular(15) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(15),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(text, style: TextStyle(color: isMe ? Colors.black : Colors.white)),
            const SizedBox(height: 4),
            Text(timeString, style: TextStyle(color: isMe ? Colors.black.withOpacity(0.6) : sonicSilver, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // =======================================================
  // WIDGET BODY ĐÃ ĐƯỢC SỬA ĐỂ XỬ LÝ 2 TRƯỜNG HỢP
  // =======================================================
  Widget _buildChatBody() {
    if (_chatId == null || _currentUser == null) {
      return const Center(child: CircularProgressIndicator(color: topazColor));
    }

    // --- TRƯỜNG HỢP 1: HIỂN THỊ DANH SÁCH CÁC CUỘC TRÒ CHUYỆN ---
    if (_chatId == 'LIST_VIEW') {
      return StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('chats').where('participants', arrayContains: _currentUser!.uid).orderBy('lastMessageTimestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: topazColor));
          if (snapshot.hasError) return Center(child: Text('Lỗi: ${snapshot.error}', style: const TextStyle(color: coralRed)));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Chưa có cuộc trò chuyện nào.', style: TextStyle(color: sonicSilver)));

          final chatDocs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: chatDocs.length,
            itemBuilder: (context, index) => _ChatListItem(chatDoc: chatDocs[index]),
          );
        },
      );
    }

    // --- TRƯỜDNG HỢP 2: HIỂN THỊ NỘI DUNG MỘT CUỘC TRÒ CHUYỆN CỤ THỂ ---
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('chats').doc(_chatId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: topazColor));
        if (snapshot.hasError) return Center(child: Text('Lỗi tải tin nhắn: ${snapshot.error}', style: const TextStyle(color: coralRed)));

        final messages = snapshot.data?.docs ?? [];
        if (messages.isEmpty) return Center(child: Text('Bắt đầu cuộc trò chuyện với ${widget.targetUserName ?? 'người này'}!', style: TextStyle(color: sonicSilver)));

        return ListView.builder(
          reverse: true, controller: _scrollController, padding: const EdgeInsets.only(top: 10, bottom: 10),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final data = messages[index].data() as Map<String, dynamic>;
            return _buildMessageBubble(data['senderId'] ?? '', data['text'] ?? '', data['timestamp'] ?? Timestamp.now());
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isListView = _chatId == 'LIST_VIEW';
    final title = isListView ? 'Tin nhắn' : (widget.targetUserName ?? widget.targetUserId ?? 'Đang tải...');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black, elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(child: _buildChatBody()),
          // Chỉ hiển thị ô nhập liệu khi đang trong cuộc trò chuyện cụ thể
          if (!isListView)
            Container(
              padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
              color: darkSurface.withOpacity(0.5),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController, onSubmitted: (_) => _sendMessage(), style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn...', hintStyle: TextStyle(color: sonicSilver.withOpacity(0.7)),
                        filled: true, fillColor: darkSurface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 22, backgroundColor: topazColor,
                    child: IconButton(icon: const Icon(Icons.send, color: Colors.black, size: 20), onPressed: _sendMessage),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ====================================================================
// WIDGET MỚI: ĐỂ HIỂN THỊ MỘT DÒNG TRONG DANH SÁCH CHAT
// ====================================================================
// THAY THẾ TOÀN BỘ WIDGET NÀY
class _ChatListItem extends StatelessWidget {
  final DocumentSnapshot chatDoc;
  const _ChatListItem({required this.chatDoc});

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    final data = chatDoc.data() as Map<String, dynamic>;
    final List<dynamic> participants = data['participants'];
    final String otherUserId = participants.firstWhere((id) => id != currentUser.uid, orElse: () => '');
    final String lastMessage = data['lastMessage'] ?? '';

    if (otherUserId.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(otherUserId).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const ListTile(title: Text('Đang tải...', style: TextStyle(color: sonicSilver)));

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        // SỬA Ở ĐÂY
        final String targetUserName = userData['displayName'] ?? 'Người dùng';
        // VÀ SỬA Ở ĐÂY
        final String? targetAvatarUrl = userData['photoURL'] as String?;

        return ListTile(
          leading: CircleAvatar(
            radius: 25,
            backgroundColor: darkSurface,
            backgroundImage: (targetAvatarUrl != null && targetAvatarUrl.isNotEmpty) ? NetworkImage(targetAvatarUrl) : null,
            child: (targetAvatarUrl == null || targetAvatarUrl.isEmpty) ? Text(targetUserName.isNotEmpty ? targetUserName[0] : 'U', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null,
          ),
          title: Text(targetUserName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text(lastMessage, style: const TextStyle(color: sonicSilver), maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => MessageScreen(targetUserId: otherUserId, targetUserName: targetUserName)),
            );
          },
        );
      },
    );
  }
}
// lib/message_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/scheduler.dart';

const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C);

// =======================================================
// Main Screen Widget (Router)
// =======================================================
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
  User? _currentUser;
  String? _chatId;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _getOrCreateChatId();
  }

  Future<void> _getOrCreateChatId() async {
    if (_currentUser == null) return;

    // Case 1: No target user, show the list of chats.
    if (widget.targetUserId == null) {
      if (mounted) setState(() => _chatId = 'LIST_VIEW');
      return;
    }

    // Case 2: Target user is provided, find or create the chat.
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

  @override
  Widget build(BuildContext context) {
    final bool isListView = (_chatId == 'LIST_VIEW');
    final String title = isListView
        ? 'Tin nhắn'
        : (widget.targetUserName ?? widget.targetUserId ?? 'Đang tải...');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_chatId == null || _currentUser == null) {
      return const Center(child: CircularProgressIndicator(color: topazColor));
    }

    if (_chatId == 'LIST_VIEW') {
      return _ChatListView(currentUser: _currentUser!);
    }

    // Otherwise, it's a conversation view
    return _ConversationView(
      chatId: _chatId!,
      currentUser: _currentUser!,
      targetUserName: widget.targetUserName ?? 'Người dùng',
    );
  }
}

// =======================================================
// Widget for displaying the list of all chats
// =======================================================
class _ChatListView extends StatelessWidget {
  final User currentUser;
  const _ChatListView({required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .orderBy('lastMessageTimestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: topazColor));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}', style: const TextStyle(color: coralRed)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Chưa có cuộc trò chuyện nào.', style: TextStyle(color: sonicSilver)));
        }

        final chatDocs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: chatDocs.length,
          itemBuilder: (context, index) => _ChatListItem(chatDoc: chatDocs[index]),
        );
      },
    );
  }
}

// =======================================================
// Widget for a single conversation
// =======================================================
class _ConversationView extends StatefulWidget {
  final String chatId;
  final User currentUser;
  final String targetUserName;

  const _ConversationView({required this.chatId, required this.currentUser, required this.targetUserName});

  @override
  State<_ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<_ConversationView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _currentUserName = 'Bạn';

  @override
  void initState() {
    super.initState();
    // Fetch the current user's display name
    _firestore.collection('users').doc(widget.currentUser.uid).get().then((doc) {
      if (mounted && doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _currentUserName = data['displayName'] ?? 'Bạn';
        });
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final messageContent = {
      'senderId': widget.currentUser.uid,
      'senderName': _currentUserName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'isRead': false,
    };

    try {
      await _firestore.collection('chats').doc(widget.chatId).collection('messages').add(messageContent);
      await _firestore.collection('chats').doc(widget.chatId).update({
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('chats').doc(widget.chatId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: topazColor));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Lỗi tải tin nhắn: ${snapshot.error}', style: const TextStyle(color: coralRed)));
              }

              final messages = snapshot.data?.docs ?? [];
              if (messages.isEmpty) {
                return Center(child: Text('Bắt đầu cuộc trò chuyện với ${widget.targetUserName}!', style: const TextStyle(color: sonicSilver)));
              }

              return ListView.builder(
                reverse: true,
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final data = messages[index].data() as Map<String, dynamic>;
                  return _MessageBubble(
                    senderId: data['senderId'] ?? '',
                    text: data['text'] ?? '',
                    timestamp: data['timestamp'] ?? Timestamp.now(),
                    isMe: (data['senderId'] ?? '') == widget.currentUser.uid,
                  );
                },
              );
            },
          ),
        ),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
      color: darkSurface.withOpacity(0.5),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              onSubmitted: (_) => _sendMessage(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Nhập tin nhắn...',
                hintStyle: TextStyle(color: sonicSilver.withOpacity(0.7)),
                filled: true,
                fillColor: darkSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 22,
            backgroundColor: topazColor,
            child: IconButton(icon: const Icon(Icons.send, color: Colors.black, size: 20), onPressed: _sendMessage),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// Widget for a single message bubble
// =======================================================
class _MessageBubble extends StatelessWidget {
  final String senderId;
  final String text;
  final Timestamp timestamp;
  final bool isMe;

  const _MessageBubble({required this.senderId, required this.text, required this.timestamp, required this.isMe});

  @override
  Widget build(BuildContext context) {
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
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
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
}

// ===================================================================
// WIDGET MỚI: ĐỂ HIỂN THỊ MỘT DÒNG TRONG DANH SÁCH CHAT (STATEFUL)
// ===================================================================
class _ChatListItem extends StatefulWidget {
  final DocumentSnapshot chatDoc;
  const _ChatListItem({required this.chatDoc});

  @override
  State<_ChatListItem> createState() => _ChatListItemState();
}

class _ChatListItemState extends State<_ChatListItem> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  DocumentSnapshot? _otherUserDoc;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _fetchOtherUserData();
  }

  Future<void> _fetchOtherUserData() async {
    if (_currentUser == null) return;
    if (!mounted) return; // Add guard

    final data = widget.chatDoc.data() as Map<String, dynamic>;
    final List<dynamic> participants = data['participants'];
    final String otherUserId = participants.firstWhere((id) => id != _currentUser!.uid, orElse: () => '');

    if (otherUserId.isNotEmpty) {
      final userDoc = await _firestore.collection('users').doc(otherUserId).get();
      if (mounted) {
        setState(() {
          _otherUserDoc = userDoc;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Refresh data when navigating back
  void _onNavigateBack() {
    _fetchOtherUserData();
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ListTile(
        title: Text('Đang tải...', style: TextStyle(color: sonicSilver)),
        subtitle: Text('...', style: TextStyle(color: sonicSilver)),
        leading: CircleAvatar(radius: 25, backgroundColor: darkSurface),
      );
    }
    if (_otherUserDoc == null || !_otherUserDoc!.exists) {
      return const SizedBox.shrink(); // Or a placeholder for a deleted user
    }

    final userData = _otherUserDoc!.data() as Map<String, dynamic>;
    final String targetUserName = userData['displayName'] ?? 'Người dùng';
    final String? targetAvatarUrl = userData['photoURL'] as String?;
    final String lastMessage = (widget.chatDoc.data() as Map<String, dynamic>)['lastMessage'] ?? '';

    return ListTile(
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: darkSurface,
        backgroundImage: (targetAvatarUrl != null && targetAvatarUrl.isNotEmpty) ? NetworkImage(targetAvatarUrl) : null,
        child: (targetAvatarUrl == null || targetAvatarUrl.isEmpty)
            ? Text(targetUserName.isNotEmpty ? targetUserName[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            : null,
      ),
      title: Text(targetUserName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text(lastMessage, style: const TextStyle(color: sonicSilver), maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => MessageScreen(targetUserId: _otherUserDoc!.id, targetUserName: targetUserName)),
        ).then((_) => _onNavigateBack()); // Refresh on return
      },
    );
  }
}

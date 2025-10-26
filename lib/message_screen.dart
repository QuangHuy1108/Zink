// lib/message_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/scheduler.dart'; // Thêm import Scheduler

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
  final ScrollController _scrollController = ScrollController(); // Để cuộn xuống dưới
  User? _currentUser;

  // Trạng thái cục bộ
  String? _chatId;
  String _currentUserName = 'Bạn';

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _currentUserName = _currentUser!.displayName ?? _currentUser!.email?.split('@').first ?? 'Bạn';
      _getOrCreateChatId(); // Bắt đầu tìm kiếm/tạo Chat ID
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // =======================================================
  // 1. LOGIC XỬ LÝ CHAT ID (Tìm kiếm hoặc Tạo mới)
  // =======================================================
  Future<void> _getOrCreateChatId() async {
    if (_currentUser == null) return;

    // FIX 1: Nếu không có targetUserId, đặt một giá trị đặc biệt và thoát.
    if (widget.targetUserId == null) {
      if (mounted) {
        setState(() {
          _chatId = 'LIST_VIEW'; // Giá trị đặc biệt
        });
      }
      return;
    }

    final currentUserId = _currentUser!.uid;
    final targetUserId = widget.targetUserId!;
    final participants = [currentUserId, targetUserId]..sort();

    // Bước 1: Tìm kiếm cuộc trò chuyện
    final querySnapshot = await _firestore.collection('chats')
        .where('participants', isEqualTo: participants)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      // Đã tìm thấy
      if (mounted) {
        setState(() {
          _chatId = querySnapshot.docs.first.id;
        });
      }
    } else {
      // Chưa có: Tạo một cuộc trò chuyện mới
      final newChat = await _firestore.collection('chats').add({
        'participants': participants,
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() {
          _chatId = newChat.id;
        });
      }
    }
  }

  // =======================================================
  // 2. LOGIC GỬI TIN NHẮN
  // =======================================================
  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _chatId == null || _currentUser == null) return;

    final messageContent = {
      'senderId': _currentUser!.uid,
      'senderName': _currentUserName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'isRead': false,
    };

    try {
      // 1. Gửi tin nhắn vào subcollection
      await _firestore.collection('chats').doc(_chatId).collection('messages').add(messageContent);

      // 2. Cập nhật lastMessage trên document chat
      await _firestore.collection('chats').doc(_chatId).update({
        'lastMessage': text,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });

      // 3. Xóa nội dung và cuộn xuống
      _messageController.clear();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    } catch (e) {
      print("Lỗi gửi tin nhắn: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi: Không thể gửi tin nhắn.'), backgroundColor: topazColor));
    }
  }


  // MOCK WIDGET -> WIDGET THẬT: Hiển thị một tin nhắn trong cuộc trò chuyện
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

  // =======================================================
  // 3. WIDGET BODY VÀ STREAM BUILDER
  // =======================================================
  Widget _buildChatBody() {
    if (_chatId == null) {
      return const Center(child: CircularProgressIndicator(color: topazColor));
    }

    // FIX 2: Hiển thị placeholder nếu đang ở chế độ danh sách chat
    if (_chatId == 'LIST_VIEW') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.forum_outlined, color: sonicSilver, size: 60),
              const SizedBox(height: 16),
              Text('Đây là danh sách các cuộc trò chuyện của bạn.', style: TextStyle(color: sonicSilver, fontSize: 16), textAlign: TextAlign.center,),
              Text('Bạn cần điều hướng từ hồ sơ của một người bạn để bắt đầu trò chuyện 1-1.', style: TextStyle(color: sonicSilver.withOpacity(0.7), fontSize: 14), textAlign: TextAlign.center,),
            ],
          ),
        ),
      );
    }

    // StreamBuilder để lắng nghe các tin nhắn
    return StreamBuilder<QuerySnapshot>(
      // ... (Giữ nguyên logic StreamBuilder)
      stream: _firestore.collection('chats').doc(_chatId).collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: topazColor));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi tải tin nhắn: ${snapshot.error}', style: const TextStyle(color: coralRed)));
        }

        final messages = snapshot.data?.docs ?? [];
        if (messages.isEmpty) {
          return Center(child: Text('Bắt đầu cuộc trò chuyện với ${widget.targetUserName ?? 'người này'}!', style: TextStyle(color: sonicSilver)));
        }

        return ListView.builder(
          reverse: true,
          controller: _scrollController,
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final doc = messages[index];
            final data = doc.data() as Map<String, dynamic>;
            final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
            return _buildMessageBubble(
              data['senderId'] as String? ?? '',
              data['text'] as String? ?? 'Tin nhắn trống',
              timestamp,
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final String title = widget.targetUserName ?? widget.targetUserId ?? 'Tin nhắn';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        // THỐNG NHẤT NÚT BACK
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
          splashRadius: 28,
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // Khu vực hiển thị tin nhắn (Đã triển khai StreamBuilder)
          Expanded(
            child: _buildChatBody(),
          ),
          // Input gửi tin nhắn
          Container(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
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
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.black, size: 20),
                    onPressed: _sendMessage, // Gọi hàm gửi tin nhắn thật
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// lib/message_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);

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

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
  }

  // MOCK WIDGET: Hiển thị một tin nhắn trong cuộc trò chuyện
  Widget _buildMessageBubble(String senderName, String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(senderName, style: TextStyle(fontWeight: FontWeight.bold, color: topazColor.withOpacity(0.8), fontSize: 12)),
            Text(text, style: TextStyle(color: isMe ? Colors.black : Colors.white)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.targetUserName ?? widget.targetUserId ?? 'Tin nhắn';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // Khu vực hiển thị tin nhắn (Placeholder)
          Expanded(
            child: ListView(
              reverse: true, // Tin nhắn mới nhất ở dưới
              padding: const EdgeInsets.only(top: 10),
              children: [
                _buildMessageBubble("Bạn", "Tôi đang kiểm tra chức năng nhắn tin.", true),
                _buildMessageBubble(title, "Chào! Rất vui được tương tác với bạn.", false),
                _buildMessageBubble("Bạn", "Chức năng tìm kiếm và kết bạn có vẻ hoạt động tốt.", true),
              ].reversed.toList(), // Đảo ngược thứ tự để hiển thị theo thời gian
            ),
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
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tin nhắn đã được gửi (Mock).')));
                      // TODO: Implement actual send message logic
                    },
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

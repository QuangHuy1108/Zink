// lib/add_reel_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

import 'utils/app_colors.dart';

class AddReelScreen extends StatefulWidget {
  const AddReelScreen({super.key});

  @override
  State<AddReelScreen> createState() => _AddReelScreenState();
}

class _AddReelScreenState extends State<AddReelScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController(); // ĐÃ THÊM: Tags Controller
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  File? _selectedVideo;
  bool _isLoading = false;
  String _privacy = 'Công khai';

  Future<void> _pickVideo() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đang mở thư viện video... (Giả lập)')),
    );
  }

  // SỬA HÀM NÀY
  Future<void> _uploadReel() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    final description = _descriptionController.text.trim(); // <-- Lấy mô tả
    final List<String> tags = _tagsController.text.trim()
        .toLowerCase()
        .split(RegExp(r'[,\s]+'))
        .where((tag) => tag.isNotEmpty)
        .toList();

    try {
      // 1. Lấy thông tin người dùng (tương tự Post)
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      String displayName;
      String? userAvatarUrl;
      String username; // <-- Biến mới

      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data() as Map<String, dynamic>;
        displayName = userData['displayName'] ?? 'Người dùng Zink';
        userAvatarUrl = userData['photoURL'];
        username = userData['username'] ?? user.email?.split('@').first ?? 'user'; // <-- Lấy username
      } else {
        displayName = user.displayName ?? 'Người dùng Zink';
        userAvatarUrl = user.photoURL;
        username = user.email?.split('@').first ?? 'user'; // <-- Lấy username (dự phòng)
      }

      String mockVideoUrl = 'https://example.com/video.mp4';
      String mockThumbnailUrl = 'https://example.com/thumbnail.jpg';

      // 2. Tạo Reel mới
      final newReelRef = await _firestore.collection('reels').add({
        'uid': user.uid,
        'displayName': displayName,
        'userAvatarUrl': userAvatarUrl ?? '',
        'username': username, // <-- Lưu username
        'desc': description,
        'videoUrl': mockVideoUrl,
        'thumbnailUrl': mockThumbnailUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'privacy': _privacy,
        'likesCount': 0,
        'commentsCount': 0,
        'sharesCount': 0,
        'likedBy': [],
        'savedBy': [],
        'tags': tags,
      });

      final newReelId = newReelRef.id;

      // --- BẮT ĐẦU LOGIC GỬI THÔNG BÁO TAG ---
      final WriteBatch tagBatch = _firestore.batch();

      // 3. Phân tích mô tả (description) để tìm tag @username
      RegExp tagRegex = RegExp(r'@([a-zA-Z0-9_]+)');
      List<String> mentionedUsernames = tagRegex.allMatches(description)
          .map((match) => match.group(1)!)
          .toSet()
          .toList();

      List<String> mentionedUserIds = [];
      if (mentionedUsernames.isNotEmpty) {
        // 4. Truy vấn CSDL để lấy ID
        final usersSnapshot = await _firestore.collection('users')
            .where('username', whereIn: mentionedUsernames.take(30).toList())
            .get();
        mentionedUserIds = usersSnapshot.docs.map((doc) => doc.id).toList();
      }

      // 5. Gửi thông báo cho từng người được tag
      for (String userIdToNotify in mentionedUserIds) {
        if (userIdToNotify != user.uid) { // Không tự tag chính mình
          final tagNotificationRef = _firestore
              .collection('users')
              .doc(userIdToNotify) // Gửi cho người được tag
              .collection('notifications')
              .doc();

          tagBatch.set(tagNotificationRef, {
            'type': 'tag_reel', // <-- Loại thông báo mới
            'senderId': user.uid,
            'senderName': displayName,
            'senderAvatarUrl': userAvatarUrl,
            'destinationId': newReelId, // ID của Reel vừa tạo
            'contentPreview': 'đã nhắc đến bạn trong một Reel.',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
      }

      // 6. Thực thi batch thông báo
      await tagBatch.commit();
      // --- KẾT THÚC LOGIC GỬI THÔNG BÁO TAG ---

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng Reel thành công!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xảy ra lỗi: $e'), backgroundColor: coralRed),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _pickVideo,
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: darkSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: sonicSilver.withOpacity(0.5), width: 1),
                        ),
                        child: _selectedVideo == null
                            ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.video_library_outlined, color: sonicSilver, size: 50),
                              SizedBox(height: 8),
                              Text('Nhấn để chọn video', style: TextStyle(color: sonicSilver)),
                            ],
                          ),
                        )
                            : Center(child: Text('Đã chọn video (Placeholder)', style: TextStyle(color: Colors.white))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Viết mô tả cho Reel của bạn...',
                      hintStyle: TextStyle(color: sonicSilver.withOpacity(0.7)),
                      filled: true,
                      fillColor: darkSurface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ĐÃ THÊM: TRƯỜNG NHẬP TAGS
                  TextField(
                    controller: _tagsController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Thêm tags (ví dụ: #funny, #trending)',
                      hintStyle: TextStyle(color: sonicSilver.withOpacity(0.7)),
                      filled: true,
                      fillColor: darkSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  // KẾT THÚC THÊM: TRƯỜNG NHẬP TAGS
                  const SizedBox(height: 20),
                  const Text('Ai có thể xem Reel này?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _buildPrivacyOption('Công khai', Icons.public, 'Mọi người trên Zink'),
                  _buildPrivacyOption('Bạn bè', Icons.people, 'Chỉ những người bạn theo dõi'),
                  _buildPrivacyOption('Chỉ mình tôi', Icons.lock, 'Chỉ mình bạn có thể xem'),
                ],
              ),
            ),
          ),
          _buildPostButton(),
        ],
      ),
    );
  }

  Widget _buildPrivacyOption(String value, IconData icon, String subtitle) {
    return RadioListTile<String>(
      title: Text(value, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: sonicSilver)),
      secondary: Icon(icon, color: sonicSilver),
      value: value,
      groupValue: _privacy,
      onChanged: (newValue) {
        if (newValue != null) {
          setState(() {
            _privacy = newValue;
          });
        }
      },
      activeColor: topazColor,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildPostButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0).copyWith(bottom: MediaQuery.of(context).padding.bottom + 8.0),
      width: double.infinity,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: topazColor))
          : ElevatedButton(
        onPressed: _uploadReel,
        style: ElevatedButton.styleFrom(
          backgroundColor: topazColor,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Đăng Reel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
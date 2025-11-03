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

    try {
      // Lấy thông tin người dùng từ Firestore trước
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      String displayName;
      String? userAvatarUrl;

      if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          displayName = userData['displayName'] ?? 'Người dùng Zink';
          userAvatarUrl = userData['photoURL'];
      } else {
          // Phương án dự phòng: Lấy từ Auth nếu không có trên Firestore
          displayName = user.displayName ?? 'Người dùng Zink';
          userAvatarUrl = user.photoURL;
      }

      String mockVideoUrl = 'https://example.com/video.mp4';
      String mockThumbnailUrl = 'https://example.com/thumbnail.jpg';

      await _firestore.collection('reels').add({
        'uid': user.uid,
        'displayName': displayName, // SỬA: Dùng 'displayName'
        'userAvatarUrl': userAvatarUrl ?? '', // SỬA: Dùng biến đã lấy được
        'desc': _descriptionController.text.trim(),
        'videoUrl': mockVideoUrl, 
        'thumbnailUrl': mockThumbnailUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'privacy': _privacy,
        'likesCount': 0,
        'commentsCount': 0,
        'sharesCount': 0,
        'likedBy': [],
        'savedBy': [],
      });

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

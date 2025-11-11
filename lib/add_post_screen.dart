// lib/add_post_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'add_reel_screen.dart';
import 'utils/app_colors.dart';

// MÀN HÌNH CHA CHỨA TABBAR
class AddPostScreen extends StatefulWidget {
  final VoidCallback onPostUploaded;
  const AddPostScreen({super.key, required this.onPostUploaded});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        shadowColor: darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Tạo mới', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: topazColor,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: sonicSilver,
          tabs: const [
            Tab(text: 'Bài viết'),
            Tab(text: 'Reel'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AddPostContent(onPostUploaded: widget.onPostUploaded),
          const AddReelScreen(),
        ],
      ),
    );
  }
}

// WIDGET CON CHO TAB "BÀI VIẾT"
class AddPostContent extends StatefulWidget {
  final VoidCallback onPostUploaded;
  const AddPostContent({super.key, required this.onPostUploaded});

  @override
  _AddPostContentState createState() => _AddPostContentState();
}

class _AddPostContentState extends State<AddPostContent> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController(); // ĐÃ THÊM: Tags Controller
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  File? _selectedImage;
  String _privacy = 'Công khai';
  bool _isLoading = false;

  // Giả lập hàm chọn ảnh (Cần tích hợp image_picker)
  Future<void> _pickImage() async {
    // TODO: Tích hợp image_picker để chọn ảnh thật
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đang mở thư viện ảnh... (Giả lập)')));
    // Giả sử người dùng chọn một ảnh
    // setState(() => _selectedImage = File('path/to/mock/image.jpg'));
  }

  // SỬA Ở ĐÂY: THAY ĐỔI LOGIC ĐĂNG BÀI
  Future<void> _uploadPost() async {
    final user = _auth.currentUser;
    if (user == null) {
      print("DEBUG: Lỗi - Người dùng hiện tại là null, không thể đăng bài.");
      return;
    }

    final caption = _captionController.text.trim();
    final tags = _tagsController.text.trim().toLowerCase().split(RegExp(r'[,\s]+')).where((tag) => tag.isNotEmpty).toList();

    if (_selectedImage == null && caption.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vui lòng thêm ảnh hoặc viết nội dung để đăng bài.'),
        backgroundColor: coralRed,
      ));
      return;
    }

    setState(() => _isLoading = true);

    print("--- BẮT ĐẦU GỠ LỖI ---");
    print("DEBUG 1: Đang đăng bài cho UID: ${user.uid}");

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = "https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/800/800";
      }

      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      print("DEBUG 2: Tài liệu người dùng có tồn tại trong Firestore không? -> ${userDoc.exists}");

      String displayName;
      String? userAvatarUrl;
      String username; // <-- Biến mới để lưu username

      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data() as Map<String, dynamic>;
        print("DEBUG 3: Dữ liệu lấy từ Firestore là: $userData");
        displayName = userData['displayName'] ?? 'Người dùng Zink (Lỗi)';
        userAvatarUrl = userData['photoURL'];
        username = userData['username'] ?? user.email?.split('@').first ?? 'user'; // <-- Lấy username
      } else {
        print("DEBUG 4: Không tìm thấy tài liệu Firestore. Lấy từ Auth.");
        displayName = user.displayName ?? 'Người dùng Zink';
        userAvatarUrl = user.photoURL;
        username = user.email?.split('@').first ?? 'user'; // <-- Lấy username (dự phòng)
      }

      print("DEBUG 5: Tên hiển thị cuối cùng sẽ được lưu là: '$displayName'");

      // 1. Tạo bài viết mới
      final newPostRef = await _firestore.collection('posts').add({
        'uid': user.uid,
        'displayName': displayName,
        'userAvatarUrl': userAvatarUrl,
        'username': username, // <-- Lưu username của người đăng
        'postCaption': caption,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'privacy': _privacy,
        'likesCount': 0,
        'commentsCount': 0,
        'sharesCount': 0,
        'likedBy': [],
        'savedBy': [],
        'tags': tags,
      });

      final newPostId = newPostRef.id;

      // --- BẮT ĐẦU LOGIC GỬI THÔNG BÁO TAG ---
      final WriteBatch tagBatch = _firestore.batch();

      // 2. Phân tích caption để tìm tag @username
      RegExp tagRegex = RegExp(r'@([a-zA-Z0-9_]+)');
      List<String> mentionedUsernames = tagRegex.allMatches(caption)
          .map((match) => match.group(1)!)
          .toSet()
          .toList();

      List<String> mentionedUserIds = [];
      if (mentionedUsernames.isNotEmpty) {
        // 3. Truy vấn CSDL để lấy ID của các username này
        final usersSnapshot = await _firestore.collection('users')
            .where('username', whereIn: mentionedUsernames.take(30).toList())
            .get();
        mentionedUserIds = usersSnapshot.docs.map((doc) => doc.id).toList();
      }

      // 4. Gửi thông báo cho từng người được tag
      for (String userIdToNotify in mentionedUserIds) {
        if (userIdToNotify != user.uid) { // Không tự tag chính mình
          final tagNotificationRef = _firestore
              .collection('users')
              .doc(userIdToNotify) // Gửi cho người được tag
              .collection('notifications')
              .doc();

          tagBatch.set(tagNotificationRef, {
            'type': 'tag_post', // <-- Loại thông báo mới
            'senderId': user.uid,
            'senderName': displayName,
            'senderAvatarUrl': userAvatarUrl,
            'destinationId': newPostId, // ID của bài viết vừa tạo
            'contentPreview': 'đã nhắc đến bạn trong một bài viết.',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
      }

      // 5. Thực thi batch thông báo
      await tagBatch.commit();
      // --- KẾT THÚC LOGIC GỬI THÔNG BÁO TAG ---

      print("--- GỠ LỖI THÀNH CÔNG ---");

      widget.onPostUploaded();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đăng bài thành công!'), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }

    } catch (e) {
      print("--- GỠ LỖI THẤT BẠI ---");
      print("LỖI EXCEPTION: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: coralRed));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: darkSurface,
                borderRadius: BorderRadius.circular(12),
                image: _selectedImage != null ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover) : null,
              ),
              child: _selectedImage == null
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, color: sonicSilver, size: 50),
                    SizedBox(height: 8),
                    Text('Nhấn để chọn ảnh', style: TextStyle(color: sonicSilver)),
                  ],
                ),
              )
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _captionController,
            maxLines: 5,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Bạn đang nghĩ gì?...',
              hintStyle: TextStyle(color: sonicSilver.withOpacity(0.7)),
              filled: true,
              fillColor: darkSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // ĐÃ THÊM: TRƯỜNG NHẬP TAGS
          TextField(
            controller: _tagsController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Thêm tags (ví dụ: #du_lich, #meo, #food)',
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
          _buildPrivacyOption('Công khai', Icons.public, 'Mọi người trên Zink'),
          _buildPrivacyOption('Bạn bè', Icons.people, 'Chỉ những người bạn theo dõi'),
          _buildPrivacyOption('Chỉ mình tôi', Icons.lock, 'Chỉ mình bạn có thể xem'),
          const SizedBox(height: 30),
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: topazColor))
              : SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _uploadPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: topazColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Đăng bài', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyOption(String value, IconData icon, String subtitle) {
    // ĐÃ SỬA LỖI CHÍNH TẢ: RadioListListTile -> RadioListTile
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
}
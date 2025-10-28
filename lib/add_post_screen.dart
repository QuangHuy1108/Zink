import 'package:flutter/material.dart';
import 'dart:io';

// --- Import các file và hằng số cần thiết ---
import 'add_reel_screen.dart';
import 'utils/app_colors.dart';

class AddPostScreen extends StatefulWidget {
  final VoidCallback onPostUploaded;

  const AddPostScreen({super.key, required this.onPostUploaded});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

// SỬA: Thêm `SingleTickerProviderStateMixin` để quản lý TabController
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
        // SỬA: Thêm TabBar vào bottom của AppBar
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
      // SỬA: Dùng TabBarView để hiển thị nội dung tương ứng
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Màn hình đăng bài viết (giữ nguyên logic cũ)
          AddPostContent(onPostUploaded: widget.onPostUploaded),
          // Tab 2: Màn hình đăng Reel (widget mới đã tạo)
          const AddReelScreen(), 
        ],
      ),
    );
  }
}

// --- Widget nội dung cho việc đăng bài viết (tách ra từ màn hình cũ) ---
class AddPostContent extends StatefulWidget {
  final VoidCallback onPostUploaded;
  const AddPostContent({super.key, required this.onPostUploaded});

  @override
  _AddPostContentState createState() => _AddPostContentState();
}

class _AddPostContentState extends State<AddPostContent> {
  final TextEditingController _captionController = TextEditingController();
  File? _selectedImage;
  String _privacy = 'Công khai';
  bool _isLoading = false;

  // ... (Tất cả các hàm như _pickImage, _uploadPost, ... giữ nguyên logic cũ)
  Future<void> _pickImage() async { /* ... */ }
  Future<void> _uploadPost() async { /* ... */ }

  @override
  Widget build(BuildContext context) {
    // Giao diện của màn hình đăng bài viết không thay đổi, chỉ được bọc trong widget này
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // ... (Toàn bộ giao diện của AddPostScreen cũ được đặt ở đây)
           // Khu vực chọn ảnh
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: darkSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _selectedImage != null
                    ? Image.file(_selectedImage!, fit: BoxFit.cover)
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, color: sonicSilver, size: 50),
                            SizedBox(height: 8),
                            Text('Nhấn để chọn ảnh', style: TextStyle(color: sonicSilver)),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            // Ô nhập caption
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
            // Tùy chọn quyền riêng tư
            _buildPrivacyOption('Công khai', Icons.public, 'Mọi người trên Zink'),
            _buildPrivacyOption('Bạn bè', Icons.people, 'Chỉ những người bạn theo dõi'),
            _buildPrivacyOption('Chỉ mình tôi', Icons.lock, 'Chỉ mình bạn có thể xem'),

            const SizedBox(height: 30),
            // Nút đăng
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

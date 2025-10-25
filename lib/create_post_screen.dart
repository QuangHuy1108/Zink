// lib/create_post_screen.dart
import 'dart:io'; // Giữ lại import này phòng trường hợp _displayImageUrl là file path sau này
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'dart:math'; // Không cần thiết nữa

// TODO: (Quan trọng) Import package image_picker nếu bạn muốn chọn ảnh thật
// import 'package:image_picker/image_picker.dart';
// TODO: (Quan trọng) Import package firebase_storage nếu bạn muốn upload ảnh
// import 'package:firebase_storage/firebase_storage.dart';


// Constants (Giữ nguyên)
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C);

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // TODO: Khởi tạo FirebaseStorage nếu dùng: final FirebaseStorage _storage = FirebaseStorage.instance;

  // Sử dụng _displayImageUrl để lưu URL ảnh sau khi upload (hoặc null)
  String? _displayImageUrl;
  // TODO: Có thể cần thêm biến File? _selectedImageFile; nếu dùng image_picker

  final TextEditingController _captionController = TextEditingController();

  String _selectedPrivacy = 'Công khai';
  final List<String> _privacyOptions = ['Công khai', 'Bạn bè', 'Chỉ mình tôi'];

  bool _isPicking = false; // Cờ cho biết đang chọn/upload ảnh
  bool _isSubmitting = false; // Cờ cho biết đang đăng bài

  // Cập nhật logic chọn ảnh (hiện tại chỉ là placeholder)
  Future<void> _pickImage() async {
    if (_isPicking) return; // Ngăn bấm nhiều lần
    setState(() { _isPicking = true; });

    // TODO: Triển khai logic chọn ảnh thật dùng image_picker
    // final picker = ImagePicker();
    // final XFile? image = await picker.pickImage(source: ImageSource.gallery); // Hoặc ImageSource.camera
    // if (image != null) {
    //   File imageFile = File(image.path);
    //   // TODO: Triển khai logic upload ảnh lên Firebase Storage
    //   // String? uploadedUrl = await _uploadImage(imageFile);
    //   // if (uploadedUrl != null && mounted) {
    //   //   setState(() { _displayImageUrl = uploadedUrl; });
    //   // } else if (mounted) {
    //   //    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi upload ảnh.'), backgroundColor: coralRed));
    //   // }
    // } else {
    //   // Người dùng không chọn ảnh
    // }

    // --- Giả lập tạm thời ---
    await Future.delayed(const Duration(milliseconds: 500)); // Giả lập độ trễ
    if (mounted) {
      setState(() {
        // Tạm thời xóa ảnh khi bấm lại (chờ logic upload)
        _displayImageUrl = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chức năng chọn/upload ảnh chưa được triển khai.')));
    }
    // --- Kết thúc giả lập ---

    if (mounted) setState(() { _isPicking = false; });
  }

  // TODO: Hàm upload ảnh lên Firebase Storage (ví dụ)
  // Future<String?> _uploadImage(File imageFile) async {
  //   try {
  //     final user = _auth.currentUser;
  //     if (user == null) return null;
  //     String fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
  //     Reference storageRef = _storage.ref().child('post_images/$fileName');
  //     UploadTask uploadTask = storageRef.putFile(imageFile);
  //     TaskSnapshot snapshot = await uploadTask;
  //     return await snapshot.ref.getDownloadURL();
  //   } catch (e) {
  //     print("Lỗi upload ảnh: $e");
  //     return null;
  //   }
  // }


  // Logic đăng bài (Đã loại bỏ Storage tham chiếu trực tiếp)
  void _submitPost(BuildContext context) async {
    final caption = _captionController.text.trim();
    final currentUser = _auth.currentUser;

    // Yêu cầu bắt buộc chọn ảnh (kiểm tra _displayImageUrl)
    if (_displayImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Vui lòng chọn và upload ảnh để đăng bài!'),
          backgroundColor: coralRed));
      return;
    }
    if (_isSubmitting || currentUser == null) return;

    setState(() { _isSubmitting = true; });

    try {
      // imageUrl giờ đây phải là URL thật sau khi upload
      final imageUrl = _displayImageUrl!; // Đã kiểm tra null ở trên

      final userName = currentUser.displayName ?? "Người dùng ẩn";
      final userAvatarUrl = currentUser.photoURL; // Có thể null

      final newPostData = {
        'uid': currentUser.uid,
        'userName': userName,
        'userAvatarUrl': userAvatarUrl,
        'tag': '#New', // TODO: Cho phép người dùng chọn Tag
        'likesCount': 0, 'commentsCount': 0, 'sharesCount': 0,
        'likedBy': [], 'savedBy': [], 'privacy': _selectedPrivacy,
        'imageUrl': imageUrl, // Lưu URL ảnh (phải có)
        'postCaption': caption, 'location': null, 'taggedUsers': [],
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('posts').add(newPostData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Đã đăng bài viết thành công!'),
        backgroundColor: topazColor, duration: const Duration(seconds: 2),
      ));
      Navigator.pop(context);

    } catch (e) { /* ... Xử lý lỗi ... */ }
    finally { if (mounted) setState(() { _isSubmitting = false; }); }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Xác định ImageProvider từ _displayImageUrl (chỉ URL mạng hoặc null)
    ImageProvider? imageProvider;
    if (_displayImageUrl != null && _displayImageUrl!.isNotEmpty && _displayImageUrl!.startsWith('http')) {
      imageProvider = NetworkImage(_displayImageUrl!);
    }
    // Không còn xử lý AssetImage

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Tạo Bài Viết Mới', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.black, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              // Disable nút Đăng khi đang chọn ảnh hoặc đang gửi
              onPressed: (_isSubmitting || _isPicking) ? null : () => _submitPost(context),
              style: TextButton.styleFrom(
                foregroundColor: (_isSubmitting || _isPicking) ? sonicSilver : topazColor,
                disabledForegroundColor: sonicSilver.withOpacity(0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: sonicSilver))
                  : const Text('Đăng', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Khu vực Xem trước Ảnh
              GestureDetector(
                onTap: _isPicking ? null : _pickImage, // Disable tap khi đang chọn ảnh
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: darkSurface, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: imageProvider == null ? sonicSilver.withOpacity(0.5) : Colors.transparent, width: 1),
                      image: imageProvider != null
                          ? DecorationImage( image: imageProvider, fit: BoxFit.cover, onError: (err, stack) => print("Lỗi tải ảnh preview: $err"),)
                          : null,
                    ),
                    child: _isPicking // Hiển thị loading khi đang chọn/upload
                        ? const Center(child: CircularProgressIndicator(color: topazColor))
                        : (imageProvider == null
                        ? Center( /* ... Placeholder chọn ảnh ... */ )
                        : null),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Trường Chú thích (Caption)
              TextField( controller: _captionController, /* ... */ ),
              const SizedBox(height: 20),
              // Cài đặt quyền riêng tư (Dropdown)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: darkSurface, // Sử dụng hằng số màu đã định nghĩa
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPrivacy, // Giá trị hiện tại
                    isExpanded: true,
                    dropdownColor: darkSurface, // Nền của danh sách thả xuống
                    style: const TextStyle(color: Colors.white, fontSize: 16), // Kiểu chữ
                    icon: const Icon(Icons.arrow_drop_down, color: sonicSilver), // Icon mũi tên

                    // Sửa lỗi: Cung cấp hàm onChanged
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedPrivacy = newValue;
                        });
                      }
                    },

                    // Sửa lỗi: Cung cấp danh sách items
                    items: _privacyOptions.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              const SizedBox(height: 15),
              // Các tùy chọn nâng cao
              _buildOptionTile(icon: Icons.location_on_outlined, title: 'Thêm vị trí', onTap: () { /* ... */ }),
              const SizedBox(height: 10),
              _buildOptionTile(icon: Icons.alternate_email_outlined, title: 'Gắn thẻ người khác', onTap: () { /* ... */ }),
              const SizedBox(height: 10),
              _buildOptionTile(icon: Icons.sell_outlined, title: 'Thêm chủ đề (Tag)', onTap: () { /* ... */ }),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget để tạo các ListTile tùy chọn (Giữ nguyên)
  Widget _buildOptionTile({required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: sonicSilver),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
      trailing: const Icon(Icons.arrow_forward_ios, color: sonicSilver, size: 16),
      tileColor: darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
    );
  }
}
// lib/create_story_screen.dart
import 'dart:io'; // Import để xử lý File (nếu bạn dùng image_picker thật)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'models.dart'; // Import StoryContent (giả định tồn tại hoặc định nghĩa ở đây)

// --- Giả định StoryContent và StoryState tồn tại (nếu cần) ---
class StoryContent { /* ... Định nghĩa StoryContent ... */ }
class StoryState { /* ... Định nghĩa StoryState ... */ }
final StoryState globalUserStoryState = StoryState();
// --- Kết thúc giả định ---


// TODO: Import image_picker và firebase_storage nếu cần

// Constants (Giữ nguyên)
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C);


class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // TODO: Khởi tạo FirebaseStorage nếu dùng: final FirebaseStorage _storage = FirebaseStorage.instance;

  // Sử dụng _selectedImageUrl để lưu URL ảnh sau khi upload (hoặc null)
  String? _selectedImageUrl;
  // TODO: Có thể cần thêm biến File? _selectedImageFile; nếu dùng image_picker

  String _storyText = '';
  String _selectedSong = '';
  String _selectedLocation = '';
  List<String> _taggedFriends = [];

  Offset _textPosition = const Offset(50, 200);
  Offset _songPosition = const Offset(50, 100);

  // --- ĐÃ XÓA: _mockImages ---

  bool _isPicking = false; // Cờ cho biết đang chọn/upload ảnh
  bool _isSubmitting = false; // Cờ cho biết đang đăng bài

  // @override
  // void initState() {
  //   super.initState();
  //   // Không khởi tạo ảnh mock nữa
  // }

  // Phương thức chọn ảnh (Placeholder, cần logic upload)
  Future<void> _pickImage() async {
    if (_isPicking) return;
    setState(() { _isPicking = true; });

    // TODO: Triển khai logic chọn ảnh thật dùng image_picker và upload lên Firebase Storage
    // Sau khi upload thành công, cập nhật _selectedImageUrl = url_ảnh_đã_upload;

    // --- Giả lập tạm thời ---
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() { _selectedImageUrl = null; }); // Tạm thời xóa ảnh
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chức năng chọn/upload ảnh chưa được triển khai.')));
    }
    // --- Kết thúc giả lập ---

    if (mounted) setState(() { _isPicking = false; });
  }

  // TODO: Hàm upload ảnh lên Firebase Storage (tương tự CreatePostScreen)
  // Future<String?> _uploadImage(File imageFile) async { /* ... */ }

  // Phương thức THÊM NHẠC (Giữ nguyên UI)
  void _addSong() async { /* ... Logic giữ nguyên ... */ }
  // Phương thức THÊM VĂN BẢN (Text) (Giữ nguyên UI)
  void _addText() { /* ... Logic giữ nguyên ... */ }
  // Phương thức TAG BẠN BÈ (Tag Friends) (Giữ nguyên UI)
  void _addTag() { /* ... Logic giữ nguyên ... */ }
  // Phương thức VỊ TRÍ (Location) (Giữ nguyên UI)
  void _addLocation() { /* ... Logic giữ nguyên ... */ }

  // Cập nhật hành động Đăng Story lên Firestore (Sử dụng _selectedImageUrl)
  void _postStory() async {
    final currentUser = _auth.currentUser;
    // Kiểm tra _selectedImageUrl thay vì _selectedImagePath
    if (currentUser == null || _selectedImageUrl == null || _isSubmitting || _isPicking) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_selectedImageUrl == null ? 'Vui lòng chọn và upload ảnh để đăng tin!' : 'Vui lòng đợi...'),
          backgroundColor: coralRed ));
      return;
    }

    setState(() { _isSubmitting = true; });

    // Lấy thông tin user
    final userName = currentUser.displayName ?? 'Người dùng';
    final userAvatarUrl = currentUser.photoURL;

    final storyData = {
      'userId': currentUser.uid, 'userName': userName, 'userAvatarUrl': userAvatarUrl,
      'imageUrl': _selectedImageUrl, // <<--- LƯU URL ẢNH ĐÃ UPLOAD
      'text': _storyText, 'textPosition': {'dx': _textPosition.dx, 'dy': _textPosition.dy},
      'song': _selectedSong, 'songPosition': {'dx': _songPosition.dx, 'dy': _songPosition.dy},
      'location': _selectedLocation, 'taggedFriends': _taggedFriends,
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
      'viewedBy': [], 'likedBy': [], // Thêm likedBy nếu cần
    };

    try {
      await _firestore.collection('stories').add(storyData);
      // --- ĐÃ XÓA LOGIC CẬP NHẬT globalUserStoryState ---
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã đăng tin thành công!'),
          backgroundColor: topazColor, // Sử dụng màu hằng số của bạn
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    } catch (e) { /* ... Xử lý lỗi ... */ }
    finally { if (mounted) setState(() { _isSubmitting = false; }); }
  }

  // Widget kéo thả (Giữ nguyên)
  Widget _buildDraggableWidget({
    required String content,
    required Offset position,
    required Function(DragUpdateDetails) onDragUpdate,
    required TextStyle style,
    Color shadowColor = Colors.black, // Thêm màu đổ bóng
  }) {
    if (content.isEmpty) return const SizedBox.shrink(); // Trả về rỗng nếu không có nội dung

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector( // Cho phép kéo
        onPanUpdate: onDragUpdate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.transparent, // Chỉ hiển thị text
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: shadowColor.withOpacity(0.7),
                blurRadius: 5,
                spreadRadius: 2,
              )
            ],
          ),
          child: Text(
            content,
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
      ),
    );
  }

@override
Widget build(BuildContext context) {
  const double iconSize = 28;
  final size = MediaQuery.of(context).size;
  final paddingTop = MediaQuery.of(context).padding.top;
  final paddingBottom = MediaQuery.of(context).padding.bottom;

  // Xác định ImageProvider từ _selectedImageUrl (chỉ URL mạng hoặc null)
  ImageProvider? imageProvider;
  if (_selectedImageUrl != null && _selectedImageUrl!.isNotEmpty && _selectedImageUrl!.startsWith('http')) {
    imageProvider = NetworkImage(_selectedImageUrl!);
  }
  // Không còn xử lý AssetImage

  return Scaffold(
    backgroundColor: Colors.black,
    resizeToAvoidBottomInset: false,
    body: Stack(
      children: [
        // 1. STORY CONTENT/BACKGROUND (Ảnh từ URL hoặc Placeholder)
        GestureDetector(
          onTap: _isPicking ? null : _pickImage, // Disable tap khi đang chọn/upload
          child: Container(
            width: double.infinity, height: double.infinity,
            color: darkSurface,
            child: _isPicking // Hiển thị loading khi đang chọn/upload
                ? const Center(child: CircularProgressIndicator(color: topazColor))
                : (imageProvider != null
                ? Image( image: imageProvider, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Center(child: Icon(Icons.broken_image, color: sonicSilver, size: 50)))
                : Center( /* ... Placeholder chọn ảnh ... */ )
            ),
          ),
        ),

        // Lớp phủ Gradient (Giữ nguyên)
        Container( /* ... Gradient ... */ ),

        // 2. KÉO THẢ VĂN BẢN VÀ NHẠC (Giữ nguyên)
        _buildDraggableWidget(
          content: _selectedSong.isNotEmpty ? '🎶 $_selectedSong' : '',
          position: _songPosition, // Vị trí của nhạc
          onDragUpdate: (details) {
            setState(() {
              // Cập nhật vị trí khi kéo, giới hạn trong màn hình
              _songPosition = Offset(
                (_songPosition.dx + details.delta.dx).clamp(0, size.width - 50),
                (_songPosition.dy + details.delta.dy).clamp(0, size.height - 50),
              );
            });
          },
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          shadowColor: Colors.black,
        ),
        _buildDraggableWidget(
          content: _storyText,
          position: _textPosition, // Vị trí của text
          onDragUpdate: (details) {
            setState(() {
              // Cập nhật vị trí khi kéo, giới hạn trong màn hình
              _textPosition = Offset(
                (_textPosition.dx + details.delta.dx).clamp(0, size.width - 50),
                (_textPosition.dy + details.delta.dy).clamp(0, size.height - 50),
              );
            });
          },
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          shadowColor: Colors.black,
        ),

        // 3. TAG VÀ VỊ TRÍ CỐ ĐỊNH (Giữ nguyên)
        if (_selectedLocation.isNotEmpty || _taggedFriends.isNotEmpty)
          Positioned(
            bottom: paddingBottom + 80, // Vị trí cố định (phía trên nút Đăng)
            left: 16,
            right: 16,
            child: Container( // Thêm child là Container
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min, // Thu nhỏ vừa nội dung
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_selectedLocation.isNotEmpty) ...[
                    const Icon(Icons.location_on, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(_selectedLocation, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                  if (_selectedLocation.isNotEmpty && _taggedFriends.isNotEmpty)
                    const Text(' - ', style: TextStyle(color: Colors.white, fontSize: 13)),
                  if (_taggedFriends.isNotEmpty) ...[
                    const Icon(Icons.person, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      // Hiển thị tên nếu tag 1 người, ngược lại hiển thị số lượng
                      _taggedFriends.length == 1 ? _taggedFriends.first : '${_taggedFriends.length} người bạn',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ),

        // 4. TOP ACTION BAR (Giữ nguyên)
// 4. TOP ACTION BAR
        Positioned(
          top: paddingTop + 10, // Căn chỉnh theo padding trên của thiết bị
          left: 16,
          right: 16,
          child: Row( // Thêm child là Row
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Nút Đóng
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: iconSize),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.4)), // Thêm nền mờ
              ),
              // Các nút Actions
              Row(
                children: [
                  _buildTopActionButton(icon: Icons.music_note, onTap: _addSong),
                  const SizedBox(width: 10),
                  _buildTopActionButton(icon: Icons.text_fields, onTap: _addText),
                  const SizedBox(width: 10),
                  _buildTopActionButton(icon: Icons.alternate_email, onTap: _addTag),
                  const SizedBox(width: 10),
                  _buildTopActionButton(icon: Icons.location_on, onTap: _addLocation),
                ],
              ),
            ],
          ),
        ),
        // 5. NÚT ĐĂNG (Send Button)
        Positioned(
          bottom: paddingBottom + 20, right: 20,
          child: FloatingActionButton.extended(
            onPressed: (_isSubmitting || _isPicking) ? null : _postStory, // Disable khi đang xử lý
            icon: _isSubmitting ? SizedBox(/* Loading */) : const Icon(Icons.send_rounded, /* ... */),
            label: Text(_isSubmitting ? 'Đang đăng...' : 'Tin của bạn', /* ... */),
            backgroundColor: topazColor, elevation: 4,
          ),
        ),
      ],
    ),
  );
}

  // Helper widget cho các nút action ở top bar
  Widget _buildTopActionButton({required IconData icon, required VoidCallback onTap}) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 24), // Icon nhỏ hơn một chút
      onPressed: onTap,
      padding: const EdgeInsets.all(8), // Padding nhỏ hơn
      constraints: const BoxConstraints(), // Bỏ ràng buộc kích thước mặc định
      splashRadius: 20, // Giảm vùng splash
    );
  }
}
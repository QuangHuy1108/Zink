// lib/create_story_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- Giả định StoryContent và StoryState tồn tại ---
class StoryContent { /* ... */ }
class StoryState { /* ... */ }
final StoryState globalUserStoryState = StoryState();
// --- Kết thúc giả định ---

// Constants
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

  String? _selectedImageUrl;
  String _storyText = '';
  String _selectedSong = '';
  String _selectedLocation = '';
  List<String> _taggedFriends = [];

  Offset _textPosition = const Offset(50, 200);
  Offset _songPosition = const Offset(50, 100);

  bool _isPicking = false;
  bool _isSubmitting = false;

  Future<void> _pickImage() async {
    if (_isPicking) return;
    setState(() { _isPicking = true; });

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() { _selectedImageUrl = 'https://firebasestorage.googleapis.com/v0/b/zink-d4493.appspot.com/o/story_images%2Fmock_image.jpg?alt=media&token=12345'; }); // Giả lập có ảnh
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã chọn ảnh (Giả lập)')));
    }

    if (mounted) setState(() { _isPicking = false; });
  }

  void _addSong() async { /* ... */ }
  
  // SỬA: Hoàn thiện chức năng thêm chữ
  void _addText() async {
    final textController = TextEditingController(text: _storyText);
    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: darkSurface,
        title: const Text('Nhập nội dung', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nội dung tin của bạn...',
            hintStyle: TextStyle(color: sonicSilver),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy', style: TextStyle(color: sonicSilver)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(textController.text);
            },
            child: const Text('OK', style: TextStyle(color: topazColor)),
          ),
        ],
      ),
    );

    if (newText != null) {
      setState(() {
        _storyText = newText;
      });
    }
  }

  void _addTag() { /* ... */ }
  void _addLocation() { /* ... */ }

  // SỬA: Thay đổi điều kiện kiểm tra để cho phép đăng story chỉ có chữ
  void _postStory() async {
    final currentUser = _auth.currentUser;
    // Kiểm tra xem có nội dung không (ảnh hoặc chữ)
    if (currentUser == null || (_selectedImageUrl == null && _storyText.trim().isEmpty) || _isSubmitting || _isPicking) {
      String errorMessage = 'Vui lòng thêm ảnh hoặc nhập văn bản để đăng tin!';
      if (_isSubmitting || _isPicking) {
        errorMessage = 'Vui lòng đợi...';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: coralRed));
      return;
    }

    setState(() { _isSubmitting = true; });

    final userName = currentUser.displayName ?? 'Người dùng';
    final userAvatarUrl = currentUser.photoURL;

    final storyData = {
      'userId': currentUser.uid, 'userName': userName, 'userAvatarUrl': userAvatarUrl,
      'imageUrl': _selectedImageUrl, 
      'text': _storyText, 'textPosition': {'dx': _textPosition.dx, 'dy': _textPosition.dy},
      'song': _selectedSong, 'songPosition': {'dx': _songPosition.dx, 'dy': _songPosition.dy},
      'location': _selectedLocation, 'taggedFriends': _taggedFriends,
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
      'viewedBy': [], 'likedBy': [],
    };

    try {
      final WriteBatch batch = _firestore.batch();
      final storyRef = _firestore.collection('stories').doc();
      batch.set(storyRef, storyData);
      final userRef = _firestore.collection('users').doc(currentUser.uid);
      batch.update(userRef, {'hasActiveStory': true, 'lastStoryTimestamp': FieldValue.serverTimestamp()});
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã đăng tin thành công!'), backgroundColor: topazColor, duration: Duration(seconds: 2)));
      Navigator.pop(context);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi đăng tin: $e'), backgroundColor: coralRed));
    } finally {
      if (mounted) setState(() { _isSubmitting = false; });
    }
  }

  Widget _buildDraggableWidget({required String content, required Offset position, required Function(DragUpdateDetails) onDragUpdate, required TextStyle style, Color shadowColor = Colors.black}) {
    if (content.isEmpty) return const SizedBox.shrink();
    return Positioned(left: position.dx, top: position.dy, child: GestureDetector(onPanUpdate: onDragUpdate, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: shadowColor.withOpacity(0.7), blurRadius: 5, spreadRadius: 2)]), child: Text(content, textAlign: TextAlign.center, style: style))));
  }

  @override
  Widget build(BuildContext context) {
    const double iconSize = 28;
    final size = MediaQuery.of(context).size;
    final paddingTop = MediaQuery.of(context).padding.top;
    final paddingBottom = MediaQuery.of(context).padding.bottom;

    ImageProvider? imageProvider;
    if (_selectedImageUrl != null && _selectedImageUrl!.isNotEmpty && _selectedImageUrl!.startsWith('http')) {
      imageProvider = NetworkImage(_selectedImageUrl!);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          GestureDetector(onTap: _isPicking ? null : _pickImage, child: Container(width: double.infinity, height: double.infinity, color: darkSurface, child: _isPicking ? const Center(child: CircularProgressIndicator(color: topazColor)) : (imageProvider != null ? Image(image: imageProvider, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Center(child: Icon(Icons.broken_image, color: sonicSilver, size: 50))) : const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_outlined, size: 60, color: sonicSilver), SizedBox(height: 12), Text('Nhấn để chọn ảnh/video', style: TextStyle(color: sonicSilver, fontSize: 16))]))))),
          Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.4), Colors.transparent, Colors.black.withOpacity(0.6)], stops: const [0.0, 0.4, 1.0]))),
          _buildDraggableWidget(content: _selectedSong.isNotEmpty ? '🎶 $_selectedSong' : '', position: _songPosition, onDragUpdate: (details) => setState(() => _songPosition = Offset((_songPosition.dx + details.delta.dx).clamp(0, size.width - 50), (_songPosition.dy + details.delta.dy).clamp(0, size.height - 50))), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), shadowColor: Colors.black),
          _buildDraggableWidget(content: _storyText, position: _textPosition, onDragUpdate: (details) => setState(() => _textPosition = Offset((_textPosition.dx + details.delta.dx).clamp(0, size.width - 50), (_textPosition.dy + details.delta.dy).clamp(0, size.height - 50))), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), shadowColor: Colors.black),
          if (_selectedLocation.isNotEmpty || _taggedFriends.isNotEmpty) Positioned(bottom: paddingBottom + 80, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [if (_selectedLocation.isNotEmpty) ...[const Icon(Icons.location_on, color: Colors.white, size: 14), const SizedBox(width: 4), Text(_selectedLocation, style: const TextStyle(color: Colors.white, fontSize: 13))], if (_selectedLocation.isNotEmpty && _taggedFriends.isNotEmpty) const Text(' - ', style: TextStyle(color: Colors.white, fontSize: 13)), if (_taggedFriends.isNotEmpty) ...[const Icon(Icons.person, color: Colors.white, size: 14), const SizedBox(width: 4), Text(_taggedFriends.length == 1 ? _taggedFriends.first : '${_taggedFriends.length} người bạn', style: const TextStyle(color: Colors.white, fontSize: 13))]])))),
          Positioned(top: paddingTop + 10, left: 16, right: 16, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(icon: const Icon(Icons.close, color: Colors.white, size: iconSize), onPressed: () => Navigator.pop(context), style: IconButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.4))), Row(children: [_buildTopActionButton(icon: Icons.music_note, onTap: _addSong), const SizedBox(width: 10), _buildTopActionButton(icon: Icons.text_fields, onTap: _addText), const SizedBox(width: 10), _buildTopActionButton(icon: Icons.alternate_email, onTap: _addTag), const SizedBox(width: 10), _buildTopActionButton(icon: Icons.location_on, onTap: _addLocation)])])),
          Positioned(bottom: paddingBottom + 20, right: 20, child: FloatingActionButton.extended(onPressed: (_isSubmitting || _isPicking) ? null : _postStory, icon: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.send_rounded, color: Colors.black), label: Text(_isSubmitting ? 'Đang đăng...' : 'Tin của bạn', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: topazColor, elevation: 4)),
        ],
      ),
    );
  }

  Widget _buildTopActionButton({required IconData icon, required VoidCallback onTap}) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 24),
      onPressed: onTap,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
      splashRadius: 20,
    );
  }
}

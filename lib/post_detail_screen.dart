// lib/post_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // <--- Import Auth

// Import PostCard và các Constants/Helpers (Giả định tồn tại)
// import 'feed_screen.dart'; // Để dùng PostCard và các Constants/Helpers
// import 'models.dart'; // Giả sử Comment model ở đây

// --- Giả định các lớp/widget này tồn tại ---
class PostCard extends StatelessWidget { final Map<String, dynamic> postData; final VoidCallback onStateChange; const PostCard({super.key, required this.postData, required this.onStateChange}); @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(8), margin: const EdgeInsets.symmetric(vertical: 4), color: darkSurface, child: Text("Post ${postData['id']}", style: const TextStyle(color: Colors.white))); }
class Comment { final String id; final String userId; final String userName; final String? userAvatarUrl; final String text; final Timestamp timestamp; final String? parentId; bool isLiked; int likesCount; final List<String> likedBy; Comment({required this.id, required this.userId, required this.userName, this.userAvatarUrl, required this.text, required this.timestamp, this.parentId, this.isLiked = false, required this.likesCount, required this.likedBy}); factory Comment.fromFirestore(DocumentSnapshot doc, String currentUserId) => Comment(id: doc.id, userId: '', userName: '', text: '', timestamp: Timestamp.now(), likesCount: 0, likedBy: []);}
// --- Kết thúc giả định ---

// Constants
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
// const Color coralRed = Color(0xFFFD402C);

// =======================================================
// MÀN HÌNH CHI TIẾT BÀI VIẾT (Đã cập nhật Avatar)
// =======================================================
class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> postData; // Dữ liệu Post đã xử lý (URL có thể null)
  const PostDetailScreen({super.key, required this.postData});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  late String _postId;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _postId = widget.postData['id'] as String? ?? '';
    if (_postId.isEmpty) { /* Handle error */ }
  }

  // --- HÀM BUILD COMMENT ITEM (Cập nhật Avatar) ---
  Widget _buildCommentItem(Comment comment) {
    final bool isMyComment = comment.userId == _currentUser?.uid;

    // Lấy avatar URL (có thể null)
    final String? avatarUrl = comment.userAvatarUrl;
    final ImageProvider? avatarImage = (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
        ? NetworkImage(avatarUrl)
        : null; // Không fallback AssetImage

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar( // Avatar đã xử lý null
            radius: 18,
            backgroundImage: avatarImage, // Có thể null
            backgroundColor: darkSurface,
            // Hiển thị Icon nếu không có ảnh
            child: avatarImage == null ? const Icon(Icons.person_outline, size: 18, color: sonicSilver) : null,
          ),
          const SizedBox(width: 12),
          Expanded( child: Column( /* ... Nội dung comment ... */ ),
          ),
        ],
      ),
    );
  }

  // --- HÀM FORMAT TIMESTAMP (Giữ nguyên) ---
  String _formatTimestampAgo(Timestamp timestamp) { /* ... */ return ''; }

  @override
  Widget build(BuildContext context) {
    final String postUserName = widget.postData['userName'] ?? 'Bài viết';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Bài viết của $postUserName', style: const TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: Colors.black, elevation: 0.5, shadowColor: darkSurface,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HIỂN THỊ POSTCARD CHI TIẾT
            // PostCard cần được cập nhật để xử lý URL null
            PostCard(
              postData: widget.postData, // Truyền data (URL có thể null)
              onStateChange: () { if (mounted) setState(() {}); },
            ),
            const Divider(color: darkSurface, height: 1, thickness: 1),

            // 2. TIÊU ĐỀ PHẦN BÌNH LUẬN (Giữ nguyên)Padding( /* ... Tiêu đề "Bình luận" ... */ ),Padding(
            //               padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), // Sửa lỗi: Thêm padding
            //               child: const Text( // Sửa lỗi: Thêm child
            //                 'Bình luận',
            //                 style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            //               ),
            //             ),

            // 3. HIỂN THỊ DANH SÁCH BÌNH LUẬN (StreamBuilder giữ nguyên, _buildCommentItem đã cập nhật)
            if (_postId.isNotEmpty)
              StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('posts').doc(_postId).collection('comments')
                    .orderBy('timestamp', descending: false).limit(20).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) { /* Loading */ }
                  if (snapshot.hasError) { /* Error */ }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) { /* No data */ }

                  final commentDocs = snapshot.data!.docs;
                  final currentUserId = _currentUser?.uid ?? '';

                  return ListView.builder(
                    physics: const NeverScrollableScrollPhysics(), shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: commentDocs.length,
                    itemBuilder: (context, index) {
                      try {
                        final comment = Comment.fromFirestore(commentDocs[index], currentUserId);
                        return _buildCommentItem(comment); // Đã cập nhật avatar
                      } catch (e) { print("Lỗi parse comment: $e"); return const SizedBox.shrink(); }
                    },
                  );
                },
              )
            else
              const Padding(
                padding: EdgeInsets.all(16.0), // Sửa lỗi: Thêm padding
                child: Center( // Sửa lỗi: Thêm child
                  child: Text(
                    'Lỗi: Không thể tải bình luận (Thiếu ID bài viết).',
                    style: TextStyle(color: sonicSilver, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            const SizedBox(height: 50), // Padding dưới cùng

            const SizedBox(height: 50), // Padding dưới cùng
          ],
        ),
      ),
    );
  }
}

// lib/post_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // <--- Import Auth
import 'feed_screen.dart' hide Comment;

// Import PostCard và các Constants/Helpers (Giả định tồn tại)
// import 'feed_screen.dart'; // Để dùng PostCard và các Constants/Helpers
// import 'models.dart'; // Giả sử Comment model ở đây

// --- Giả định các lớp/widget này tồn tại ---
// THAY THẾ TOÀN BỘ CLASS COMMENT CŨ BẰNG CLASS NÀY:

class Comment {
  final String id;
  final String userId;
  final String displayName; // ĐÃ SỬA
  final String? userAvatarUrl;
  final String text;
  final Timestamp timestamp;
  final String? parentId;
  bool isLiked;
  int likesCount;
  final List<String> likedBy;

  Comment({
    required this.id,
    required this.userId,
    required this.displayName, // ĐÃ SỬA
    this.userAvatarUrl,
    required this.text,
    required this.timestamp,
    this.parentId,
    this.isLiked = false,
    required this.likesCount,
    required this.likedBy
  });

  factory Comment.fromFirestore(DocumentSnapshot doc, String currentUserId) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    List<String> likedByList = List<String>.from(data['likedBy'] ?? []);
    return Comment(
      id: doc.id,
      userId: data['userId'] ?? '',
      displayName: data['displayName'] ?? 'Người dùng Zink', // ĐÃ SỬA
      userAvatarUrl: data['userAvatarUrl'],
      text: data['text'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      parentId: data['parentId'],
      likesCount: (data['likesCount'] is num ? (data['likesCount'] as num).toInt() : 0),
      likedBy: likedByList,
      isLiked: currentUserId.isNotEmpty && likedByList.contains(currentUserId),
    );
  }
}// --- Kết thúc giả định ---

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

    final String? avatarUrl = comment.userAvatarUrl;
    final ImageProvider? avatarImage = (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
        ? NetworkImage(avatarUrl)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: avatarImage,
            backgroundColor: darkSurface,
            child: avatarImage == null ? const Icon(Icons.person_outline, size: 18, color: sonicSilver) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: darkSurface,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        comment.text,
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Row(
                    children: [
                      Text(_formatTimestampAgo(comment.timestamp), style: const TextStyle(color: sonicSilver, fontSize: 12)),
                      const SizedBox(width: 12),
                      if (comment.likesCount > 0)
                        Text('${comment.likesCount} Thích', style: const TextStyle(color: sonicSilver, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Nút like cho comment có thể thêm ở đây nếu cần
        ],
      ),
    );
  }

  // --- HÀM FORMAT TIMESTAMP (Giữ nguyên) ---
  String _formatTimestampAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp.toDate());

    if (difference.inSeconds < 60) return 'Vừa xong';
    if (difference.inMinutes < 60) return '${difference.inMinutes} phút';
    if (difference.inHours < 24) return '${difference.inHours} giờ';
    return '${difference.inDays} ngày';
  }
  @override
  @override
  @override
  Widget build(BuildContext context) {    final String postUserName = widget.postData['displayName'] ?? 'Bài viết';

  return Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
        onPressed: () => Navigator.of(context).pop(),
        splashRadius: 28,
      ),
      title: Text('Bài viết của $postUserName', style: const TextStyle(color: Colors.white, fontSize: 18)),
      backgroundColor: Colors.black,
      elevation: 0.5,
      shadowColor: darkSurface,
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    body: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HIỂN THỊ POSTCARD CHI TIẾT (ĐÃ SỬA)
          PostCard(
            postData: widget.postData,
            // XÓA BỎ onStateChange ở đây
          ),
          const Divider(color: darkSurface, height: 1, thickness: 1),

          // 2. TIÊU ĐỀ PHẦN BÌNH LUẬN
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Text(
              'Bình luận',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),

          // 3. HIỂN THỊ DANH SÁCH BÌNH LUẬN
          if (_postId.isNotEmpty)
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('posts').doc(_postId).collection('comments')
                  .orderBy('timestamp', descending: false)
                  .limit(20)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: topazColor)));
                }
                if (snapshot.hasError) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Lỗi tải bình luận.', style: TextStyle(color: sonicSilver))));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Chưa có bình luận nào.', style: TextStyle(color: sonicSilver))));
                }

                final commentDocs = snapshot.data!.docs;
                final currentUserId = _currentUser?.uid ?? '';

                return ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: commentDocs.length,
                  itemBuilder: (context, index) {
                    try {
                      final comment = Comment.fromFirestore(commentDocs[index], currentUserId);
                      return _buildCommentItem(comment);
                    } catch (e) {
                      print("Lỗi parse comment: $e");
                      return const SizedBox.shrink();
                    }
                  },
                );
              },
            )
          else
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'Lỗi: Không thể tải bình luận (Thiếu ID bài viết).',
                  style: TextStyle(color: sonicSilver, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          const SizedBox(height: 50), // Padding dưới cùng
        ],
      ),
    ),
  );
  }
}
// lib/post_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'feed_screen.dart' hide Comment; // Dùng PostCard
import 'comment_screen.dart' hide Comment;

// ===== CÁC IMPORT ĐÃ THÊM =====
import 'dart:developer' as developer;
import 'profile_screen.dart' hide PostDetailScreen, Comment;
// =============================

// --- Giả định các lớp/widget này tồn tại ---
// Định nghĩa Comment (GIỮ NGUYÊN TỪ FILE CŨ CỦA BẠN)
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
}
// --- Kết thúc giả định ---

// Constants
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C); // ĐÃ BỎ COMMENT

// =======================================================
// MÀN HÌNH CHI TIẾT BÀI VIẾT (Đã cập nhật Avatar)
// =======================================================
class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> postData;
  const PostDetailScreen({super.key, required this.postData});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  late String _postId;

  // ===== BIẾN ĐÃ THÊM =====
  late bool isPostOwner;
  // =========================

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _postId = widget.postData['id'] as String? ?? '';
    // ===== DÒNG ĐÃ THÊM =====
    isPostOwner = widget.postData['uid'] == _currentUser?.uid;
    // =========================
    if (_postId.isEmpty) { /* Handle error */ }
  }

  void _openCommentSheet() {
    if (_postId.isEmpty) return;

    // Lấy dữ liệu post từ widget (đã có)
    final String postMediaUrl = widget.postData['imageUrl'] ?? '';
    final String postUserName = widget.postData['displayName'] ?? 'Người dùng';
    final int commentCount = widget.postData['commentsCount'] ?? 0;
    // Biến isPostOwner đã có trong initState

    // Mở sheet bình luận (giống hệt logic của FeedScreen)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.95,
          child: CommentBottomSheetContent( // <-- Gọi sheet từ lib/comment_screen.dart
            postId: _postId,
            postUserName: postUserName,
            currentCommentCount: commentCount,
            postMediaUrl: postMediaUrl,
            postCaption: widget.postData['postCaption'] ?? '',
            isPostOwner: isPostOwner,
            onCommentPosted: (newCount) {
              // Cập nhật lại UI (nếu cần)
              if (mounted) {
                setState(() {
                  // Cập nhật lại postData (mặc dù không bắt buộc)
                  widget.postData['commentsCount'] = newCount;
                });
              }
            },
          ),
        );
      },
    );
  }

  // Điều hướng đến trang cá nhân
  void _navigateToProfile(String userId) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          targetUserId: userId,
          onNavigateToHome: () { if (Navigator.canPop(context)) Navigator.pop(context); },
          onLogout: () {},
        ),
      ),
    );
  }

  // Thích/Bỏ thích bình luận
  void _toggleCommentLike(Comment comment) async {
    final userId = _currentUser?.uid;
    if (userId == null) return;

    // SỬA: Dùng _postId thay vì widget.postId
    final commentRef = _firestore
        .collection('posts')
        .doc(_postId)
        .collection('comments')
        .doc(comment.id);
    final isCurrentlyLiked = comment.isLiked;

    if (mounted) {
      setState(() {
        comment.isLiked = !isCurrentlyLiked;
        isCurrentlyLiked ? comment.likesCount-- : comment.likesCount++;
      });
    }

    try {
      if (!isCurrentlyLiked) {
        await commentRef.update({
          'likedBy': FieldValue.arrayUnion([userId]),
          'likesCount': FieldValue.increment(1)
        });
      } else {
        await commentRef.update({
          'likedBy': FieldValue.arrayRemove([userId]),
          'likesCount': FieldValue.increment(-1)
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          comment.isLiked = isCurrentlyLiked;
          isCurrentlyLiked ? comment.likesCount++ : comment.likesCount--;
        });
      }
      developer.log("Error toggling comment like: $e", name: 'PostDetailScreen');
    }
  }

  // Mở menu (Xóa/Báo cáo)
  void _showCommentMenu(Comment comment) {
    final isMyComment = comment.userId == _currentUser?.uid;
    // SỬA: Dùng biến isPostOwner của class
    showModalBottomSheet(
      context: context,
      backgroundColor: darkSurface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (isMyComment || isPostOwner) // <--- SỬA Ở ĐÂY
            ListTile(
                leading: const Icon(Icons.delete_outline, color: coralRed),
                title: const Text('Xóa bình luận', style: TextStyle(color: coralRed)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeletionReasonDialog(comment);
                }),
          if (!isMyComment)
            ListTile(
                leading: const Icon(Icons.report_problem_outlined, color: sonicSilver),
                title: const Text('Báo cáo bình luận', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã báo cáo bình luận.')));
                  }
                }),
          ListTile(
              leading: const Icon(Icons.close, color: sonicSilver),
              title: const Text('Hủy', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx)),
        ]),
      ),
    );
  }

  // Hộp thoại xác nhận xóa
  void _showDeletionReasonDialog(Comment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: darkSurface,
        title: const Text('Xóa bình luận', style: TextStyle(color: Colors.white)),
        content: const Text('Bạn có chắc chắn muốn xóa bình luận này không?', style: TextStyle(color: sonicSilver)),
        actions: [
          TextButton(
              child: const Text('Hủy', style: TextStyle(color: sonicSilver)),
              onPressed: () => Navigator.of(ctx).pop(false)),
          TextButton(
              child: const Text('Xóa', style: TextStyle(color: coralRed)),
              onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    );
    if (confirm == true) _deleteComment(comment);
  }

  // Logic xóa (đã sửa lỗi)
  void _deleteComment(Comment comment) async {
    try {
      final WriteBatch batch = _firestore.batch();
      // SỬA: Dùng _postId
      final postRef = _firestore.collection('posts').doc(_postId);
      final commentsCollection = postRef.collection('comments');
      final commentRef = commentsCollection.doc(comment.id);

      if (comment.parentId == null) {
        final repliesSnapshot = await commentsCollection
            .where('parentId', isEqualTo: comment.id)
            .get();
        for (final replyDoc in repliesSnapshot.docs) {
          batch.update(replyDoc.reference, {'parentId': null});
        }
      }

      batch.delete(commentRef);
      batch.update(postRef, {'commentsCount': FieldValue.increment(-1)});
      await batch.commit();

      // SỬA: Xóa 2 dòng callback không tồn tại

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa bình luận.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Lỗi: Không thể xóa bình luận.'),
            backgroundColor: coralRed));
      }
      developer.log("Error deleting comment: $e", name: 'PostDetailScreen');
    }
  }

  // ====================================================
  // ===== HÀM _buildCommentItem ĐÃ ĐƯỢC THAY THẾ HOÀN TOÀN =====
  // ====================================================
  Widget _buildCommentItem(Comment comment) {
    final bool isMyComment = comment.userId == _currentUser?.uid;
    final bool enableLongPress = isPostOwner || isMyComment;
    final bool isReply = comment.parentId != null;
    final String? avatarUrl = comment.userAvatarUrl;
    final ImageProvider? avatarImage = (avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        avatarUrl.startsWith('http'))
        ? NetworkImage(avatarUrl)
        : null;

    return GestureDetector(
      onLongPress: enableLongPress ? () => _showCommentMenu(comment) : null,
      child: Padding(
        padding: EdgeInsets.only(
          top: 12.0,
          bottom: 12.0,
          left: isReply ? 50.0 : 0,
          right: 0,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _navigateToProfile(comment.userId),
              child: CircleAvatar(
                  radius: 18,
                  backgroundImage: avatarImage,
                  backgroundColor: darkSurface,
                  child: avatarImage == null
                      ? const Icon(Icons.person_outline,
                      size: 18, color: sonicSilver)
                      : null),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: darkSurface,
                        borderRadius: BorderRadius.circular(15)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => _navigateToProfile(comment.userId),
                          child: Text(
                            comment.displayName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          comment.text,
                          style: TextStyle(
                              color: Colors.white.withAlpha(230),
                              fontSize: 14,
                              height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Row(
                      children: [
                        Text(
                          // SỬA LỖI 1: Đổi tên hàm
                            _formatTimestampAgo(comment.timestamp),
                            style: const TextStyle(
                                color: sonicSilver, fontSize: 12)),
                        const SizedBox(width: 12),
                        Text('${comment.likesCount} Thích',
                            style: TextStyle(
                                color: sonicSilver,
                                fontSize: 12,
                                fontWeight: comment.likesCount > 0
                                    ? FontWeight.bold
                                    : FontWeight.normal)),

                        // SỬA LỖI 2: THÊM LẠI NÚT "TRẢ LỜI"
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _openCommentSheet, // <-- GỌI HÀM MỚI
                          child: const Text('Trả lời',
                              style: TextStyle(
                                  color: sonicSilver,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Nút Like (Thích)
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 4.0),
              child: IconButton(
                icon: Icon(
                    comment.isLiked
                        ? Icons.favorite
                        : Icons.favorite_border,
                    size: 16,
                    color: comment.isLiked ? coralRed : sonicSilver),
                onPressed: () => _toggleCommentLike(comment),
                splashRadius: 15,
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ),
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
  Widget build(BuildContext context) {
    final String postUserName = widget.postData['displayName'] ?? 'Bài viết';

    return Scaffold(      backgroundColor: Colors.black,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PostCard(
                postData: widget.postData,
              ),
              const Divider(color: darkSurface, height: 1, thickness: 1),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  'Bình luận',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),

              // Danh sách bình luận (StreamBuilder đã sửa)
              if (_postId.isNotEmpty)
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('posts').doc(_postId).collection('comments')
                      .orderBy('timestamp', descending: false) // SỬA: Sắp xếp cũ -> mới
                      .limit(50) // Tăng limit
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

                    // ===== LOGIC NHÓM BÌNH LUẬN CHA/CON (ĐÃ THÊM) =====
                    final List<Comment> topLevelComments = [];
                    final Map<String, List<Comment>> repliesMap = {};

                    for (final doc in commentDocs) {
                      try {
                        final comment = Comment.fromFirestore(doc, currentUserId);
                        if (comment.parentId == null) {
                          topLevelComments.add(comment);
                        } else {
                          if (repliesMap.containsKey(comment.parentId!)) {
                            repliesMap[comment.parentId!]!.add(comment);
                          } else {
                            repliesMap[comment.parentId!] = [comment];
                          }
                        }
                      } catch (e) {
                        developer.log("Lỗi parse comment: $e", name: 'PostDetailScreen');
                      }
                    }
                    // ===============================================

                    return ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: topLevelComments.length, // CHỈ HIỂN THỊ BÌNH LUẬN CHA
                      itemBuilder: (context, index) {
                        final parentComment = topLevelComments[index];
                        final replies = repliesMap[parentComment.id] ?? [];

                        // TRẢ VỀ MỘT CỤM (CHA + CON)
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCommentItem(parentComment), // Hàm đã nâng cấp
                            ...replies.map((reply) => _buildCommentItem(reply)), // Hàm đã nâng cấp
                          ],
                        );
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
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}
// lib/reel_comment_sheet.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // <--- Import Auth

// Constants (Giữ nguyên)
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C);

// Định nghĩa cấu trúc dữ liệu Comment (Giữ nguyên)
class Comment {
  // ... (Giữ nguyên định nghĩa Comment và factory fromFirestore)
  final String id; final String userId; final String userName; final String? userAvatarUrl; final String text; final Timestamp timestamp; final String? parentId; bool isLiked; int likesCount; final List<String> likedBy; Comment({required this.id, required this.userId, required this.userName, this.userAvatarUrl, required this.text, required this.timestamp, this.parentId, this.isLiked = false, required this.likesCount, required this.likedBy}); factory Comment.fromFirestore(DocumentSnapshot doc, String currentUserId){ Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {}; List<String> likedByList = List<String>.from(data['likedBy'] ?? []); return Comment( id: doc.id, userId: data['userId'] ?? '', userName: data['userName'] ?? 'Người dùng ẩn', userAvatarUrl: data['userAvatarUrl'], text: data['text'] ?? '', timestamp: data['timestamp'] ?? Timestamp.now(), parentId: data['parentId'], likesCount: (data['likesCount'] is num ? (data['likesCount'] as num).toInt() : 0), likedBy: likedByList, isLiked: currentUserId.isNotEmpty && likedByList.contains(currentUserId), ); }
}
// --- KẾT THÚC ĐỊNH NGHĨA COMMENT ---


// =======================================================
// WIDGET SHEET COMMENT CHO REEL (Đã cập nhật Firestore và Avatar)
// =======================================================
class ReelCommentSheetContent extends StatefulWidget {
  final String reelId; // ID của Reel
  final String reelUserName; // Tên người đăng Reel
  final int currentCommentCount; // Số lượng comment ban đầu (có thể lấy từ stream)
  final Function(int) onCommentPosted; // Callback khi đăng comment thành công
  final bool isReelOwner; // User hiện tại có phải chủ Reel không

  const ReelCommentSheetContent({
    super.key,
    required this.reelId,
    required this.reelUserName,
    required this.currentCommentCount,
    required this.onCommentPosted,
    required this.isReelOwner,
  });

  @override
  State<ReelCommentSheetContent> createState() => _ReelCommentSheetContentState();
}

class _ReelCommentSheetContentState extends State<ReelCommentSheetContent> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  Comment? _replyingToComment;
  bool _isSendButtonActive = false;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  Stream<DocumentSnapshot>? _reelDocStream;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _commentController.addListener(_updateSendButtonState);

    // Khởi tạo stream để lấy reel document (lấy comment count)
    if (widget.reelId.isNotEmpty) {
      _reelDocStream = _firestore.collection('reels').doc(widget.reelId).snapshots();
    }
  }

  @override
  void dispose() {
    _commentController.removeListener(_updateSendButtonState);
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _updateSendButtonState() { /* ... Giữ nguyên ... */ }
  void _postComment() async { /* ... Giữ nguyên logic Firestore ... */ }
  void _replyToComment(Comment comment) { /* ... Giữ nguyên logic UI ... */ }
  void _toggleCommentLike(Comment comment) async { /* ... Giữ nguyên logic Firestore ... */ }
  void _deleteComment(Comment comment) async { /* ... Giữ nguyên logic Firestore ... */ }
  String _formatTime(Timestamp timestamp) { /* ... Giữ nguyên ... */ return ''; }


  // Widget hiển thị một comment item (Cập nhật Avatar)
  Widget _buildCommentItem(Comment comment) {
    final bool isReply = comment.parentId != null;
    final bool isMyComment = comment.userId == _currentUser?.uid;
    // Quyền xóa: Chủ reel HOẶC chủ comment
    final bool canDelete = widget.isReelOwner || isMyComment;

    // Lấy avatar URL (có thể null)
    final String? avatarUrl = comment.userAvatarUrl;
    final ImageProvider? avatarImage = (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
        ? NetworkImage(avatarUrl)
        : null; // Không còn fallback AssetImage

    return GestureDetector(
      // Long Press để xóa (nếu có quyền)
      onLongPress: canDelete ? () => _deleteComment(comment) : null,
      child: Padding(
        padding: EdgeInsets.only(
          top: 10.0, bottom: 10.0,
          left: isReply ? 50.0 : 16.0, // Thụt lề reply
          right: 16.0,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar( // Avatar đã xử lý null
              radius: 18,
              backgroundImage: avatarImage, // Có thể null
              backgroundColor: darkSurface,
              // Hiển thị Icon nếu không có ảnh
              child: avatarImage == null
                  ? const Icon(Icons.person_outline, size: 18, color: sonicSilver)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded( // Nội dung comment
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row( // Tên và thời gian
                    children: [
                      Text( comment.userName, style: TextStyle(fontWeight: FontWeight.bold, color: isMyComment ? topazColor : Colors.white)),
                      const SizedBox(width: 8),
                      Text(_formatTime(comment.timestamp), style: const TextStyle(color: sonicSilver, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(comment.text, style: const TextStyle(color: Colors.white)), // Text comment
                  const SizedBox(height: 8),
                  Row( // Nút Reply và Like (Giữ nguyên)
                    children: [ /* ... Nút Reply, Like ... */ ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget ô nhập comment (Cập nhật Avatar)
  Widget _buildCommentInput() {
    // Lấy avatar người dùng hiện tại (URL hoặc null)
    final String? currentUserAvatarUrl = _currentUser?.photoURL;
    final ImageProvider? currentUserAvatar = (currentUserAvatarUrl != null && currentUserAvatarUrl.isNotEmpty)
        ? NetworkImage(currentUserAvatarUrl)
        : null; // Không còn fallback AssetImage

    return Container(
      padding: EdgeInsets.only(
        left: 16.0, right: 16.0, top: 12.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 10,
      ),
      color: Colors.black, // Nền đen
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner đang Reply (Giữ nguyên)
          if (_replyingToComment != null) Container( /* ... Banner Reply ... */ ),

          // Input Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CircleAvatar( // Avatar user hiện tại (đã xử lý null)
                radius: 20,
                backgroundImage: currentUserAvatar, // Có thể null
                backgroundColor: darkSurface,
                // Hiển thị Icon nếu không có ảnh
                child: currentUserAvatar == null
                    ? const Icon(Icons.person, color: sonicSilver, size: 20)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded( child: TextField( /* ... TextField ... */ ), ),
              const SizedBox(width: 8),
              // Sửa lỗi: Thêm icon và onPressed
              IconButton(
                icon: Icon(Icons.send_rounded, color: _isSendButtonActive ? topazColor : sonicSilver),
                onPressed: _isSendButtonActive ? _postComment : null,
                splashRadius: 20,
              ),

            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // StreamBuilder để lấy comment count (Giữ nguyên)
    final Stream<int> commentCountStream = _reelDocStream
        ?.map<int>((doc) => (doc.data() as Map<String, dynamic>?)?['commentsCount'] ?? widget.currentCommentCount)
        ?? Stream.value(widget.currentCommentCount);

    final String currentUserId = _currentUser?.uid ?? '';

    return Container(
      height: MediaQuery.of(context).size.height * (2 / 3),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        // ...
        children: [
          // Header Sheet
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, left: 16.0, right: 16.0), // Sửa lỗi: Thêm padding
            child: Column( // Sửa lỗi: Thêm child
              children: [
                // Drag Handle
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: darkSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 12),
                // Title (Comment Count) & Close Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 40), // Placeholder for alignment
                    StreamBuilder<int>(
                        stream: commentCountStream,
                        initialData: widget.currentCommentCount,
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? widget.currentCommentCount;
                          return Text(
                            '$count bình luận',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          );
                        }
                    ),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                        splashRadius: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: darkSurface, thickness: 1, height: 1),
// ...

          // Comment List (StreamBuilder giữ nguyên, _buildCommentItem đã cập nhật)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('reels').doc(widget.reelId).collection('comments')
                  .orderBy('timestamp', descending: true).limit(50).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) { /* Loading */ }
                if (snapshot.hasError) { /* Error */ }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) { /* No data */ }

                final commentDocs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 5),
                  itemCount: commentDocs.length,
                  itemBuilder: (context, index) {
                    try {
                      final comment = Comment.fromFirestore(commentDocs[index], currentUserId);
                      return _buildCommentItem(comment); // Đã cập nhật avatar
                    } catch (e) { print("Lỗi parse comment reel: $e"); return const SizedBox.shrink(); }
                  },
                );
              },
            ),
          ),

          // Input field (Đã cập nhật avatar)
          _buildCommentInput(),
        ],
      ),
    );
  }
}

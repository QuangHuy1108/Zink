// lib/comment_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // <--- Import Auth

// Định nghĩa lại cấu trúc dữ liệu Comment (Giữ nguyên)
class Comment {
  // ... (Giữ nguyên định nghĩa Comment và factory fromFirestore)
  final String id; final String userId; final String userName; final String? userAvatarUrl; final String text; final Timestamp timestamp; final String? parentId; bool isLiked; int likesCount; final List<String> likedBy; Comment({required this.id, required this.userId, required this.userName, this.userAvatarUrl, required this.text, required this.timestamp, this.parentId, this.isLiked = false, required this.likesCount, required this.likedBy}); factory Comment.fromFirestore(DocumentSnapshot doc, String currentUserId){ Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {}; List<String> likedByList = List<String>.from(data['likedBy'] ?? []); return Comment( id: doc.id, userId: data['userId'] ?? '', userName: data['userName'] ?? 'Người dùng ẩn', userAvatarUrl: data['userAvatarUrl'], text: data['text'] ?? '', timestamp: data['timestamp'] ?? Timestamp.now(), parentId: data['parentId'], likesCount: (data['likesCount'] is num ? (data['likesCount'] as num).toInt() : 0), likedBy: likedByList, isLiked: currentUserId.isNotEmpty && likedByList.contains(currentUserId), ); }
}

class CommentBottomSheetContent extends StatefulWidget {
  final String postId;
  final String postUserName;
  final int currentCommentCount;
  final String? postMediaUrl; // URL ảnh bài post (có thể null)
  final Function(int) onCommentPosted;
  final String postCaption;
  final bool isPostOwner;

  const CommentBottomSheetContent({
    super.key,
    required this.postId,
    required this.postUserName,
    required this.currentCommentCount,
    required this.onCommentPosted,
    this.postMediaUrl, // Chấp nhận null
    required this.isPostOwner,
    this.postCaption = '',
  });

  @override
  State<CommentBottomSheetContent> createState() => _CommentBottomSheetContentState();
}

class _CommentBottomSheetContentState extends State<CommentBottomSheetContent> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  Comment? _replyingToComment;
  bool _isSendButtonActive = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  // Constants
  static const Color topazColor = Color(0xFFF6C886);
  static const Color sonicSilver = Color(0xFF747579);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color coralRed = Color(0xFFFD402C);

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _commentController.addListener(_updateSendButtonState);
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
  void _toggleCommentLike(Comment comment) async { /* ... Giữ nguyên logic Firestore ... */ }
  void _replyToComment(Comment comment) { /* ... Giữ nguyên logic UI ... */ }
  String _formatTime(Timestamp timestamp) { /* ... Giữ nguyên logic format ... */ return ''; }
  void _showCommentMenu(Comment comment) { /* ... Giữ nguyên logic UI ... */ }
  void _showDeletionReasonDialog(Comment comment) { /* ... Giữ nguyên logic UI ... */ }
  Widget _buildReasonOption(BuildContext context, String reason, Comment comment) { /* ... Giữ nguyên logic UI ... */ return ListTile(); }
  void _deleteComment(Comment comment, String reason) async { /* ... Giữ nguyên logic Firestore ... */ }

  // Widget hiển thị một comment item (Cập nhật Avatar)
  Widget _buildCommentItem(Comment comment) {
    final bool isReply = comment.parentId != null;
    final bool isMyComment = comment.userId == _currentUser?.uid;
    final bool enableLongPress = widget.isPostOwner || isMyComment;

    // Lấy avatar URL (có thể null)
    final String? avatarUrl = comment.userAvatarUrl;
    final ImageProvider? avatarImage = (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
        ? NetworkImage(avatarUrl)
        : null; // Không còn fallback AssetImage

    return GestureDetector(
      onLongPress: enableLongPress ? () => _showCommentMenu(comment) : null,
      child: Padding(
        padding: EdgeInsets.only( top: 10.0, bottom: 10.0, left: isReply ? 50.0 : 16.0, right: 16.0 ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar( // Avatar đã xử lý null
              radius: 18,
              backgroundImage: avatarImage, // Có thể null
              backgroundColor: darkSurface,
              child: avatarImage == null
                  ? const Icon(Icons.person_outline, size: 18, color: sonicSilver) // Fallback Icon
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded( child: Column( /* ... Nội dung comment, nút Reply/Like ... */ ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget hiển thị thông tin bài post (Cập nhật Avatar và Media)
  Widget _buildPostView() {
    // Lấy avatar chủ post (từ Firestore user hoặc null)
    // Tạm thời dùng Icon placeholder
    final ImageProvider? postOwnerAvatar = null; // Cần logic lấy URL thật
    final String? postMediaUrl = widget.postMediaUrl; // Lấy URL media (có thể null)

    // Xác định ImageProvider cho media (có thể null)
    final ImageProvider? mediaProvider = (postMediaUrl != null && postMediaUrl.isNotEmpty && postMediaUrl.startsWith('http'))
        ? NetworkImage(postMediaUrl)
        : null;

    return Container(
      padding: const EdgeInsets.only(top: 10, left: 16, right: 16),
      color: Colors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row( // Header
            children: [
              CircleAvatar( // Avatar chủ post (đã xử lý null)
                radius: 20,
                backgroundImage: postOwnerAvatar, // Có thể null
                backgroundColor: darkSurface,
                child: postOwnerAvatar == null ? const Icon(Icons.person, color: sonicSilver, size: 20) : null,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.postUserName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  // Giả lập username từ tên người dùng
                  Text("@${widget.postUserName.toLowerCase().replaceAll(' ', '')}", style: const TextStyle(color: sonicSilver, fontSize: 13)),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // CAPTION (Giữ nguyên)
          if (widget.postCaption.isNotEmpty) /* ... Caption ... */
          if (widget.postCaption.isEmpty) const SizedBox(height: 5),

          // Hình ảnh/Media Gốc (Hiển thị ảnh hoặc placeholder)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: darkSurface, // Màu nền chờ
              ),
              // Hiển thị ảnh nếu có, ngược lại là placeholder
              child: mediaProvider != null
                  ? Image(
                image: mediaProvider,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: sonicSilver, size: 40)),
              )
                  : const Center(child: Icon(Icons.image_not_supported, color: sonicSilver, size: 50)), // Placeholder
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: darkSurface, height: 1, thickness: 1),
        ],
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
      padding: EdgeInsets.only( left: 16.0, right: 16.0, top: 12.0,
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 10 ),
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner đang Reply (Giữ nguyên)
          if (_replyingToComment != null) Container( /* ... Banner Reply ... */ ),

          Row( // Input Row
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CircleAvatar( // Avatar user hiện tại (đã xử lý null)
                radius: 20,
                backgroundImage: currentUserAvatar, // Có thể null
                backgroundColor: darkSurface,
                child: currentUserAvatar == null ? const Icon(Icons.person, color: sonicSilver, size: 20) : null, // Fallback Icon
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  focusNode: _commentFocusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  maxLines: 4, // Cho phép nhiều dòng
                  minLines: 1, // Tối thiểu 1 dòng
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: _replyingToComment != null ? 'Trả lời ${(_replyingToComment!.userName)}...' : 'Thêm bình luận...',
                    hintStyle: const TextStyle(color: sonicSilver, fontSize: 15),
                    filled: true,
                    fillColor: darkSurface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: darkSurface.withOpacity(0.5))),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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

  // Widget chứa danh sách comment (Giữ nguyên StreamBuilder, _buildCommentItem đã cập nhật)
  Widget _buildCommentSection(int commentCount) {
    final String currentUserId = _auth.currentUser?.uid ?? '';
    return Container(
      decoration: BoxDecoration( color: Colors.black ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, left: 16.0, right: 16.0),
            child: Column(
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
                // Title (Comment Count)
                Text(
                  '$commentCount bình luận',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          const Divider(color: darkSurface, height: 1, thickness: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('posts').doc(widget.postId).collection('comments')
                  .orderBy('timestamp', descending: false).snapshots(),
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
                      return _buildCommentItem(comment); // _buildCommentItem đã cập nhật avatar
                    } catch (e) { print("Lỗi parse comment: $e"); return const SizedBox.shrink(); }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Stream lấy comment count (Giữ nguyên)
    final commentCountStream = _firestore.collection('posts').doc(widget.postId)
        .collection('comments').snapshots().map((snapshot) => snapshot.size);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        constraints: BoxConstraints( maxHeight: MediaQuery.of(context).size.height * 0.95 ),
        decoration: const BoxDecoration( color: Colors.black, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // Phần bài viết gốc (đã cập nhật)
              Flexible( flex: 4, child: _buildPostView()),
              // Phần comment (đã cập nhật)
              Flexible(
                flex: 6,
                child: StreamBuilder<int>(
                    stream: commentCountStream, initialData: widget.currentCommentCount,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? widget.currentCommentCount;
                      return _buildCommentSection(count);
                    }
                ),
              ),
              // Thanh nhập liệu (đã cập nhật)
              _buildCommentInput(),
            ],
          ),
        ),
      ),
    );
  }
}

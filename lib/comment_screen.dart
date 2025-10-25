import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // <--- Import Auth

// Constants
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C);

// Định nghĩa lại cấu trúc dữ liệu Comment
class Comment {
  final String id; final String userId; final String userName; final String? userAvatarUrl; final String text; final Timestamp timestamp; final String? parentId; bool isLiked; int likesCount; final List<String> likedBy;

  Comment({required this.id, required this.userId, required this.userName, this.userAvatarUrl, required this.text, required this.timestamp, this.parentId, this.isLiked = false, required this.likesCount, required this.likedBy});

  factory Comment.fromFirestore(DocumentSnapshot doc, String currentUserId){
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    List<String> likedByList = List<String>.from(data['likedBy'] ?? []);

    return Comment(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Người dùng ẩn',
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

  // 1. Kích hoạt nút gửi
  void _updateSendButtonState() {
    final isActive = _commentController.text.trim().isNotEmpty;
    if (isActive != _isSendButtonActive) {
      setState(() {
        _isSendButtonActive = isActive;
      });
    }
  }

  // 2. Logic đăng bình luận lên Firestore
  void _postComment() async {
    final text = _commentController.text.trim();
    final user = _currentUser;

    if (text.isEmpty || user == null) return;
    FocusScope.of(context).unfocus();

    final userName = user.displayName ?? user.email?.split('@').first ?? 'Người dùng Zink';
    final userAvatarUrl = user.photoURL;
    final parentId = _replyingToComment?.id;

    _commentController.clear();
    setState(() { _replyingToComment = null; }); // Reset trạng thái reply

    try {
      // 1. Thêm comment vào subcollection 'comments'
      await _firestore.collection('posts').doc(widget.postId).collection('comments').add({
        'userId': user.uid,
        'userName': userName,
        'userAvatarUrl': userAvatarUrl,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'parentId': parentId,
        'likesCount': 0,
        'likedBy': [],
      });

      // 2. Tăng commentsCount trên post chính
      final postRef = _firestore.collection('posts').doc(widget.postId);
      await postRef.update({'commentsCount': FieldValue.increment(1)});

      // 3. Thông báo cho PostCard để cập nhật count
      widget.onCommentPosted(widget.currentCommentCount + 1);

    } catch (e) {
      print("Lỗi đăng bình luận: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi khi đăng bình luận.'), backgroundColor: coralRed));
    }
  }

  // 3. Logic Thích/Bỏ thích bình luận
  void _toggleCommentLike(Comment comment) async {
    final user = _currentUser;
    if (user == null) return;

    final commentRef = _firestore.collection('posts').doc(widget.postId).collection('comments').doc(comment.id);
    final isLiking = !comment.isLiked;

    final updateData = isLiking
        ? {'likedBy': FieldValue.arrayUnion([user.uid]), 'likesCount': FieldValue.increment(1)}
        : {'likedBy': FieldValue.arrayRemove([user.uid]), 'likesCount': FieldValue.increment(-1)};

    try {
      await commentRef.update(updateData);
      // Không cần setState ở đây vì StreamBuilder sẽ tự động cập nhật lại UI
    } catch (e) {
      print("Lỗi thích/bỏ thích bình luận: $e");
    }
  }

  // 4. Bắt đầu trả lời bình luận
  void _replyToComment(Comment comment) {
    setState(() {
      _replyingToComment = comment;
      _commentFocusNode.requestFocus();
    });
  }

  // 5. Định dạng thời gian
  String _formatTime(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'Vừa xong';
    if (difference.inMinutes < 60) return '${difference.inMinutes} phút';
    if (difference.inHours < 24) return '${difference.inHours} giờ';
    if (difference.inDays < 30) return '${difference.inDays} ngày';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  // 6. Xử lý Menu (Xóa bình luận)
  void _showCommentMenu(Comment comment) {
    final isMyComment = comment.userId == _currentUser?.uid;

    showModalBottomSheet(
      context: context,
      backgroundColor: darkSurface,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMyComment || widget.isPostOwner)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: coralRed),
                  title: const Text('Xóa bình luận', style: TextStyle(color: coralRed)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showDeletionReasonDialog(comment);
                  },
                ),
              if (!isMyComment)
                ListTile(
                  leading: const Icon(Icons.report_problem_outlined, color: sonicSilver),
                  title: const Text('Báo cáo bình luận', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã báo cáo bình luận.'), backgroundColor: sonicSilver));
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close, color: sonicSilver),
                title: const Text('Hủy', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        );
      },
    );
  }

  // 7. Dialog xác nhận xóa
  void _showDeletionReasonDialog(Comment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: darkSurface,
          title: const Text('Xóa bình luận', style: TextStyle(color: Colors.white)),
          content: const Text('Bạn có chắc chắn muốn xóa bình luận này không?', style: TextStyle(color: sonicSilver)),
          actions: [
            TextButton(
              child: const Text('Hủy', style: TextStyle(color: sonicSilver)),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('Xóa', style: TextStyle(color: coralRed)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _deleteComment(comment);
    }
  }

  // 8. Logic xóa comment
  void _deleteComment(Comment comment) async {
    try {
      // 1. Xóa comment trong subcollection
      await _firestore.collection('posts').doc(widget.postId).collection('comments').doc(comment.id).delete();

      // 2. Giảm commentsCount trên post chính
      final postRef = _firestore.collection('posts').doc(widget.postId);
      await postRef.update({'commentsCount': FieldValue.increment(-1)});

      // 3. Thông báo cho PostCard để cập nhật count
      widget.onCommentPosted(widget.currentCommentCount - 1);

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa bình luận.'), backgroundColor: sonicSilver));
    } catch (e) {
      print("Lỗi xóa bình luận: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi: Không thể xóa bình luận.'), backgroundColor: coralRed));
    }
  }

  // Widget hiển thị một comment item (Cập nhật Avatar)
  Widget _buildCommentItem(Comment comment) {
    final bool isReply = comment.parentId != null;
    final bool isMyComment = comment.userId == _currentUser?.uid;
    // Chỉ cho phép long press nếu là chủ post hoặc chủ comment
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                      text: TextSpan(
                          style: const TextStyle(fontSize: 14, color: Colors.white),
                          children: [
                            TextSpan(
                                text: comment.userName,
                                style: TextStyle(fontWeight: FontWeight.bold, color: isMyComment ? topazColor : Colors.white)
                            ),
                            const TextSpan(text: ' '),
                            TextSpan(text: comment.text),
                          ]
                      )
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(_formatTime(comment.timestamp), style: const TextStyle(color: sonicSilver, fontSize: 12)),
                      const SizedBox(width: 10),
                      Text('${comment.likesCount} Thích', style: const TextStyle(color: sonicSilver, fontSize: 12)),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _replyToComment(comment),
                        child: const Text('Trả lời', style: TextStyle(color: sonicSilver, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Nút Like nhỏ bên phải
            GestureDetector(
              onTap: () => _toggleCommentLike(comment),
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                child: Icon(
                  comment.isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 14,
                  color: comment.isLiked ? coralRed : sonicSilver,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget hiển thị thông tin bài post (Cần logic lấy avatar chủ post)
  Widget _buildPostView() {
    // Tạm thời dùng Icon placeholder cho Avatar chủ post (logic phức tạp hơn)
    final ImageProvider? postOwnerAvatar = null;
    final String? postMediaUrl = widget.postMediaUrl;

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

          // CAPTION
          if (widget.postCaption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Text(widget.postCaption, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ),

          // Hình ảnh/Media Gốc (Hiển thị ảnh hoặc placeholder)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: darkSurface,
              ),
              child: mediaProvider != null
                  ? Image(
                image: mediaProvider,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: sonicSilver, size: 40)),
              )
                  : const Center(child: Icon(Icons.image_not_supported, color: sonicSilver, size: 50)),
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
        : null;

    return Container(
      padding: EdgeInsets.only( left: 16.0, right: 16.0, top: 12.0,
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 10 ),
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner đang Reply
          if (_replyingToComment != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: darkSurface.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Text('Trả lời ${_replyingToComment!.userName}:', style: const TextStyle(color: sonicSilver, fontSize: 13)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() { _replyingToComment = null; _commentFocusNode.unfocus(); }),
                    child: const Icon(Icons.close, size: 16, color: sonicSilver),
                  )
                ],
              ),
            ),

          Row( // Input Row
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CircleAvatar( // Avatar user hiện tại
                radius: 20,
                backgroundImage: currentUserAvatar,
                backgroundColor: darkSurface,
                child: currentUserAvatar == null ? const Icon(Icons.person, color: sonicSilver, size: 20) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  focusNode: _commentFocusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: _replyingToComment != null ? 'Viết trả lời...' : 'Thêm bình luận...',
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
      decoration: const BoxDecoration( color: Colors.black ),
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: topazColor));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Lỗi tải bình luận: ${snapshot.error}', style: const TextStyle(color: coralRed)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('Hãy là người đầu tiên bình luận!', style: TextStyle(color: sonicSilver.withOpacity(0.7))));
                }

                final commentDocs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 5),
                  itemCount: commentDocs.length,
                  itemBuilder: (context, index) {
                    try {
                      final comment = Comment.fromFirestore(commentDocs[index], currentUserId);
                      return _buildCommentItem(comment); // _buildCommentItem đã cập nhật avatar
                    } catch (e) {
                      print("Lỗi parse comment: $e");
                      return const SizedBox.shrink();
                    }
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
    // Stream lấy comment count
    final commentCountStream = _firestore.collection('posts').doc(widget.postId)
        .snapshots().map((doc) => (doc.data()?['commentsCount'] as num?)?.toInt() ?? widget.currentCommentCount);

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

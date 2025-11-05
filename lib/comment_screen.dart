import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'models/comment_model.dart';
import 'utils/app_colors.dart';

// TODO: Consider using a dedicated logging package like 'logger' for better error handling.

class CommentBottomSheetContent extends StatefulWidget {
  final String postId;
  final String postUserName;
  final int currentCommentCount;
  final String? postMediaUrl;
  final Function(int) onCommentPosted;
  final String postCaption;
  final bool isPostOwner;

  const CommentBottomSheetContent({
    super.key,
    required this.postId,
    required this.postUserName,
    required this.currentCommentCount,
    required this.onCommentPosted,
    this.postMediaUrl,
    required this.isPostOwner,
    this.postCaption = '',
  });

  @override
  State<CommentBottomSheetContent> createState() =>
      _CommentBottomSheetContentState();
}

class _CommentBottomSheetContentState extends State<CommentBottomSheetContent> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  Comment? _replyingToComment;
  bool _isSendButtonActive = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

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

  void _updateSendButtonState() {
    final isActive = _commentController.text.trim().isNotEmpty;
    if (isActive != _isSendButtonActive) {
      if (mounted) {
        setState(() => _isSendButtonActive = isActive);
      }
    }
  }

  void _postComment() async {
    final text = _commentController.text.trim();
    final user = _currentUser;
    if (text.isEmpty || user == null) return;
    FocusScope.of(context).unfocus();

    // Start of modification: More robust user info fetching
    String displayName = 'Người dùng ẩn'; // Default value
    String? photoURL;

    // 1. Prioritize fetching from Firestore as it's likely the most updated source.
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        displayName = userData['displayName'] ?? displayName;
        photoURL = userData['photoURL'] ?? photoURL;
      }
    } catch (e) {
      developer.log("Error fetching user data from Firestore for comment: $e",
          name: 'CommentBottomSheet');
    }

    // 2. Fallback to FirebaseAuth data if Firestore data is not available.
    if (displayName == 'Người dùng ẩn' && user.displayName != null) {
        displayName = user.displayName!;
    }
    photoURL ??= user.photoURL;
    // End of modification

    final parentId = _replyingToComment?.id;

    _commentController.clear();
    if (mounted) setState(() => _replyingToComment = null);

    try {
      // 1. Save comment to the post's sub-collection
      final newCommentRef = await _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'userId': user.uid,
        'displayName': displayName,
        'userAvatarUrl': photoURL,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'parentId': parentId,
        'likesCount': 0,
        'likedBy': [],
      });

      final WriteBatch batch = _firestore.batch();

      // 2. Update the post's comment count
      final postRef = _firestore.collection('posts').doc(widget.postId);
      batch.update(postRef, {'commentsCount': FieldValue.increment(1)});

      // 3. Get post data to find the owner and create a notification
      final postSnapshot = await postRef.get();
      if (postSnapshot.exists) {
        final postData = postSnapshot.data() as Map<String, dynamic>;
        final postOwnerId = postData['uid'] as String?;

        // 4. Create notification if the commenter is not the post owner
        if (postOwnerId != null && postOwnerId != user.uid) {
          final notificationRef = _firestore
              .collection('users')
              .doc(postOwnerId)
              .collection('notifications')
              .doc();
          batch.set(notificationRef, {
            'type': 'comment',
            'senderId': user.uid,
            'senderName': displayName,
            'senderAvatarUrl': photoURL,
            'destinationId': widget.postId,
            'commentId': newCommentRef.id,
            'contentPreview': text,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }

        // 5. Create notification for the replied-to comment's author
        if (_replyingToComment != null &&
            _replyingToComment!.userId != user.uid &&
            _replyingToComment!.userId != postOwnerId) {
          final replyNotificationRef = _firestore
              .collection('users')
              .doc(_replyingToComment!.userId)
              .collection('notifications')
              .doc();
          batch.set(replyNotificationRef, {
            'type': 'reply',
            'senderId': user.uid,
            'senderName': displayName,
            'senderAvatarUrl': photoURL,
            'destinationId': widget.postId,
            'commentId': newCommentRef.id,
            'contentPreview': text,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
      }

      // 6. Commit all batch operations
      await batch.commit();

      // 7. Update UI
      widget.onCommentPosted(widget.currentCommentCount + 1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Lỗi khi đăng bình luận.'),
            backgroundColor: coralRed));
      }
      developer.log("Error posting comment: $e", name: 'CommentBottomSheet');
    }
  }

  void _toggleCommentLike(Comment comment) async {
    final userId = _currentUser?.uid;
    if (userId == null) return;

    final commentRef = _firestore
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(comment.id);
    final isCurrentlyLiked = comment.isLiked;

    // Optimistic UI update
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
      // Revert UI on error
      if (mounted) {
        setState(() {
          comment.isLiked = isCurrentlyLiked;
          isCurrentlyLiked ? comment.likesCount++ : comment.likesCount--;
        });
      }
      developer.log("Error toggling comment like: $e",
          name: 'CommentBottomSheet');
    }
  }

  void _replyToComment(Comment comment) => setState(() {
        _replyingToComment = comment;
        _commentFocusNode.requestFocus();
      });

  String _formatTime(Timestamp timestamp) {
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
    if (diff.inHours < 24) return '${diff.inHours} giờ';
    return '${diff.inDays} ngày';
  }

  void _showCommentMenu(Comment comment) {
    final isMyComment = comment.userId == _currentUser?.uid;
    showModalBottomSheet(
      context: context,
      backgroundColor: darkSurface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (isMyComment || widget.isPostOwner)
            ListTile(
                leading: const Icon(Icons.delete_outline, color: coralRed),
                title: const Text('Xóa bình luận',
                    style: TextStyle(color: coralRed)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeletionReasonDialog(comment);
                }),
          if (!isMyComment)
            ListTile(
                leading: const Icon(Icons.report_problem_outlined,
                    color: sonicSilver),
                title: const Text('Báo cáo bình luận',
                    style: TextStyle(color: Colors.white)),
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

  void _showDeletionReasonDialog(Comment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: darkSurface,
        title:
            const Text('Xóa bình luận', style: TextStyle(color: Colors.white)),
        content: const Text('Bạn có chắc chắn muốn xóa bình luận này không?',
            style: TextStyle(color: sonicSilver)),
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

  void _deleteComment(Comment comment) async {
    try {
      // Use a batch to ensure atomicity
      final WriteBatch batch = _firestore.batch();

      final commentRef = _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(comment.id);
      batch.delete(commentRef);

      final postRef = _firestore.collection('posts').doc(widget.postId);
      batch.update(postRef, {'commentsCount': FieldValue.increment(-1)});

      await batch.commit();

      widget.onCommentPosted(widget.currentCommentCount - 1);
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
      developer.log("Error deleting comment: $e", name: 'CommentBottomSheet');
    }
  }

  Widget _buildCommentItem(Comment comment) {
    final bool isMyComment = comment.userId == _currentUser?.uid;
    final bool enableLongPress = widget.isPostOwner || isMyComment;
    final String? avatarUrl = comment.userAvatarUrl;
    final ImageProvider? avatarImage = (avatarUrl != null &&
            avatarUrl.isNotEmpty &&
            avatarUrl.startsWith('http'))
        ? NetworkImage(avatarUrl)
        : null;

    return GestureDetector(
      onLongPress: enableLongPress ? () => _showCommentMenu(comment) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
                radius: 18,
                backgroundImage: avatarImage,
                backgroundColor: darkSurface,
                child: avatarImage == null
                    ? const Icon(Icons.person_outline,
                        size: 18, color: sonicSilver)
                    : null),
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
                        Text(
                          comment.userName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 14),
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
                        Text(_formatTime(comment.timestamp),
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
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => _replyToComment(comment),
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

  Widget _buildPostView() {
    final String? postMediaUrl = widget.postMediaUrl;
    final ImageProvider? mediaProvider = (postMediaUrl != null &&
            postMediaUrl.isNotEmpty &&
            postMediaUrl.startsWith('http'))
        ? NetworkImage(postMediaUrl)
        : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: Colors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                  radius: 20,
                  backgroundColor: darkSurface,
                  child: Text(
                      widget.postUserName.isNotEmpty
                          ? widget.postUserName[0]
                          : 'U',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
              const SizedBox(width: 10),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.postUserName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text("@${widget.postUserName.toLowerCase().replaceAll(' ', '')}",
                        style:
                            const TextStyle(color: sonicSilver, fontSize: 13))
                  ]),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  splashRadius: 20)
            ],
          ),
          const SizedBox(height: 12),
          if (widget.postCaption.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(widget.postCaption,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14))),
          if (mediaProvider != null)
            Container(
              height: MediaQuery.of(context).size.height * 0.4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: darkSurface,
                image: DecorationImage(image: mediaProvider, fit: BoxFit.cover),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentSection(List<Comment> comments) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Text('${comments.length} bình luận',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer()
            ],
          ),
        ),
        const Divider(color: darkSurface, height: 1),
        Expanded(
          child: comments.isEmpty
              ? const Center(
                  child: Text("Chưa có bình luận nào.",
                      style: TextStyle(color: sonicSilver)))
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: comments.length,
                  itemBuilder: (context, index) =>
                      _buildCommentItem(comments[index])),
        )
      ],
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12),
      decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(top: BorderSide(color: darkSurface, width: 1.0))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingToComment != null)
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                      child: Text('Đang trả lời ${_replyingToComment!.userName}',
                          style: const TextStyle(
                              color: sonicSilver, fontSize: 12),
                          overflow: TextOverflow.ellipsis)),
                  GestureDetector(
                    onTap: () => setState(() => _replyingToComment = null),
                    child: const Icon(Icons.close, color: sonicSilver, size: 16),
                  )
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  focusNode: _commentFocusNode,
                  style: const TextStyle(color: Colors.white),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: _replyingToComment != null
                        ? 'Thêm câu trả lời...'
                        : 'Thêm bình luận...',
                    hintStyle: TextStyle(color: sonicSilver.withAlpha(178)),
                    filled: true,
                    fillColor: darkSurface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    _isSendButtonActive ? topazColor : sonicSilver.withAlpha(100),
                child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.black, size: 20),
                    onPressed: _isSendButtonActive ? _postComment : null),
              )
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
        child: Container(
          color: const Color(0xFF121212),
          child: Column(
            children: [
              _buildPostView(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('posts')
                      .doc(widget.postId)
                      .collection('comments')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(color: topazColor));
                    }
                    if (snapshot.hasError) {
                      developer.log("Error in comment stream: ${snapshot.error}",
                          name: 'CommentBottomSheet');
                      return const Center(
                          child: Text("Lỗi tải bình luận.",
                              style: TextStyle(color: sonicSilver)));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildCommentSection([]);
                    }
                    final comments = snapshot.data!.docs
                        .map((doc) =>
                            Comment.fromFirestore(doc, _currentUser?.uid ?? ''))
                        .toList();
                    return _buildCommentSection(comments);
                  },
                ),
              ),
              _buildCommentInput(),
            ],
          ),
        ),
      ),
    );
  }
}

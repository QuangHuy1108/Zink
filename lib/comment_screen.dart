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

    // Start of modification: More robust user info fetching (GIỮ NGUYÊN)
    String displayName = 'Người dùng ẩn'; // Default value
    String? photoURL;
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
    if (displayName == 'Người dùng ẩn' && user.displayName != null) {
      displayName = user.displayName!;
    }
    photoURL ??= user.photoURL;
    // End of modification

    // --- BẮT ĐẦU SỬA LOGIC PARENTID ---
    String? finalParentId;
    String? repliedToUserId;

    if (_replyingToComment != null) {
      // Lấy ID của người mình đang trả lời (để gửi thông báo)
      repliedToUserId = _replyingToComment!.userId;

      // Logic "Flattening":
      // Nếu bình luận mình đang reply ĐÃ LÀ CON (có parentId),
      // thì parentId của bình luận MỚI = parentId của bình luận đó (tức là Id của "cha").
      if (_replyingToComment!.parentId != null) {
        finalParentId = _replyingToComment!.parentId;
      } else {
        // Nếu bình luận mình đang reply LÀ CHA (parentId == null),
        // thì parentId của bình luận MỚI = Id của bình luận đó.
        finalParentId = _replyingToComment!.id;
      }
    }
    // --- KẾT THÚC SỬA LOGIC PARENTID ---

    _commentController.clear();

    _commentController.clear();
    if (mounted) setState(() => _replyingToComment = null);

    try {
      // 1. Save comment to the post's sub-collection (GIỮ NGUYÊN)
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
        'parentId': finalParentId,
        'likesCount': 0,
        'likedBy': [],
        // TODO: Bạn nên thêm 'username' ở đây nếu dùng logic tag
      });

      final WriteBatch batch = _firestore.batch();

      // 2. Update the post's comment count (GIỮ NGUYÊN)
      final postRef = _firestore.collection('posts').doc(widget.postId);
      batch.update(postRef, {'commentsCount': FieldValue.increment(1)});

      // 3. Get post data to find the owner (GIỮ NGUYÊN)
      final postSnapshot = await postRef.get();
      if (!postSnapshot.exists) {
        // Nếu post không tồn tại, chỉ commit batch và thoát
        await batch.commit();
        widget.onCommentPosted(widget.currentCommentCount + 1);
        return;
      }

      final postData = postSnapshot.data() as Map<String, dynamic>;
      final postOwnerId = postData['uid'] as String?;

      // --- BẮT ĐẦU LOGIC THÔNG BÁO ĐÃ SỬA ---

      bool postOwnerWasNotified = false; // Cờ để tránh 2 thông báo

      // 4. (ƯU TIÊN) Gửi thông báo cho người được trả lời
      if (repliedToUserId != null && repliedToUserId != user.uid) {

        // Nếu người được trả lời chính là chủ post, đánh dấu đã thông báo
        if (repliedToUserId == postOwnerId) {
          postOwnerWasNotified = true;
        }

        final replyNotificationRef = _firestore
            .collection('users')
            .doc(repliedToUserId) // Gửi cho người được trả lời
            .collection('notifications')
            .doc();

        batch.set(replyNotificationRef, {
          'type': 'reply', // <-- Luôn là 'reply'
          'senderId': user.uid,
          'senderName': displayName,
          'senderAvatarUrl': photoURL,
          'destinationId': widget.postId,
          'commentId': newCommentRef.id,
          'contentPreview': 'đã nhắc đến bạn trong một bình luận.',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      // 5. Gửi thông báo cho chủ bài viết (NẾU chưa được thông báo ở bước 4)
      if (postOwnerId != null &&
          postOwnerId != user.uid &&
          !postOwnerWasNotified) { // <-- Kiểm tra cờ

        final notificationRef = _firestore
            .collection('users')
            .doc(postOwnerId)
            .collection('notifications')
            .doc();
        batch.set(notificationRef, {
          'type': 'comment', // <-- Chỉ là 'comment' (vì là bình luận gốc)
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

      // (Nếu bạn có logic tag @username, nó sẽ nằm ở đây,
      // và cũng cần kiểm tra
      // userIdToNotify != repliedToUserId && userIdToNotify != postOwnerId)

      // --- KẾT THÚC LOGIC THÔNG BÁO ĐÃ SỬA ---

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

  void _replyToComment(Comment comment) {
    // Sửa ở đây: Dùng comment.username thay vì comment.userName
    final String tag = '@${comment.username} ';

    setState(() {
      _replyingToComment = comment;
      _commentController.text = tag;
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: _commentController.text.length),
      );
      _commentFocusNode.requestFocus();
    });
  }

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
      final WriteBatch batch = _firestore.batch();
      final postRef = _firestore.collection('posts').doc(widget.postId);
      final commentsCollection = postRef.collection('comments');

      // 1. Tham chiếu đến bình luận cần xóa
      final commentRef = commentsCollection.doc(comment.id);

      // 2. LOGIC MỚI: Nếu đây là bình luận cha (parentId là null),
      //    hãy tìm và "thăng cấp" (promote) tất cả các con của nó.
      if (comment.parentId == null) {
        // Tìm tất cả bình luận có parentId trỏ đến bình luận này
        final repliesSnapshot = await commentsCollection
            .where('parentId', isEqualTo: comment.id)
            .get();

        // Cập nhật 'parentId' của chúng thành null để biến chúng thành bình luận cha
        for (final replyDoc in repliesSnapshot.docs) {
          batch.update(replyDoc.reference, {'parentId': null});
        }
      }

      // 3. Xóa chính bình luận này (dù là cha hay con)
      batch.delete(commentRef);

      // 4. Cập nhật post count (luôn chỉ trừ 1, vì chúng ta không xóa con)
      batch.update(postRef, {'commentsCount': FieldValue.increment(-1)});

      // 5. Thực thi tất cả các lệnh
      await batch.commit();

      // 6. Cập nhật UI (chỉ trừ 1)
      // Lưu ý: Các bình luận con sẽ tự động xuất hiện
      // ở cấp cao nhất trong lần build lại tiếp theo.
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
      developer.log("Error deleting comment (promoting replies): $e", name: 'CommentBottomSheet');
    }
  }

  Widget _buildCommentItem(Comment comment) {
    final bool isMyComment = comment.userId == _currentUser?.uid;
    final bool enableLongPress = widget.isPostOwner || isMyComment;
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
          left: isReply ? 50.0 : 16.0, // Thụt lề 50.0 nếu là reply
          right: 16.0,
        ),
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

// DÁN CODE MỚI NÀY VÀO
  Widget _buildCommentSection(List<DocumentSnapshot> docs) { // Nhận vào List<DocumentSnapshot>
    final String currentUserId = _currentUser?.uid ?? '';

    // --- BẮT ĐẦU LOGIC MỚI ---

    // 1. Chuẩn bị 2 danh sách:
    //    - một cho bình luận cha (topLevelComments)
    //    - một cho bình luận con (repliesMap)
    final List<Comment> topLevelComments = [];
    final Map<String, List<Comment>> repliesMap = {};

    // 2. Lọc và phân loại tất cả bình luận
    for (final doc in docs) {
      try {
        final comment = Comment.fromFirestore(doc, currentUserId);

        // Kiểm tra xem bình luận có parentId không
        if (comment.parentId == null) {
          // Nếu KHÔNG, nó là bình luận cha
          topLevelComments.add(comment);
        } else {
          // Nếu CÓ, nó là bình luận con
          // Thêm nó vào danh sách trả lời của cha nó
          if (repliesMap.containsKey(comment.parentId!)) {
            repliesMap[comment.parentId!]!.add(comment);
          } else {
            repliesMap[comment.parentId!] = [comment];
          }
        }
      } catch (e) {
        developer.log("Error parsing comment in _buildCommentSection: $e", name: 'CommentBottomSheet');
      }
    }
    // --- KẾT THÚC LOGIC MỚI ---

// --- BẮT ĐẦU SỬA ---
    // --- BẮT ĐẦU SỬA ---
    // 1. Đếm số lượng bình luận con (trả lời) thực sự được nhóm
    int replyCount = 0;
    repliesMap.values.forEach((replyList) {
      replyCount += replyList.length;
    });

    // 2. Tổng số bình luận HIỂN THỊ = (số bình luận cha + số bình luận con được nhóm)
    // Ví dụ: 4 = 4 (cha) + 0 (con) HOẶC 4 = 3 (cha) + 1 (con)
    final int totalVisibleComments = topLevelComments.length + replyCount;
    // --- KẾT THÚC SỬA ---
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Text('$totalVisibleComments bình luận', // <-- SỬA Ở ĐÂY (Sẽ hiển thị số 3)
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer()
            ],
          ),
        ),
        const Divider(color: darkSurface, height: 1),

        // Danh sách (ListView)
        Expanded(
          child: topLevelComments.isEmpty // Nếu không có bình luận cha nào
              ? const Center(
              child: Text("Chưa có bình luận nào.",
                  style: TextStyle(color: sonicSilver)))
          // Tạo danh sách chỉ dựa trên bình luận cha
              : ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: topLevelComments.length,
            itemBuilder: (context, index) {
              // 3. Lấy bình luận cha
              final parentComment = topLevelComments[index];

              // 4. Lấy tất cả bình luận con của nó từ Map
              final replies = repliesMap[parentComment.id] ?? [];

              // 5. Trả về một Column: Gồm Cha và các Con của nó
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 5a. Hiển thị bình luận cha
                  _buildCommentItem(parentComment),

                  // 5b. Hiển thị tất cả bình luận con (replies)
                  // Hàm _buildCommentItem của bạn đã có sẵn logic thụt lề
                  // (do chúng ta đã sửa ở bước trước),
                  // nên nó sẽ tự động thụt lề cho replies.
                  ...replies.map((reply) => _buildCommentItem(reply)),
                ],
              );
            },
          ),
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
                      .orderBy('timestamp', descending: false)
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
                    final docs = snapshot.data!.docs;
                    return _buildCommentSection(docs);
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

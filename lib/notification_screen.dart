// lib/notification_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import các màn hình/model cần thiết cho điều hướng
// Đảm bảo các lớp giả định này tồn tại (hoặc được định nghĩa ở đây/đã import)
class StoryViewScreen extends StatelessWidget { final String userName; final String avatarUrl; final List<String> storyIds; const StoryViewScreen({super.key, required this.userName, required this.avatarUrl, required this.storyIds}); @override Widget build(BuildContext context) => PlaceholderScreen(title: "Story View", content: "Xem story của $userName");}
class CommentBottomSheetContent extends StatelessWidget { final String postId; final String postUserName; final int currentCommentCount; final Function(int) onCommentPosted; final String postMediaUrl; final String postCaption; final bool isPostOwner; const CommentBottomSheetContent({super.key, required this.postId, required this.postUserName, required this.currentCommentCount, required this.onCommentPosted, required this.postMediaUrl, required this.postCaption, required this.isPostOwner}); @override Widget build(BuildContext context) => Container(color: Colors.grey, child: Text("Comment Sheet for $postId"));}
class PostDetailScreen extends StatelessWidget { final Map<String, dynamic> postData; const PostDetailScreen({super.key, required this.postData}); @override Widget build(BuildContext context) => PlaceholderScreen(title: "Post Detail", content: "Xem chi tiết bài viết ${postData['id']}");}
class ProfileScreen extends StatelessWidget { final String? targetUserId; final VoidCallback onNavigateToHome; final VoidCallback onLogout; const ProfileScreen({super.key, this.targetUserId, required this.onNavigateToHome, required this.onLogout}); @override Widget build(BuildContext context) => PlaceholderScreen(title: "Profile", content: "Xem profile của ${targetUserId ?? 'Bạn'}");}
class Comment { final String id; final String userId; final String userName; final String? userAvatarUrl; final String text; final Timestamp timestamp; final String? parentId; bool isLiked; int likesCount; final List<String> likedBy; Comment({required this.id, required this.userId, required this.userName, this.userAvatarUrl, required this.text, required this.timestamp, this.parentId, this.isLiked = false, required this.likesCount, required this.likedBy}); factory Comment.fromFirestore(DocumentSnapshot doc, String currentUserId) => Comment(id: doc.id, userId: '', userName: '', text: '', timestamp: Timestamp.now(), likesCount: 0, likedBy: []);}

// Constants
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C);
const Color activeGreen = Color(0xFF32CD32);

// Màn hình Placeholder đơn giản
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final String content;
  const PlaceholderScreen({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(content, style: const TextStyle(color: sonicSilver, fontSize: 16), textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

// =======================================================
// WIDGET: SocialNotificationTile (Giữ nguyên)
// =======================================================
class SocialNotificationTile extends StatelessWidget {
  final DocumentSnapshot notificationDoc;
  final Function(DocumentSnapshot doc) onUserTap;
  final Function(DocumentSnapshot doc, String action) onActionTap;
  final Function(DocumentSnapshot doc) onLongPress;
  final Function(DocumentSnapshot doc) onTileTap;

  const SocialNotificationTile({
    super.key,
    required this.notificationDoc,
    required this.onUserTap,
    required this.onActionTap,
    required this.onLongPress,
    required this.onTileTap,
  });

  ImageProvider? _getAvatarProvider(Map<String, dynamic> data) {
    final String? avatarUrl = data['senderAvatarUrl'] as String?;
    if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) {
      try {
        return NetworkImage(avatarUrl);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Widget _buildTrailingWidget(BuildContext context) {
    final data = notificationDoc.data() as Map<String, dynamic>? ?? {};
    final type = data['type'] as String? ?? '';
    final bool actionTaken = data['actionTaken'] as bool? ?? false;

    if (type == 'friend_request') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: actionTaken ? null : () => onActionTap(notificationDoc, 'accept'),
            style: ElevatedButton.styleFrom(
              backgroundColor: topazColor, foregroundColor: Colors.black,
              minimumSize: const Size(80, 30), padding: EdgeInsets.zero,
              disabledBackgroundColor: darkSurface,
            ),
            child: Text(actionTaken ? 'Đã chấp nhận' : 'Chấp nhận', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: actionTaken ? null : () => onActionTap(notificationDoc, 'reject'),
            style: OutlinedButton.styleFrom(
              foregroundColor: sonicSilver, side: const BorderSide(color: sonicSilver),
              minimumSize: const Size(80, 30), padding: EdgeInsets.zero,
            ),
            child: const Text('Từ chối', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      );
    } else if (type == 'follow') {
      if (actionTaken) {
        return OutlinedButton(
          onPressed: () => onActionTap(notificationDoc, 'unfollow_back'),
          style: OutlinedButton.styleFrom(
            foregroundColor: sonicSilver, side: const BorderSide(color: sonicSilver),
            minimumSize: const Size(100, 30), padding: EdgeInsets.zero,
          ),
          child: const Text('Đang theo dõi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        );
      } else {
        return ElevatedButton(
          onPressed: () => onActionTap(notificationDoc, 'follow_back'),
          style: ElevatedButton.styleFrom(
            backgroundColor: topazColor, foregroundColor: Colors.black,
            minimumSize: const Size(100, 30), padding: EdgeInsets.zero,
          ),
          child: const Text('Theo dõi lại', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        );
      }
    }
    return const Icon(Icons.arrow_forward_ios, color: sonicSilver, size: 16);
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'like': return Icons.favorite_rounded;
      case 'comment': return Icons.question_answer_rounded;
      case 'my_post_save': return Icons.bookmark_rounded;
      case 'suggest_page': return Icons.star_rounded;
      case 'tag_post': case 'tag_comment': case 'tag_story': return Icons.alternate_email_rounded;
      default: return Icons.notifications_none;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'like': return coralRed;
      case 'suggest_page': return topazColor;
      default: return sonicSilver;
    }
  }

  String _formatTimestampAgo(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final difference = DateTime.now().difference(dateTime);
    if (difference.inSeconds < 60) return '${difference.inSeconds} giây';
    if (difference.inMinutes < 60) return '${difference.inMinutes} phút';
    if (difference.inHours < 24) return '${difference.inHours} giờ';
    return '${difference.inDays} ngày';
  }


  @override
  Widget build(BuildContext context) {
    final data = notificationDoc.data() as Map<String, dynamic>? ?? {};
    final String type = data['type'] as String? ?? '';
    final String senderName = data['senderName'] as String? ?? 'Ai đó';
    final String contentPreview = data['contentPreview'] as String? ?? '...';
    final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
    final bool isRead = data['isRead'] as bool? ?? false;
    final bool showIconOnAvatar = type != 'friend_request' && type != 'follow';

    final ImageProvider? avatarProvider = _getAvatarProvider(data);

    void handleListTileTap() {
      if (type != 'friend_request' && type != 'follow') {
        onTileTap(notificationDoc);
      }
    }

    Widget userAvatar = GestureDetector(
      onTap: () => onUserTap(notificationDoc),
      child: CircleAvatar(
        radius: 24,
        backgroundColor: darkSurface,
        backgroundImage: avatarProvider,
        child: avatarProvider == null ? const Icon(Icons.person_outline, color: sonicSilver, size: 24) : null,
      ),
    );

    if (showIconOnAvatar) {
      userAvatar = Stack(
        clipBehavior: Clip.none,
        children: [
          userAvatar,
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.5)
              ),
              child: Icon(_getIconForType(type), color: _getColorForType(type), size: 14),
            ),
          )
        ],
      );
    }


    return GestureDetector(
      onLongPress: () => onLongPress(notificationDoc),
      child: Container(
        color: isRead ? Colors.transparent : darkSurface.withOpacity(0.3),
        child: ListTile(
          onTap: handleListTileTap,
          leading: userAvatar,
          title: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.white, fontSize: 15),
              children: <TextSpan>[
                TextSpan(text: senderName, style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: ' $contentPreview'),
              ],
            ),
          ),
          subtitle: Text(_formatTimestampAgo(timestamp), style: TextStyle(color: sonicSilver, fontSize: 12)),
          trailing: _buildTrailingWidget(context),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }

}

// =======================================================
// MÀN HÌNH CHÍNH: NotificationScreen (ĐÃ SỬA LỖI SCOPE)
// =======================================================
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  // Helper functions used inside the class
  String _formatTimestampAgo(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final difference = DateTime.now().difference(dateTime);
    if (difference.inSeconds < 60) return '${difference.inSeconds} giây';
    if (difference.inMinutes < 60) return '${difference.inMinutes} phút';
    if (difference.inHours < 24) return '${difference.inHours} giờ';
    return '${difference.inDays} ngày';
  }

  ImageProvider? _getAvatarProvider(Map<String, dynamic> data) {
    final String? avatarUrl = data['senderAvatarUrl'] as String?;
    if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) {
      try { return NetworkImage(avatarUrl); } catch (e) { return null; }
    }
    return null;
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'like': return Icons.favorite_rounded;
      case 'comment': return Icons.question_answer_rounded;
      case 'my_post_save': return Icons.bookmark_rounded;
      case 'suggest_page': return Icons.star_rounded;
      case 'tag_post': case 'tag_comment': case 'tag_story': return Icons.alternate_email_rounded;
      default: return Icons.notifications_none;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'like': return coralRed;
      case 'suggest_page': return topazColor;
      default: return sonicSilver;
    }
  }

  // Placeholder methods
  void _showCommentSheetForPost(BuildContext context, Map<String, dynamic> postData) { /* ... */ }
  void _showNotificationMenu(DocumentSnapshot notifDoc) { /* ... */ }
  void _deleteNotification(DocumentSnapshot notifDoc) async { /* ... */ }


  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    // _markNotificationsAsRead(); // Logic đánh dấu đã đọc khi mở màn hình
  }

  void _markNotificationsAsRead() async { /* ... */ }

  void _markSingleNotificationAsRead(DocumentSnapshot notifDoc) async {
    try {
      await notifDoc.reference.update({'isRead': true});
    } catch (e) {
      print("Lỗi đánh dấu đã đọc: $e");
    }
  }

  // LOGIC: Xử lý Chấp nhận hoặc Từ chối Yêu cầu Kết bạn (hoàn thiện)
  void _handleSocialAction(DocumentSnapshot notifDoc, String action) async {
    final recipientId = _currentUser?.uid;
    final data = notifDoc.data() as Map<String, dynamic>? ?? {};
    final senderId = data['senderId'] as String?;
    final senderName = data['senderName'] as String? ?? 'Người dùng';
    final type = data['type'] as String?;

    // Đảm bảo không xử lý lại yêu cầu đã xử lý
    if (recipientId == null || senderId == null || type != 'friend_request' || (data['actionTaken'] as bool? ?? false)) {
      return;
    }

    final batch = _firestore.batch();
    final recipientRef = _firestore.collection('users').doc(recipientId);
    final senderRef = _firestore.collection('users').doc(senderId);
    final notifRef = notifDoc.reference;

    // 1. Cập nhật trạng thái thông báo (đã hành động)
    batch.update(notifRef, {'actionTaken': true});

    String message;

    if (action == 'accept') {
      // 2. Thêm vào mảng friendUids của cả hai bên
      batch.update(recipientRef, {'friendUids': FieldValue.arrayUnion([senderId])});
      batch.update(senderRef, {'friendUids': FieldValue.arrayUnion([recipientId])});

      // 3. Xóa ID khỏi outgoingRequests của người gửi
      batch.update(senderRef, {'outgoingRequests': FieldValue.arrayRemove([recipientId])});

      // 4. Tạo thông báo cho người gửi (đã chấp nhận)
      final recipientName = _currentUser?.displayName ?? 'Người dùng';
      batch.set(
          _firestore.collection('users').doc(senderId).collection('notifications').doc(),
          {
            'type': 'friend_accept',
            'senderId': recipientId,
            'senderName': recipientName,
            'senderAvatarUrl': _currentUser?.photoURL,
            'destinationId': recipientId,
            'contentPreview': 'đã chấp nhận lời mời kết bạn của bạn.',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          }
      );
      message = 'Đã chấp nhận lời mời kết bạn từ $senderName.';

    } else if (action == 'reject') {
      // 2. Xóa ID khỏi outgoingRequests của người gửi
      batch.update(senderRef, {'outgoingRequests': FieldValue.arrayRemove([recipientId])});

      // 3. Xóa thông báo khỏi danh sách người nhận
      batch.delete(notifRef);
      message = 'Đã từ chối lời mời kết bạn từ $senderName.';

    } else {
      return;
    }

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: topazColor));
        if (action == 'accept') {
          _markSingleNotificationAsRead(notifDoc);
        }
      }
    } catch (e) {
      print("Lỗi xử lý yêu cầu kết bạn: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi: Xử lý yêu cầu không thành công.'), backgroundColor: coralRed));
    }
  }

  void _handleProfileTap(DocumentSnapshot notifDoc) { /* ... */ }

  void _handleTap(DocumentSnapshot notifDoc) async {
    final data = notifDoc.data() as Map<String, dynamic>? ?? {};
    final destinationId = data['destinationId'] as String?;
    final type = data['type'] as String?;
    final senderName = data['senderName'] as String? ?? 'Người dùng';

    final currentUserId = _currentUser?.uid;

    if (destinationId == null || type == null) { /* Show error */ return; }

    Widget? targetScreen;
    try {
      if (['like', 'comment', 'tag_post', /*...*/ 'tag_comment'].contains(type)) {
        final postDoc = await _firestore.collection('posts').doc(destinationId).get();
        if (postDoc.exists) {
          Map<String, dynamic> postData = postDoc.data()!;
          postData['id'] = postDoc.id;

          final List<String> likedByList = List<String>.from(postData['likedBy'] ?? []);
          final List<String> savedByList = List<String>.from(postData['savedBy'] ?? []);
          postData['isLiked'] = currentUserId != null && likedByList.contains(currentUserId);
          postData['isSaved'] = currentUserId != null && savedByList.contains(currentUserId);

          postData['userAvatarUrl'] = postData['userAvatarUrl'];
          postData['imageUrl'] = postData['imageUrl'];
          postData['locationTime'] = (postData['timestamp'] as Timestamp?) != null ? _formatTimestampAgo(postData['timestamp']!) : '';

          if (type == 'comment' || type == 'tag_comment') {
            _showCommentSheetForPost(context, postData);
            _markSingleNotificationAsRead(notifDoc);
            return;
          } else {
            targetScreen = PostDetailScreen(postData: postData);
          }
        } else {
          targetScreen = const PlaceholderScreen(title: 'Lỗi', content: 'Bài viết không còn tồn tại.');
        }
      } else if (['my_story_like', 'my_story_share', 'tag_story'].contains(type)) {
        String avatarUrl = (type == 'tag_story')
            ? (data['senderAvatarUrl'] ?? '')
            : (_currentUser?.photoURL ?? '');

        targetScreen = StoryViewScreen(
          userName: (type == 'tag_story') ? senderName : (_currentUser?.displayName ?? 'Bạn'),
          avatarUrl: avatarUrl,
          storyIds: [],
        );
      } else if (type == 'suggest_page') {
        targetScreen = PlaceholderScreen(title: 'Trang gợi ý', content: 'Xem chi tiết trang: $destinationId');
      } else {
        targetScreen = PlaceholderScreen(title: 'Chi tiết thông báo', content: 'Đích đến: $destinationId');
      }
      if (targetScreen != null && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => targetScreen!))
            .then((_) => _markSingleNotificationAsRead(notifDoc));
      }
    } catch (e) { print("Lỗi xử lý thông báo tap: $e"); /* Handle error */ }
  }


  @override
  Widget build(BuildContext context) {
    final currentUserId = _currentUser?.uid;

    if (currentUserId == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('Vui lòng đăng nhập để xem thông báo.', style: TextStyle(color: sonicSilver))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        // THỐNG NHẤT NÚT BACK
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
          splashRadius: 28,
        ),
        title: const Text('Thông báo', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20)),
        backgroundColor: Colors.black, elevation: 0.5, shadowColor: darkSurface,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('users').doc(currentUserId).collection('notifications')
            .orderBy('timestamp', descending: true).limit(50).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: topazColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi tải thông báo: ${snapshot.error}', style: const TextStyle(color: coralRed)));
          }

          final notificationDocs = snapshot.data?.docs;
          if (notificationDocs == null || notificationDocs.isEmpty) {
            return const Center(child: Text('Không có thông báo mới.', style: TextStyle(color: sonicSilver)));
          }

          return ListView.separated(
            itemCount: notificationDocs.length,
            itemBuilder: (context, index) {
              final notifDoc = notificationDocs[index];
              final data = notifDoc.data() as Map<String, dynamic>? ?? {};
              final type = data['type'] as String? ?? '';

              if (type == 'friend_request' || type == 'follow') {
                return SocialNotificationTile(
                  notificationDoc: notifDoc,
                  onUserTap: _handleProfileTap,
                  onActionTap: _handleSocialAction,
                  onLongPress: _showNotificationMenu,
                  onTileTap: _handleTap,
                );
              } else {
                final String senderName = data['senderName'] ?? 'Ai đó';
                final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
                final bool isRead = data['isRead'] ?? false;
                final ImageProvider? avatarProvider = _getAvatarProvider(data);

                return GestureDetector(
                  onLongPress: () => _showNotificationMenu(notifDoc),
                  child: Container(
                    color: isRead ? Colors.transparent : darkSurface.withOpacity(0.3),
                    child: ListTile(
                      onTap: () => _handleTap(notifDoc),
                      leading: CircleAvatar(
                        radius: 24, backgroundColor: darkSurface, backgroundImage: avatarProvider,
                        child: avatarProvider == null ? const Icon(Icons.person_outline, color: sonicSilver) : null,
                      ),
                      title: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          children: <TextSpan>[
                            TextSpan(text: senderName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: ' ${data['contentPreview'] ?? ''}'),
                          ],
                        ),
                      ),
                      subtitle: Text(_formatTimestampAgo(timestamp), style: TextStyle(color: sonicSilver, fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios, color: sonicSilver, size: 16),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

                    ),
                  ),
                );
              }
            },
            separatorBuilder: (context, index) => const Divider(color: darkSurface, height: 0.5, thickness: 0.5),
          );
        },
      ),
    );
  }
}
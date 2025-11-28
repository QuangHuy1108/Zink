// lib/notification_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart' hide PostDetailScreen, Comment;
import 'package:flutter/gestures.dart';
import 'reels_screen.dart';

import 'comment_screen.dart'; // <-- THÊM DÒNG NÀY
import 'models/comment_model.dart'; // <-- THÊM DÒNG NÀY
import 'reels_screen.dart'; // <-- THÊM DÒNG NÀY
import 'message_screen.dart';

// Import các màn hình/model cần thiết cho điều hướng
// Đảm bảo các lớp giả định này tồn tại (hoặc được định nghĩa ở đây/đã import)
// Đã xóa StoryViewScreen


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
      case 'tag_post': case 'tag_comment':case 'tag_story': return Icons.alternate_email_rounded;
      case 'reply_message': return Icons.reply_rounded;
      case 'pin_message': return Icons.push_pin_rounded;
      case 'group_invite': return Icons.group_add_rounded;
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

  // TÌM VÀ THAY THẾ TOÀN BỘ HÀM NÀY
  @override
  Widget build(BuildContext context) {
    final data = notificationDoc.data() as Map<String, dynamic>? ?? {};
    final String type = data['type'] as String? ?? '';
    final String senderName = data['senderName'] as String? ?? 'Ai đó';
    final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
    final bool isRead = data['isRead'] as bool? ?? false;
    final bool showIconOnAvatar = type != 'friend_request' && type != 'follow';

    final ImageProvider? avatarProvider = _getAvatarProvider(data);

    String actionText;
    switch (type) {
    // Các loại có tương tác trực tiếp
      case 'follow':
        actionText = 'đã bắt đầu theo dõi bạn.';
        break;
      case 'friend_request':
        actionText = 'đã gửi cho bạn lời mời kết bạn.';
        break;
    // --- PHẦN BỔ SUNG MỚI (Tin nhắn) ---
      case 'reply_message':
        actionText = data['contentPreview'] as String? ?? 'đã trả lời tin nhắn của bạn.';
        break;
      case 'pin_message':
        actionText = data['contentPreview'] as String? ?? 'đã ghim một tin nhắn.';
        break;
      case 'group_invite':
        actionText = data['contentPreview'] as String? ?? 'đã mời bạn tham gia một nhóm.';
        break;
    // --- KẾT THÚC PHẦN BỔ SUNG ---

    // --- PHẦN BỔ SUNG MỚI ---
    // Thêm các loại tương tác theo yêu cầu của bạn
      case 'like':
        actionText = 'đã tim bài viết của bạn.';
        break;
      case 'save': //
        actionText = 'đã lưu bài viết của bạn.';
        break;
      case 'share': //
        actionText = 'đã chia sẻ bài viết của bạn.';
        break;
    // --- KẾT THÚC PHẦN BỔ SUNG ---

    // Mặc định: Lấy từ contentPreview (cho comment, reply, tag, v.v.)
      default:
        actionText = data['contentPreview'] as String? ?? '...';
        break;
    }

    void handleListTileTap() {
      if (type != 'friend_request') {
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
                // SỬA Ở ĐÂY: Thêm TapGestureRecognizer
                TextSpan(
                  text: senderName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  recognizer: TapGestureRecognizer()..onTap = () => onUserTap(notificationDoc), // <-- ĐÂY LÀ PHẦN NÂNG CẤP
                ),
                TextSpan(text: ' $actionText'),
              ],
            ),
          ),
          subtitle: Text(_formatTimestampAgo(timestamp), style: TextStyle(color: sonicSilver, fontSize: 12)),
          trailing: _buildTrailingWidget(context),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }}

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

  // Placeholder methods
  void _showCommentSheetForPost(BuildContext context, Map<String, dynamic> postData) { /* ... */ }
  void _showNotificationMenu(DocumentSnapshot notifDoc) { /* ... */ }
  void _deleteNotification(DocumentSnapshot notifDoc) async { /* ... */ }


  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    // SỬA: Bỏ comment để kích hoạt chức năng
    _markNotificationsAsRead();
  }

  // SỬA: Thêm nội dung cho hàm này
  void _markNotificationsAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 1. Lấy tất cả các thông báo chưa đọc
    final querySnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    if (querySnapshot.docs.isEmpty) return; // Không có gì để cập nhật

    // 2. Sử dụng WriteBatch để cập nhật tất cả chúng trong một lần cho hiệu quả
    final batch = _firestore.batch();
    for (final doc in querySnapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    // 3. Thực thi batch
    try {
      await batch.commit();
      print("Đã đánh dấu ${querySnapshot.docs.length} thông báo là đã đọc.");
    } catch (e) {
      print("Lỗi khi đánh dấu hàng loạt là đã đọc: $e");
    }
  }

  void _markSingleNotificationAsRead(DocumentSnapshot notifDoc) async {
    try {
      await notifDoc.reference.update({'isRead': true});
    } catch (e) {
      print("Lỗi đánh dấu đã đọc: $e");
    }
  }

  // LOGIC: Xử lý Chấp nhận hoặc Từ chối Yêu cầu Kết bạn (hoàn thiện)
  // LOGIC: Xử lý Chấp nhận hoặc Từ chối Yêu cầu Kết bạn (ĐÃ SỬA)
  void _handleSocialAction(DocumentSnapshot notifDoc, String action) async {
    // SỬA: Lấy người dùng mới nhất
    final currentUser = _auth.currentUser;
    final recipientId = currentUser?.uid;

    final data = notifDoc.data() as Map<String, dynamic>? ?? {};
    final senderId = data['senderId'] as String?;
    final senderName = data['senderName'] as String? ?? 'Người dùng';
    final type = data['type'] as String?;

    if (recipientId == null || senderId == null || type != 'friend_request' || (data['actionTaken'] as bool? ?? false)) {
      return;
    }

    final batch = _firestore.batch();
    final recipientRef = _firestore.collection('users').doc(recipientId);
    final senderRef = _firestore.collection('users').doc(senderId);
    final notifRef = notifDoc.reference;

    batch.update(notifRef, {'actionTaken': true});

    String message;

    if (action == 'accept') {
      final recipientDoc = await recipientRef.get();
      final recipientData = recipientDoc.data() as Map<String, dynamic>?;
      final recipientName = recipientData?['displayName'] ?? 'Người dùng';
      final recipientAvatarUrl = recipientData?['photoURL'];

      batch.update(recipientRef, {'friendUids': FieldValue.arrayUnion([senderId])});
      batch.update(senderRef, {'friendUids': FieldValue.arrayUnion([recipientId])});
      batch.update(senderRef, {'outgoingRequests': FieldValue.arrayRemove([recipientId])});

      batch.set(
          _firestore.collection('users').doc(senderId).collection('notifications').doc(),
          {
            'type': 'friend_accept',
            'senderId': recipientId,
            'senderName': recipientName,
            'senderAvatarUrl': recipientAvatarUrl,
            'destinationId': recipientId,
            'contentPreview': 'đã chấp nhận lời mời kết bạn của bạn.',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          }
      );
      message = 'Đã chấp nhận lời mời kết bạn từ $senderName.';

    } else if (action == 'reject') {
      batch.update(senderRef, {'outgoingRequests': FieldValue.arrayRemove([recipientId])});
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
  // TÌM VÀ THAY THẾ HÀM NÀY
  void _handleProfileTap(DocumentSnapshot notifDoc) {
    final data = notifDoc.data() as Map<String, dynamic>? ?? {};
    final senderId = data['senderId'] as String?;
    if (senderId != null && mounted) {
      // Điều hướng đến ProfileScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(
            targetUserId: senderId,
            onNavigateToHome: () {},
            onLogout: () {},
          ),
        ),
      );
    }
  }

// THAY THẾ TOÀN BỘ HÀM NÀY
// THAY THẾ TOÀN BỘ HÀM NÀY
  void _handleTap(DocumentSnapshot notifDoc) async {
    final data = notifDoc.data() as Map<String, dynamic>? ?? {};
    final destinationId = data['destinationId'] as String?; // Đây là postId (hoặc reelId)
    final type = data['type'] as String?;

    _markSingleNotificationAsRead(notifDoc);

    Widget? targetScreen; // Dùng để điều hướng

    try {
      // --- TRƯỜNG HỢP 1: ĐI ĐẾN BÀI VIẾT (POST) ---
      if (['like', 'share', 'save', 'tag_post'].contains(type)) {
        if (destinationId == null) {
          targetScreen = const PlaceholderScreen(title: 'Lỗi', content: 'Không tìm thấy ID của bài viết.');
        } else {
          final postDoc = await _firestore.collection('posts').doc(destinationId).get();
          if (postDoc.exists) {
            Map<String, dynamic> postData = postDoc.data()!;
            postData['id'] = postDoc.id;
            targetScreen = PostDetailScreen(postData: postData); // Đi đến PostDetailScreen
          } else {
            targetScreen = const PlaceholderScreen(title: 'Lỗi', content: 'Bài viết này không còn tồn tại.');
          }
        }
      }

      // --- TRƯỜNG HỢP 2: MỞ TRANG BÌNH LUẬN ---
      else if (type == 'tag_comment' || type == 'reply' || type == 'comment') {
        if (destinationId == null) {
          targetScreen = const PlaceholderScreen(title: 'Lỗi', content: 'Không tìm thấy ID của bài viết.');
        } else {
          // 1. Vẫn phải lấy thông tin Post để hiển thị
          final postDoc = await _firestore.collection('posts').doc(destinationId).get();
          if (postDoc.exists) {
            final postData = postDoc.data() as Map<String, dynamic>;
            final bool isPostOwner = (postData['uid'] as String?) == _currentUser?.uid;

            // 2. Mở trực tiếp Comment Sheet (thật)
            if (mounted) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (BuildContext sheetContext) {
                  return FractionallySizedBox(
                    heightFactor: 0.95,
                    // Giờ nó sẽ gọi CommentBottomSheetContent thật
                    child: CommentBottomSheetContent(
                      postId: destinationId,
                      postUserName: postData['displayName'] ?? 'Người dùng',
                      currentCommentCount: (postData['commentsCount'] is num ? (postData['commentsCount'] as num).toInt() : 0),
                      postMediaUrl: postData['imageUrl'],
                      postCaption: postData['postCaption'] ?? '',
                      isPostOwner: isPostOwner,
                      onCommentPosted: (newCount) { },
                    ),
                  );
                },
              );
            }
            return;
          } else {
            targetScreen = const PlaceholderScreen(title: 'Lỗi', content: 'Bài viết này không còn tồn tại.');
          }
        }
      }

      // --- TRƯỜNG HỢP 3 (REEL) ---
      else if (type == 'tag_reel') {
        targetScreen = ReelsScreen(onNavigateToHome: () {
          if (Navigator.canPop(context)) Navigator.pop(context);
        });
      }

      // --- TRƯỜNG HỢP 4 (PROFILE) ---
      else if (['follow', 'friend_accept'].contains(type)) {
        final senderId = data['senderId'] as String?;
        if (senderId != null) {
          targetScreen = ProfileScreen(
            targetUserId: senderId,
            onNavigateToHome: () {},
            onLogout: () {},
          );
        } else {
          targetScreen = const PlaceholderScreen(title: 'Lỗi', content: 'Không tìm thấy người dùng này.');
        }
      }

      // --- TRƯỜNG HỢP CHAT/MESSAGE MỚI ---
      else if (['reply_message', 'pin_message', 'group_invite'].contains(type)) {
        if (destinationId == null) {
          targetScreen = const PlaceholderScreen(title: 'Lỗi', content: 'Không tìm thấy ID cuộc trò chuyện.');
        } else {
          // Điều hướng đến MessageScreen, sử dụng destinationId (là chatId)
          targetScreen = MessageScreen(
            targetUserId: destinationId,
            targetUserName: data['senderName'] ?? 'Chat', // Tên người gửi/người mời
          );
        }
      }

      // --- TRƯỜNG HỢP KHÁC ---
      else {
        print("Chưa xử lý điều hướng cho loại thông báo: $type");
        return;
      }

      // Điều hướng nếu có màn hình đích (cho trường hợp 1, 3, 4)
      if (targetScreen != null && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => targetScreen!));
      }
    } catch (e) {
      print("Lỗi xử lý thông báo tap: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã có lỗi xảy ra khi mở thông báo.'), backgroundColor: coralRed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    final currentUserId = currentUser?.uid;

    if (currentUserId == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('Vui lòng đăng nhập để xem thông báo.', style: TextStyle(color: sonicSilver))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
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
            // Đây là nội dung mới cho itemBuilder
            itemBuilder: (context, index) {
              final notifDoc = notificationDocs[index];

              // LUÔN LUÔN DÙNG SocialNotificationTile
              return SocialNotificationTile(
                key: ValueKey(notifDoc.id), // Thêm Key để Flutter nhận diện
                notificationDoc: notifDoc,
                onUserTap: _handleProfileTap,
                onActionTap: _handleSocialAction, // Đảm bảo tên hàm đúng
                onLongPress: _showNotificationMenu, // Đảm bảo tên hàm đúng
                onTileTap: _handleTap,
              );
            },
            separatorBuilder: (context, index) => const Divider(color: darkSurface, height: 0.5, thickness: 0.5),
          );
        },
      ),
    );
  }
}

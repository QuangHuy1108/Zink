// lib/feed_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import các màn hình và widget khác
import 'profile_screen.dart' hide PostCard, Comment, PlaceholderScreen, FeedScreen, FollowersScreen, MessageScreen;
import 'comment_screen.dart' hide Comment;
import 'share_sheet.dart';
import 'search_screen.dart';
import 'notification_screen.dart' hide Comment, StoryViewScreen, CommentBottomSheetContent, ProfileScreen;
import 'post_detail_screen.dart';
import 'message_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Định nghĩa Comment ---
class Comment {
  final String id;
  final String userId;
  final String userName;
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
    required this.userName,
    this.userAvatarUrl,
    required this.text,
    required this.timestamp,
    this.parentId,
    this.isLiked = false,
    required this.likesCount,
    required this.likedBy,
  });

  factory Comment.fromFirestore(DocumentSnapshot doc, String currentUserId) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    List<String> likedByList = List<String>.from(data['likedBy'] ?? []);
    return Comment(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['displayName'] ?? 'Người dùng Zink',
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
// --- Kết thúc định nghĩa Comment ---

// =======================================================
// CONSTANTS
// =======================================================
const Color topazColor = Color(0xFFF6C886);
const Color earthYellow = Color(0xFFE0A263);
const Color coralRed = Color(0xFFFD402C);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color activeGreen = Color(0xFF32CD32);

class EditPostScreen extends StatefulWidget {
  final Map<String, dynamic> postData;
  final Function(Map<String, dynamic> newData) onPostUpdated;

  const EditPostScreen({
    super.key,
    required this.postData,
    required this.onPostUpdated,
  });

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late TextEditingController _captionController;
  late TextEditingController _tagsController;
  late String _selectedPrivacy;
  bool _isLoading = false;

  final List<String> _privacyOptions = ['Công khai', 'Bạn bè', 'Chỉ mình tôi'];

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.postData['postCaption'] ?? '');

    // Xử lý chuyển đổi List<String> tags thành chuỗi cho TextField
    final List<String> initialTags = List<String>.from(widget.postData['tags'] ?? []);
    _tagsController = TextEditingController(text: initialTags.join(', '));

    _selectedPrivacy = widget.postData['privacy'] ?? 'Công khai';
  }

  @override
  void dispose() {
    _captionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _saveChanges() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final String newCaption = _captionController.text.trim();

    // Xử lý chuyển đổi chuỗi tag thành List<String>
    final List<String> newTags = _tagsController.text.trim()
        .toLowerCase()
        .split(RegExp(r'[,\s]+'))
        .where((tag) => tag.isNotEmpty)
        .toList();

    final Map<String, dynamic> updatedData = {
      'postCaption': newCaption,
      'tags': newTags,          // Gửi Tags mới
      'privacy': _selectedPrivacy, // Gửi Privacy mới
    };

    widget.onPostUpdated(updatedData); // Gọi callback để update lên Firestore

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Chỉnh sửa Bài viết', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        actions: [
          _isLoading
              ? const Padding(padding: EdgeInsets.only(right: 16), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: topazColor))))
              : TextButton(
            onPressed: _saveChanges,
            child: const Text('Lưu', style: TextStyle(color: topazColor, fontSize: 16)),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Chỉnh sửa Caption
            TextField(
              controller: _captionController,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Chỉnh sửa chú thích...',
                hintStyle: TextStyle(color: sonicSilver.withOpacity(0.7)),
                filled: true,
                fillColor: darkSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            // 2. Chỉnh sửa Tags
            TextField(
              controller: _tagsController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Chỉnh sửa tags (cách nhau bằng dấu phẩy)',
                hintStyle: TextStyle(color: sonicSilver.withOpacity(0.7)),
                filled: true,
                fillColor: darkSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            // 3. Hiển thị Ảnh (Nếu có)
            if (widget.postData['imageUrl'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Image.network(
                  widget.postData['imageUrl'] as String,
                  fit: BoxFit.cover,
                  height: 200,
                  width: double.infinity,
                ),
              ),

            // 4. Chỉnh sửa Quyền riêng tư
            const Text('Quyền riêng tư:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            ..._privacyOptions.map((privacy) => RadioListTile<String>(
              title: Text(privacy, style: const TextStyle(color: Colors.white)),
              value: privacy,
              groupValue: _selectedPrivacy,
              onChanged: (newValue) {
                if (newValue != null) {
                  setState(() { _selectedPrivacy = newValue; });
                }
              },
              activeColor: topazColor,
              contentPadding: EdgeInsets.zero,
            )).toList(),
          ],
        ),
      ),
    );
  }
}
// =======================================================
// WIDGET CHUÔNG THÔNG BÁO
// =======================================================
class AnimatedNotificationBell extends StatefulWidget {
  final VoidCallback onOpenNotification;
  const AnimatedNotificationBell({required this.onOpenNotification, super.key});

  @override
  State<AnimatedNotificationBell> createState() => _AnimatedNotificationBellState();
}

class _AnimatedNotificationBellState extends State<AnimatedNotificationBell> {
  bool _hasNotification = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot>? _notificationStream;

  @override
  void initState() {
    super.initState();
    _listenForNotifications();
  }

  void _listenForNotifications() {
    final user = _auth.currentUser;
    if (user != null) {
      _notificationStream = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .limit(1)
          .snapshots();

      _notificationStream?.listen((snapshot) {
        final hasUnread = snapshot.docs.isNotEmpty;
        if (mounted && hasUnread != _hasNotification) {
          setState(() {
            _hasNotification = hasUnread;
          });
        }
      }, onError: (error) {
        print("Error listening for notifications: $error");
        if (mounted) {
          setState(() { _hasNotification = false; });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(
            Icons.notifications_none, // Luôn dùng icon tĩnh
            color: sonicSilver,
            size: 24,
          ),
          onPressed: widget.onOpenNotification,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          splashRadius: 20,
        ),
        if (_hasNotification)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: topazColor, // Màu vàng
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
// =======================================================
// FeedScreen
// =======================================================
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  Stream<DocumentSnapshot>? _myUserDataStream;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  final double _headerContentHeight = 45.0;

  List<DocumentSnapshot> _suggestedFriends = [];

  final ScrollController _scrollController = ScrollController(); // DÒNG NÀY

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null)
    {
      _myUserDataStream = _firestore.collection('users').doc(_currentUser!.uid).snapshots();
    }
    _fetchSuggestedFriends();
  }

  @override
  void dispose() { // KHỐI NÀY
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    // Tải lại cả gợi ý và bài viết
    await _fetchSuggestedFriends();
  }

  void _scrollToTopAndRefresh() { // KHỐI NÀY
    if (_scrollController.hasClients) {
      // 1. Cuộn lên đầu
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      // 2. Kích hoạt tải lại dữ liệu
      _handleRefresh();
    } else {
      // Nếu controller chưa sẵn sàng, chỉ tải lại
      _handleRefresh();
    }
  }

  Future<void> _fetchSuggestedFriends() async {
    if (_currentUser == null) return;

    try {
      // 1. Lấy dữ liệu người dùng hiện tại để biết loại trừ ai.
      final currentUserDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (!currentUserDoc.exists) return;
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>;

      final myFriends = List<String>.from(currentUserData['friendUids'] ?? []);
      final myOutgoingRequests = List<String>.from(currentUserData['outgoingRequests'] ?? []);
      final myFollowing = List<String>.from(currentUserData['following'] ?? []);

      // 2. Tạo một danh sách các ID cần loại trừ.
      final excludeUids = {
        _currentUser!.uid, // Loại trừ chính mình
        ...myFriends,           // Loại trừ bạn bè
      };

      // 3. Lấy người dùng về để lọc. Tăng giới hạn để có nhiều lựa chọn hơn.
      final usersSnapshot = await _firestore.collection('users').limit(30).get();

      // 4. Lọc ở phía client.
      final suggestions = usersSnapshot.docs.where((doc) {
        final docId = doc.id;

        // 1. Lọc cơ bản: Bỏ qua nếu là bạn hoặc là chính mình
        if (excludeUids.contains(docId)) {
          return false;
        }

        // 2. Lọc theo yêu cầu mới: Bỏ qua CHỈ KHI đã gửi lời mời VÀ đang theo dõi
        final bool hasSentRequest = myOutgoingRequests.contains(docId);
        final bool isFollowing = myFollowing.contains(docId);

        if (hasSentRequest && isFollowing) {
          return false; // Đã làm cả hai -> Lọc bỏ
        }

        // 3. Giữ lại trong các trường hợp khác (chưa làm gì, chỉ follow, hoặc chỉ kết bạn)
        return true;
      }).toList();

      // Xáo trộn và lấy 5 người đầu.
      suggestions.shuffle();

      if (mounted) {
        setState(() {
          _suggestedFriends = suggestions.take(5).toList();
        });
      }
    } catch (e) {
      print("Lỗi khi lấy danh sách gợi ý kết bạn: $e");
    }
  }

  Widget _buildPostFeedSliver() {
    Query query = _firestore.collection('posts').orderBy('timestamp', descending: true);
    const int suggestionInsertionIndex = 3;

    return StreamBuilder<QuerySnapshot>(
      stream: query.limit(20).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _suggestedFriends.isEmpty) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: topazColor)),
            hasScrollBody: false,
          );
        }
        if (snapshot.hasError) {
          return SliverFillRemaining(
            child: Center(child: Text('Lỗi tải bài viết: ${snapshot.error}', style: const TextStyle(color: coralRed))),
            hasScrollBody: false,
          );
        }

        final posts = snapshot.data?.docs ?? [];
        if (posts.isEmpty && _suggestedFriends.isEmpty) {
          return const SliverFillRemaining(
            child: Center(
                child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Chưa có bài viết nào.', style: TextStyle(color: sonicSilver)))),
            hasScrollBody: false,
          );
        }

        List<dynamic> combinedList = List.from(posts);

        if (_suggestedFriends.isNotEmpty && posts.length >= suggestionInsertionIndex) {
          combinedList.insert(suggestionInsertionIndex, _suggestedFriends);
        } else if (_suggestedFriends.isNotEmpty) {
          combinedList.add(_suggestedFriends);
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final item = combinedList[index];

              if (item is List<DocumentSnapshot>) {
                return SuggestedFriendsSection(
                  suggestedFriends: item,
                  myUserDataStream: _myUserDataStream,
                  onActionTaken: _fetchSuggestedFriends, // <-- TRUYỀN CALLBACK
                );
              }

              final doc = item as DocumentSnapshot;
              Map<String, dynamic> postData = doc.data() as Map<String, dynamic>? ?? {};
              postData['id'] = doc.id;
              postData['locationTime'] = (postData['timestamp'] as Timestamp?) != null ? _formatTimestampAgo(postData['timestamp'] as Timestamp) : 'Vừa xong';

              EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0);

              if (index == 0) {
                padding = const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0, top: 0);
              }

              return Padding(
                padding: padding,
                child: PostCard(
                  key: ValueKey(postData['id']),
                  postData: postData,
                ),
              );
            },
            childCount: combinedList.length,
          ),
        );
      },
    );
  }

  String _formatTimestampAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp.toDate());

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Vừa xong';
    }
  }

  Widget _buildHeaderContent() {
    return Container(
      height: _headerContentHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector( // BẮT ĐẦU DÒNG NÀY
            onTap: _scrollToTopAndRefresh, // GỌI HÀM CUỘN VÀ TẢI LẠI
            child: const Text(
              'Zink',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.bold,
                fontSize: 40,
                color: Colors.white,
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.search, color: sonicSilver, size: 24),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen()));
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 20,
              ),
              const SizedBox(width: 16),
              AnimatedNotificationBell(
                onOpenNotification: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationScreen()));
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.message_outlined, color: sonicSilver, size: 24),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MessageScreen()));
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)  {
    final double topPadding = MediaQuery.of(context).padding.top;
    final double appBarTotalHeight = topPadding + _headerContentHeight;

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: topazColor,
        backgroundColor: darkSurface,
        displacement: appBarTotalHeight,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: <Widget>[
            SliverAppBar(
              backgroundColor: Colors.black,
              floating: true,
              pinned: false,
              elevation: 0,
              automaticallyImplyLeading: false,
              expandedHeight: appBarTotalHeight,
              toolbarHeight: appBarTotalHeight,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: EdgeInsets.zero,
                centerTitle: true,
                background: Container(
                  color: Colors.black,
                  padding: EdgeInsets.only(top: topPadding),
                  child: _buildHeaderContent(),
                ),
              ),
            ),
            _buildPostFeedSliver(),
            const SliverToBoxAdapter(
              child: SizedBox(height: 50),
            ),
          ],
        ),
      ),
    );
  }
}

class SuggestedFriendsSection extends StatelessWidget {
  final List<DocumentSnapshot> suggestedFriends;
  final Stream<DocumentSnapshot>? myUserDataStream;
  final VoidCallback? onActionTaken; // <-- THÊM CALLBACK

  const SuggestedFriendsSection({
    Key? key,
    required this.suggestedFriends,
    required this.myUserDataStream,
    this.onActionTaken, // <-- THÊM VÀO CONSTRUCTOR
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Gợi ý cho bạn',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260, // <<< TĂNG CHIỀU CAO TẠI ĐÂY (Từ 220 lên 260)
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: suggestedFriends.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final userDoc = suggestedFriends[index];
                final userData = userDoc.data() as Map<String, dynamic>;
                userData['uid'] = userDoc.id; // Đảm bảo uid luôn có
                return SuggestedFriendCard(
                  key: ValueKey(userDoc.id),
                  userData: userData,
                  myUserDataStream: myUserDataStream,
                  onActionTaken: onActionTaken,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SuggestedFriendCard extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Stream<DocumentSnapshot>? myUserDataStream;
  final VoidCallback? onActionTaken; // <-- THÊM CALLBACK

  const SuggestedFriendCard({
    Key? key,
    required this.userData,
    required this.myUserDataStream,
    this.onActionTaken, // <-- THÊM VÀO CONSTRUCTOR
  }) : super(key: key);

  @override
  State<SuggestedFriendCard> createState() => _SuggestedFriendCardState();
}

class _SuggestedFriendCardState extends State<SuggestedFriendCard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  void _navigateToProfile(BuildContext context) {
    final targetUserId = widget.userData['uid'] as String?;
    if (targetUserId == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => ProfileScreen(
        targetUserId: targetUserId,
        onNavigateToHome: () {},
        onLogout: () {},
      ),
    ));
  }

  Future<void> _handleAction(Function action) async {
    if (_isLoading) return;
    if (mounted) setState(() => _isLoading = true);
    try {
      await action();
    } catch (e) {
      print("Lỗi khi thực hiện hành động: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
      // Gọi callback để FeedScreen có thể làm mới danh sách gợi ý
    }
  }

  void _toggleFriendRequest(bool isCurrentlyPending) {
    final currentUser = _auth.currentUser;
    final targetUserId = widget.userData['uid'] as String?;
    if (currentUser == null || targetUserId == null) return;

    _handleAction(() async {
      final userRef = _firestore.collection('users').doc(currentUser.uid);
      final targetNotificationRef = _firestore.collection('users').doc(targetUserId).collection('notifications');

      if (isCurrentlyPending) {
        await userRef.update({'outgoingRequests': FieldValue.arrayRemove([targetUserId])});
        final notifQuery = await targetNotificationRef.where('type', isEqualTo: 'friend_request').where('senderId', isEqualTo: currentUser.uid).limit(1).get();
        for (var doc in notifQuery.docs) {
          await doc.reference.delete();
        }
      } else {
        DocumentSnapshot myUserDoc = await userRef.get();
        String senderName = 'Một người dùng';
        if (myUserDoc.exists) senderName = (myUserDoc.data() as Map<String, dynamic>)['displayName'] ?? senderName;
        await userRef.update({'outgoingRequests': FieldValue.arrayUnion([targetUserId])});
        await targetNotificationRef.add({'type': 'friend_request', 'senderId': currentUser.uid, 'senderName': senderName, 'timestamp': FieldValue.serverTimestamp(), 'isRead': false, 'actionTaken': false});
      }
      widget.onActionTaken?.call();
    });
  }

  void _toggleFollow(bool isCurrentlyFollowing) {
    final currentUser = _auth.currentUser;
    final targetUserId = widget.userData['uid'] as String?;
    if (currentUser == null || targetUserId == null) return;

    _handleAction(() async {
      final myDocRef = _firestore.collection('users').doc(currentUser.uid);
      final theirDocRef = _firestore.collection('users').doc(targetUserId);
      final batch = _firestore.batch();

      if (isCurrentlyFollowing) {
        batch.update(myDocRef, {'following': FieldValue.arrayRemove([targetUserId])});
        batch.update(theirDocRef, {'followers': FieldValue.arrayRemove([currentUser.uid])});
      } else {
        DocumentSnapshot myUserDoc = await myDocRef.get();
        String senderName = 'Một người dùng';
        if (myUserDoc.exists) senderName = (myUserDoc.data() as Map<String, dynamic>)['displayName'] ?? senderName;
        batch.update(myDocRef, {'following': FieldValue.arrayUnion([targetUserId])});
        batch.update(theirDocRef, {'followers': FieldValue.arrayUnion([currentUser.uid])});
        batch.set(theirDocRef.collection('notifications').doc(), {'type': 'follow', 'senderId': currentUser.uid, 'senderName': senderName, 'timestamp': FieldValue.serverTimestamp(), 'isRead': false});
      }
      await batch.commit();
      widget.onActionTaken?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final String targetUserId = widget.userData['uid'] as String? ?? '';
    final String displayName = widget.userData['displayName'] as String? ?? 'Người dùng';
    final String? avatarUrl = widget.userData['photoURL'] as String?;
    final int mutualCount = widget.userData['mutual'] as int? ?? 0;
    final String friendMutualText = mutualCount > 0 ? '$mutualCount bạn chung' : 'Chưa có bạn chung';

    final ImageProvider? avatarProvider = (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null;

    return Container(
      width: 150,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _navigateToProfile(context),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: sonicSilver,
                    backgroundImage: avatarProvider,
                    child: avatarProvider == null ? const Icon(Icons.person, size: 30, color: Colors.white) : null,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    displayName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    friendMutualText,
                    style: const TextStyle(color: sonicSilver, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          StreamBuilder<DocumentSnapshot>(
              stream: widget.myUserDataStream,
              builder: (context, myDataSnapshot) {
                bool isFriend = false;
                bool isPending = false;
                bool isFollowing = false;

                if (myDataSnapshot.hasData && myDataSnapshot.data!.exists) {
                  final myData = myDataSnapshot.data!.data() as Map<String, dynamic>;
                  isFriend = (myData['friendUids'] as List<dynamic>? ?? []).contains(targetUserId);
                  isPending = (myData['outgoingRequests'] as List<dynamic>? ?? []).contains(targetUserId);
                  isFollowing = (myData['following'] as List<dynamic>? ?? []).contains(targetUserId);
                }

                final friendButtonText = isFriend ? 'Bạn bè' : (isPending ? 'Hủy lời mời' : 'Kết bạn');
                final friendButtonColor = isFriend || isPending ? darkSurface : topazColor;
                final friendTextColor = isFriend || isPending ? sonicSilver : Colors.black;
                final friendButtonSide = isFriend || isPending ? BorderSide(color: sonicSilver) : BorderSide.none;

                final followButtonText = isFollowing ? 'Hủy theo dõi' : 'Theo dõi';
                final followButtonColor = isFollowing ? darkSurface : Colors.blueAccent;
                final followTextColor = isFollowing ? sonicSilver : Colors.white;
                final followButtonSide = isFollowing ? BorderSide(color: sonicSilver) : BorderSide.none;

                return Column(
                  children: [
                    SizedBox(
                      height: 32,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isFriend || _isLoading ? null : () => _toggleFriendRequest(isPending),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: friendButtonColor,
                          foregroundColor: friendTextColor,
                          side: friendButtonSide,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: EdgeInsets.zero,
                          disabledBackgroundColor: darkSurface, // Màu khi bị vô hiệu hóa
                        ),
                        child: _isLoading && !isFriend
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(friendButtonText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (!isFriend) // Ẩn nút theo dõi nếu đã là bạn bè
                      SizedBox(
                        height: 32,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => _toggleFollow(isFollowing),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: followButtonColor,
                            foregroundColor: followTextColor,
                            side: followButtonSide,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: EdgeInsets.zero,
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(followButtonText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                  ],
                );
              }),
        ],
      ),
    );
  }
}

// =======================================================
// PostCard Widget
// =======================================================
class PostCard extends StatefulWidget {
  final Map<String, dynamic> postData;
  const PostCard({super.key, required this.postData});
  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  late String _postId;
  late bool _isLiked;
  late bool _isSaved;
  late int _likesCount;
  late int _commentsCount;
  late int _sharesCount;

  // --- TRẠNG THÁI MỚI VÀ KEY ---
  bool _isCurrentlyHidden = false;
  String? _hiddenReason;
  late String _localStorageKey;
  // -----------------------------

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _postId = widget.postData['id'] as String? ?? '';
    // Tạo key duy nhất dựa trên PostId và UserID để tránh xung đột giữa các user
    _localStorageKey = 'hidden_post_${_currentUser?.uid ?? 'guest'}_$_postId';
    _updateStateFromWidget();
    _loadHiddenState();
  }

  // --- HÀM MỚI: TẢI TRẠNG THÁI ẨN TỪ LOCAL STORAGE ---
  void _loadHiddenState() async {
    final prefs = await SharedPreferences.getInstance();
    final isHidden = prefs.getBool(_localStorageKey) ?? false;
    final reason = prefs.getString('${_localStorageKey}_reason');

    if (mounted) {
      setState(() {
        _isCurrentlyHidden = isHidden;
        _hiddenReason = reason;
      });
    }
  }

  // --- HÀM MỚI: LƯU TRẠNG THÁI ẨN VÀO LOCAL STORAGE ---
  void _saveHiddenState(bool isHidden, String? reason) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_localStorageKey, isHidden);
    if (reason != null && isHidden) {
      await prefs.setString('${_localStorageKey}_reason', reason);
    } else {
      await prefs.remove('${_localStorageKey}_reason');
    }
  }


  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.postData != oldWidget.postData) {
      _updateStateFromWidget();
    }
  }

  void _updateStateFromWidget() {
    _postId = widget.postData['id'];
    _likesCount = widget.postData['likesCount'] ?? 0;
    _commentsCount = widget.postData['commentsCount'] ?? 0;
    _sharesCount = widget.postData['sharesCount'] ?? 0;

    final List<dynamic> likes = widget.postData['likedBy'] ?? [];
    _isLiked = _currentUser != null ? likes.contains(_currentUser!.uid) : false;

    final List<dynamic> saves = widget.postData['savedBy'] ?? [];
    _isSaved = _currentUser != null ? saves.contains(_currentUser!.uid) : false;
  }

  // SỬA: Bổ sung logic tạo thông báo Like và dùng WriteBatch
  void _updateFirestoreLike() async {
    if (_currentUser == null || _postId.isEmpty) return;
    final userId = _currentUser!.uid;
    final postRef = _firestore.collection('posts').doc(_postId);
    final postOwnerId = widget.postData['uid'] as String?;

    final WriteBatch batch = _firestore.batch();

    final bool willLike = _isLiked;
    final updateData = willLike
        ? {'likedBy': FieldValue.arrayUnion([userId]), 'likesCount': FieldValue.increment(1)}
        : {'likedBy': FieldValue.arrayRemove([userId]), 'likesCount': FieldValue.increment(-1)};

    batch.update(postRef, updateData);

    // Tạo Thông báo (Chỉ khi Thích và không phải bài của mình)
    if (willLike && postOwnerId != null && postOwnerId != userId) {
      try {
        final currentUserDoc = await _firestore.collection('users').doc(userId).get();
        final currentUserData = currentUserDoc.data() as Map<String, dynamic>?;
        final senderName = currentUserData?['displayName'] ?? 'Một người dùng';
        final senderAvatarUrl = currentUserData?['photoURL'];

        final notificationRef = _firestore.collection('users').doc(postOwnerId).collection('notifications').doc();
        batch.set(notificationRef, {
          'type': 'like',
          'senderId': userId,
          'senderName': senderName,
          'senderAvatarUrl': senderAvatarUrl,
          'destinationId': _postId,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      } catch (e) {
        print("Lỗi khi lấy thông tin người gửi cho thông báo like: $e");
      }
    }

    try {
      await batch.commit();
    } catch (e) {
      print("Error updating like/notification: $e");
    }
  }


  void _toggleLike() {
    if (_currentUser == null) return;
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    _updateFirestoreLike();
  }

  void _toggleSave() async {
    if (_currentUser == null || _postId.isEmpty) return;

    final wasSaved = _isSaved;
    setState(() {
      _isSaved = !_isSaved;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_isSaved ? 'Đã lưu bài viết!' : 'Đã bỏ lưu bài viết.'),
      backgroundColor: _isSaved ? topazColor : sonicSilver,
      duration: const Duration(seconds: 1),
    ));

    final postRef = _firestore.collection('posts').doc(_postId);
    final userId = _currentUser!.uid;
    final postOwnerId = widget.postData['uid'] as String?;

    try {
      if (_isSaved) {
        final WriteBatch batch = _firestore.batch();
        batch.update(postRef, {'savedBy': FieldValue.arrayUnion([userId])});

        if (postOwnerId != null && postOwnerId != userId) {
          final currentUserDoc = await _firestore.collection('users').doc(userId).get();
          if (currentUserDoc.exists) {
            final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
            final senderName = currentUserData['displayName'] ?? 'Một người dùng';
            final senderAvatarUrl = currentUserData['photoURL'];

            final notificationRef = _firestore.collection('users').doc(postOwnerId).collection('notifications').doc();
            batch.set(notificationRef, {
              'type': 'save',
              'senderId': userId,
              'senderName': senderName,
              'senderAvatarUrl': senderAvatarUrl,
              'destinationId': _postId,
              'timestamp': FieldValue.serverTimestamp(),
              'isRead': false,
            });
          }
        }
        await batch.commit();

      } else {
        await postRef.update({'savedBy': FieldValue.arrayRemove([userId])});
      }
    } catch (e) {
      print("Lỗi khi lưu/bỏ lưu bài viết: $e");
      if (mounted) {
        setState(() { _isSaved = wasSaved; });
      }
    }
  }

  void _showCommentSheet(BuildContext context) {
    if (_postId.isEmpty) return;
    final String postMediaUrl = widget.postData['imageUrl'] ?? '';
    final bool isPostOwner = widget.postData['uid'] == _currentUser?.uid;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.95,
          child: CommentBottomSheetContent(
            postId: _postId,
            postUserName: widget.postData['displayName'] ?? 'Người dùng',
            currentCommentCount: _commentsCount,
            postMediaUrl: postMediaUrl,
            postCaption: widget.postData['postCaption'] ?? '',
            isPostOwner: isPostOwner,
            onCommentPosted: (newCount) {
              if (mounted) {
                setState(() { _commentsCount = newCount; });
              }
            },
          ),
        );
      },
    );
  }

  void _showShareSheet(BuildContext context) {
    if (_postId.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return ShareSheetContent(
          postId: _postId,
          postUserName: widget.postData['displayName'] ?? 'Người dùng',
          initialShares: _sharesCount,
          onSharesUpdated: (newCount) {
            if (mounted) setState(() { _sharesCount = newCount; });
          },
        );
      },
    );
  }

  // Chức năng Xóa bài viết (Đã có logic trong file)
  void _deletePost() async {
    if (widget.postData['uid'] != _currentUser?.uid || _postId.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: darkSurface,
          title: const Text('Xác nhận Xóa', style: TextStyle(color: Colors.white)),
          content: const Text('Bạn có chắc chắn muốn xóa bài viết này không?', style: TextStyle(color: Colors.white70)),
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
      try {
        await _firestore.collection('posts').doc(_postId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa bài viết.')));
          // Sau khi xóa thành công, ta mô phỏng ẩn vĩnh viễn (do nó không còn tồn tại)
          setState(() {
            _isCurrentlyHidden = true; // Chỉ để làm mất widget này khỏi màn hình
          });
          _saveHiddenState(true, 'Đã xóa');
        }
      } catch (e) { /* Handle error */ }
    }
  }

  // Chức năng 2. Chỉnh sửa bài viết (Mô phỏng)
  void _editPost() {
    if (widget.postData['uid'] != _currentUser?.uid || _postId.isEmpty) return;

    // Điều hướng đến màn hình chỉnh sửa
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => EditPostScreen(
        postData: widget.postData,
        onPostUpdated: (newData) async {
          // Cập nhật lên Firestore và cập nhật State cục bộ
          try {
            // Bắt đầu cập nhật lên Firestore
            await _firestore.collection('posts').doc(_postId).update({
              'postCaption': newData['postCaption'],
              'tags': newData['tags'],       // <-- CẬP NHẬT TAGS
              'privacy': newData['privacy'], // <-- CẬP NHẬT PRIVACY
              'timestamp': FieldValue.serverTimestamp(),
            });

            if (mounted) {
              // Cập nhật lại UI của PostCard ngay lập tức
              setState(() {
                widget.postData['postCaption'] = newData['postCaption'];
                widget.postData['tags'] = newData['tags'];      // Cập nhật state tags
                widget.postData['privacy'] = newData['privacy']; // Cập nhật state privacy
                _updateStateFromWidget();
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bài viết đã được cập nhật.'), backgroundColor: activeGreen));
            }
          } catch (e) {
            print("Lỗi cập nhật bài viết: $e");
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi: Cập nhật bài viết không thành công.'), backgroundColor: coralRed));
          }
        },
      ),
    ));
  }

  // Chức năng 3. Báo cáo bài viết (Hoàn thiện logic mới)
  void _reportPost() {
    _showReportDialog();
  }

  // Chức năng 4. Ẩn bài viết này (Hoàn thiện logic mới)
  void _hidePost() {
    if (mounted) {
      setState(() {
        _isCurrentlyHidden = true;
        _hiddenReason = 'Ẩn bài viết';
      });
      _saveHiddenState(true, 'Ẩn bài viết');

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Đã ẩn bài viết này.'),
        backgroundColor: sonicSilver,
        duration: Duration(seconds: 2),
      ));
    }
  }

  // Chức năng 5. Bỏ theo dõi người này
  void _unfollowUser() async {
    if (_currentUser == null) return;
    final targetUserId = widget.postData['uid'] as String?;
    final targetUserName = widget.postData['displayName'] as String? ?? 'Người dùng';

    if (targetUserId == null || targetUserId == _currentUser!.uid) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: darkSurface,
          title: const Text('Xác nhận Bỏ theo dõi', style: TextStyle(color: Colors.white)),
          content: Text('Bạn có chắc chắn muốn bỏ theo dõi $targetUserName không?', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              child: const Text('Hủy', style: TextStyle(color: sonicSilver)),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('Bỏ theo dõi', style: TextStyle(color: coralRed)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final batch = _firestore.batch();
      final myUserRef = _firestore.collection('users').doc(_currentUser!.uid);
      final theirUserRef = _firestore.collection('users').doc(targetUserId);

      try {
        // 1. Cập nhật danh sách "following" của tôi
        batch.update(myUserRef, {'following': FieldValue.arrayRemove([targetUserId])});
        // 2. Cập nhật danh sách "followers" của họ
        batch.update(theirUserRef, {'followers': FieldValue.arrayRemove([_currentUser!.uid])});

        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã bỏ theo dõi $targetUserName.'), backgroundColor: sonicSilver));
          // Ẩn bài viết và lưu trạng thái
          setState(() {
            _isCurrentlyHidden = true;
            _hiddenReason = 'Bỏ theo dõi';
          });
          _saveHiddenState(true, 'Bỏ theo dõi');
        }
      } catch (e) {
        print("Lỗi khi bỏ theo dõi: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi: Không thể bỏ theo dõi.'), backgroundColor: coralRed));
        }
      }
    }
  }

  void _navigateToProfile(String targetUsernameOrUid) {
    final targetUid = widget.postData['uid'];
    final fallbackId = (targetUsernameOrUid == (_currentUser?.displayName ?? 'You')) ? _currentUser?.uid : targetUsernameOrUid;
    final profileId = targetUid ?? fallbackId;

    if (profileId == null || profileId.isEmpty) {
      print("Error: Cannot navigate to profile, missing ID.");
      return;
    }

    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => ProfileScreen(
        targetUserId: profileId == _currentUser?.uid ? null : profileId,
        onNavigateToHome: () {
          print("Navigate to home triggered from profile opened via post card");
        },
        onLogout: () {
          print("Logout triggered from profile opened via post card - likely no-op");
        },
      ),
    ));
  }

  // --- LOGIC BÁO CÁO MỚI ---

  Future<void> _showCustomReasonDialog() async {
    final TextEditingController controller = TextEditingController();
    final bool? shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: darkSurface,
          title: const Text('Lý do khác', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Nhập lý do báo cáo...',
              hintStyle: TextStyle(color: sonicSilver),
              filled: true,
              fillColor: Colors.black,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              child: const Text('Hủy', style: TextStyle(color: sonicSilver)),
              onPressed: () => Navigator.pop(context, false),
            ),
            TextButton(
              child: const Text('Gửi', style: TextStyle(color: coralRed)),
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập lý do.'), backgroundColor: coralRed),
                  );
                }
              },
            ),
          ],
        );
      },
    );

    if (shouldSubmit == true && controller.text.trim().isNotEmpty) {
      _submitReportAndHide('Khác', controller.text.trim());
    }
  }

  Future<void> _showReportDialog() async {
    final List<String> reasons = [
      'Nội dung nhạy cảm',
      'Nội dung người lớn',
      'Nội dung mang tính bạo lực',
      'Tôi không muốn xem nội dung này',
      'Khác',
    ];

    String? selectedReason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: darkSurface,
      builder: (BuildContext context) {
        return Container(
          // BỎ DÒNG padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
// ... (Title)
              ),
              const Divider(color: Colors.white10, height: 1),
              // Thay thế List với ListView.builder để xử lý cuộn tốt hơn nếu có nhiều lý do.
              ...reasons.map((reason) {
                return ListTile(
                  title: Text(reason, style: const TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(context, reason),
                );
              }).toList(),
              // THÊM: Padding dưới cùng để xử lý vùng an toàn của notch/thanh điều hướng
              SizedBox(height: MediaQuery.of(context).padding.bottom),
              // BỎ DÒNG const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
    if (selectedReason == null) return;

    if (selectedReason == 'Khác') {
      _showCustomReasonDialog();
    } else if (selectedReason.isNotEmpty) {
      _submitReportAndHide(selectedReason, null);
    }
  }

  void _submitReportAndHide(String reason, String? customReason) async {
    // Mô phỏng việc gửi báo cáo đến Firestore/Backend
    // Bạn có thể thêm logic lưu report vào collection 'reports' tại đây

    // Ẩn bài viết và lưu trạng thái
    if (mounted) {
      setState(() {
        _isCurrentlyHidden = true;
        _hiddenReason = 'Đã báo cáo ($reason)';
      });
      _saveHiddenState(true, 'Đã báo cáo ($reason)');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cảm ơn bạn đã báo cáo. Bài viết này đã được ẩn.'),
        backgroundColor: coralRed,
        duration: Duration(seconds: 3),
      ));
    }
  }

  // --- LOGIC ẨN/HOÀN TÁC MỚI ---

  void _undoHide() {
    if (mounted) {
      setState(() {
        _isCurrentlyHidden = false;
        _hiddenReason = null;
      });
      _saveHiddenState(false, null);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Đã hoàn tác. Bài viết được khôi phục.'),
        backgroundColor: sonicSilver,
      ));
    }
  }

  Widget _buildPostContent() {
    final String? avatarUrl = widget.postData['userAvatarUrl'] as String?;
    final String? imageUrl = widget.postData['imageUrl'] as String?;
    final String userName = widget.postData['displayName'] as String? ?? 'Người dùng';
    final String locationTime = widget.postData['locationTime'] as String? ?? '';
    final String caption = widget.postData['postCaption'] as String? ?? '';

    // --- LOGIC BÀI VIẾT CHIA SẺ ---
    final String? sharedPostId = widget.postData['sharedPostId'] as String?;
    final String? shareThoughts = widget.postData['shareThoughts'] as String?;
    final bool isSharedPost = sharedPostId != null && sharedPostId.isNotEmpty;
    final String shareMessage = isSharedPost ? caption : '';
    final String displayCaption = isSharedPost ? (shareThoughts ?? '') : caption;
    // --- KẾT THÚC LOGIC BÀI VIẾT CHIA SẺ ---

    final ImageProvider? postImageProvider = (imageUrl != null && imageUrl.isNotEmpty && imageUrl.startsWith('http'))
        ? NetworkImage(imageUrl) : null;
    final ImageProvider? avatarImageProvider = (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
        ? NetworkImage(avatarUrl) : null;
    final List<String> postTags = List<String>.from(widget.postData['tags'] ?? []);

    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.only(bottom: 0),
      color: Colors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 0.0, bottom: 12.0, right: 0.0, top: 10.0),
            child: Row(
              children: [
                GestureDetector(
                    onTap: () => _navigateToProfile(userName),
                    child: CircleAvatar(
                      radius: 18, backgroundColor: darkSurface,
                      backgroundImage: avatarImageProvider,
                      child: avatarImageProvider == null ? const Icon(Icons.person, size: 18, color: sonicSilver) : null,
                    )
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _navigateToProfile(userName),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isSharedPost && shareMessage.isNotEmpty)
                          Builder(
                            builder: (context) {
                              final String sharingName = userName;
                              final RegExp regex = RegExp(r"đã chia sẻ bài viết của (.*)\.");
                              final match = regex.firstMatch(shareMessage);
                              String originalOwnerName = '';
                              String middleText = shareMessage;

                              if (match != null) {
                                originalOwnerName = match.group(1)!.trim();
                                final startIndexOfMiddle = shareMessage.indexOf(sharingName) + sharingName.length;
                                final endIndexOfMiddle = shareMessage.indexOf(originalOwnerName);
                                if (endIndexOfMiddle > startIndexOfMiddle) {
                                  middleText = shareMessage.substring(startIndexOfMiddle, endIndexOfMiddle).trim();
                                } else {
                                  middleText = shareMessage.substring(sharingName.length).replaceAll(originalOwnerName, '').replaceAll('.', '').trim();
                                }
                              } else {
                                middleText = shareMessage.substring(sharingName.length).trim();
                              }

                              return RichText(
                                text: TextSpan(
                                  style: TextStyle(color: sonicSilver.withOpacity(0.9), fontSize: 13),
                                  children: <TextSpan>[
                                    TextSpan(text: sharingName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                                    TextSpan(text: ' $middleText ', style: TextStyle(fontWeight: FontWeight.w500, color: sonicSilver.withOpacity(0.9), fontSize: 14)),
                                    TextSpan(text: originalOwnerName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                                    const TextSpan(text: '.', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white, fontSize: 14)),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          )
                        else
                          Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),

                        if (locationTime.isNotEmpty)
                          Row(
                            children: [
                              Text(locationTime, style: TextStyle(color: sonicSilver.withOpacity(0.8), fontSize: 12)),
                              const SizedBox(width: 8), // Khoảng cách giữa thời gian và quyền riêng tư
                              _buildPrivacyIcon(widget.postData['privacy'] ?? 'Công khai'), // <-- GỌI HÀM MỚI
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                _buildMoreOptionsButton(context),
              ],
            ),
          ),

          if (displayCaption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 0.0, bottom: 8.0, right: 0.0),
              child: Text(displayCaption, style: const TextStyle(color: Colors.white, fontSize: 15)),
            ),
          if (postTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 0.0, bottom: 8.0, right: 0.0),
              child: Wrap(
                spacing: 6.0,
                runSpacing: 4.0,
                children: postTags.map((tag) => Text(
                  '#$tag',
                  style: const TextStyle(color: topazColor, fontSize: 14, fontWeight: FontWeight.bold),
                )).toList(),
              ),
            ),

          GestureDetector(
            onDoubleTap: _toggleLike,
            onTap: () { /* Navigate to PostDetailScreen */ },
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: const BoxDecoration(borderRadius: BorderRadius.zero, color: darkSurface),
                child: postImageProvider != null
                    ? Image(
                  image: postImageProvider, fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: sonicSilver, size: 40)),
                )
                    : const Center(child: Icon(Icons.image_not_supported, color: sonicSilver, size: 50)),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(top: 10.0, left: 0.0, right: 0.0, bottom: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildInteractionButton(icon: _isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? coralRed : sonicSilver, count: _likesCount, onTap: _toggleLike),
                    const SizedBox(width: 20),
                    _buildInteractionButton(icon: Icons.chat_bubble_outline_rounded, color: sonicSilver, count: _commentsCount, onTap: () => _showCommentSheet(context)),
                    const SizedBox(width: 20),
                    _buildInteractionButton(icon: Icons.send_rounded, color: sonicSilver, count: _sharesCount, onTap: () => _showShareSheet(context)),
                    const Spacer(),
                    IconButton(
                      icon: Icon(_isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: _isSaved ? topazColor : sonicSilver, size: 28),
                      onPressed: _toggleSave,
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(), splashRadius: 24,
                    ),
                  ],
                ),
                if (_likesCount > 0) ... [
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Text(
                      '$_likesCount lượt thích',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  )
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreOptionsButton(BuildContext context) {
    final bool isMyPost = widget.postData['uid'] == _currentUser?.uid;
    final String targetUserId = widget.postData['uid'] as String? ?? '';
    final bool isPostOwner = targetUserId == _currentUser?.uid;
    final bool canUnfollow = !isPostOwner && targetUserId.isNotEmpty;

    List<PopupMenuItem<String>> items = [
      const PopupMenuItem<String>(value: 'report', child: Text('Báo cáo bài viết')),
      const PopupMenuItem<String>(value: 'hide', child: Text('Ẩn bài viết này')),
    ];

    if (canUnfollow) {
      items.add(const PopupMenuItem<String>(value: 'unfollow', child: Text('Bỏ theo dõi người này')));
    }

    if (isMyPost) {
      items.insert(0, const PopupMenuItem<String>(value: 'delete', child: Text('Xóa bài viết', style: TextStyle(color: coralRed))));
      items.insert(1, const PopupMenuItem<String>(value: 'edit', child: Text('Chỉnh sửa bài viết')));
    }

    return PopupMenuButton<String>(
      itemBuilder: (BuildContext context) => items,
      onSelected: (String value) {
        switch (value) {
          case 'delete':
            _deletePost();
            break;
          case 'edit':
            _editPost();
            break;
          case 'report':
            _reportPost();
            break;
          case 'hide':
            _hidePost();
            break;
          case 'unfollow':
            _unfollowUser();
            break;
        }
      },
      // Đã đổi thành Icons.more_vert
      icon: const Icon(Icons.more_vert, color: sonicSilver),
      color: darkSurface,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }


  Widget _buildInteractionButton({
    required IconData icon,
    required Color color,
    required int count,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 4),
          if (count > 0)
            Text(
              count.toString(),
              style: const TextStyle(color: sonicSilver, fontSize: 13, fontWeight: FontWeight.w500),
            ),
        ],
      ),
    );
  }

  Widget _buildPrivacyIcon(String privacy) {
    IconData icon;
    String text;

    switch (privacy) {
      case 'Công khai':
        icon = Icons.public;
        text = 'Công khai';
        break;
      case 'Bạn bè':
        icon = Icons.people_alt_outlined;
        text = 'Bạn bè';
        break;
      case 'Chỉ mình tôi':
        icon = Icons.lock;
        text = 'Riêng tư';
        break;
      default:
        icon = Icons.public;
        text = 'Công khai';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: sonicSilver.withOpacity(0.8), size: 12),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: sonicSilver.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {

    // Nếu bị ẩn, chúng ta vẫn render nội dung gốc và đè lớp phủ lên bằng Stack
    if (_isCurrentlyHidden) {
      return Container(
        // Giữ nguyên margin/padding của PostCard gốc (Container)
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.only(bottom: 0),
        color: Colors.black, // Đảm bảo nền đen
        child: Stack(
          children: [
            // 1. Lớp nền: Bài viết gốc
            _buildPostContent(),

            // 2. Lớp phủ mờ + Chữ "Hoàn tác" (giữ nguyên kích thước List Item)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.85),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Bài viết đã bị ẩn. ${_hiddenReason != null ? '($_hiddenReason)' : ''}',
                        style: const TextStyle(color: sonicSilver, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _undoHide,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkSurface,
                          foregroundColor: topazColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: topazColor)
                          ),
                        ),
                        child: const Text('Hoàn tác', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Trạng thái hiển thị: Trả về PostCard gốc
    return _buildPostContent();
  }
}
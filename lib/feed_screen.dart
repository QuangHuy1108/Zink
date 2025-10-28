// lib/feed_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import các màn hình và widget khác
import 'profile_screen.dart' hide MessageScreen;
import 'comment_screen.dart';
import 'share_sheet.dart';
import 'search_screen.dart';
import 'notification_screen.dart' hide Comment, StoryViewScreen, CommentBottomSheetContent, ProfileScreen;
import 'create_story_screen.dart' hide StoryState;
import 'story_view_screen.dart' hide StoryContent;
import 'story_manager_screen.dart' hide StoryContent;
import 'suggested_friend_card.dart' hide ProfileScreen;
import 'post_detail_screen.dart';
import 'message_screen.dart';

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
      userName: data['userName'] ?? 'Người dùng Zink',
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

// --- Story State ---
class StoryContent {
  final String text;
  final Offset textPosition;
  final String song;
  final Offset songPosition;
  final String location;
  final List<String> taggedFriends;

  StoryContent({
    required this.text,
    required this.textPosition,
    required this.song,
    required this.songPosition,
    required this.location,
    required this.taggedFriends,
  });
}
class StoryState {
  DateTime? lastPostTime;
  List<String> likedBy = [];
  StoryContent? activeStoryContent;

  bool get hasActiveStory {
    if (lastPostTime == null) return false;
    return DateTime.now().difference(lastPostTime!) < const Duration(hours: 24);
  }
}
final StoryState globalUserStoryState = StoryState();
// --- Kết thúc Story State ---


// =======================================================
// WIDGET CHUÔNG THÔNG BÁO
// =======================================================
class AnimatedNotificationBell extends StatefulWidget {
  final VoidCallback onOpenNotification;
  const AnimatedNotificationBell({required this.onOpenNotification, super.key});

  @override
  State<AnimatedNotificationBell> createState() => _AnimatedNotificationBellState();
}

class _AnimatedNotificationBellState extends State<AnimatedNotificationBell> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _hasNotification = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot>? _notificationStream;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _animation = Tween(begin: 0.0, end: 5.0).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

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
          if (_hasNotification) {
            _controller.repeat(reverse: true);
          } else {
            _controller.stop();
            _controller.reset();
          }
        }
      }, onError: (error) {
        print("Error listening for notifications: $error");
        if (mounted) {
          setState(() { _hasNotification = false; });
          _controller.stop();
          _controller.reset();
        }
      });
    } else {
      if (mounted) {
        setState(() { _hasNotification = false; });
        _controller.stop();
        _controller.reset();
      }
    }
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final offsetValue = _hasNotification ? _animation.value * (_controller.value < 0.5 ? 1 : -1) : 0.0;
        return Transform.translate(
          offset: Offset(offsetValue, 0),
          child: child,
        );
      },
      child: IconButton(
        icon: Icon(
            _hasNotification ? Icons.notifications_active : Icons.notifications_none,
            color: _hasNotification ? topazColor : sonicSilver,
            size: 24 // Giảm kích thước icon
        ),
        onPressed: () {
          widget.onOpenNotification();
        },
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        splashRadius: 20, // Giảm splash radius
      ),
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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  Stream<QuerySnapshot>? _storiesStream;
  Map<String, bool> _viewedStories = {};

  final double _headerContentHeight = 45.0; // Giữ nguyên chiều cao nhỏ

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _loadActiveStories();
  }

  void _loadActiveStories() {
    _storiesStream = _firestore
        .collection('stories')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt')
        .limit(20)
        .snapshots();
  }


  void _forceRebuild() { if (mounted) setState(() {}); }

  void _navigateToStoryScreen(Widget screen, VoidCallback onClosed) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final backgroundScale = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOut));
          final foregroundOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeIn));
          return ScaleTransition(
            scale: backgroundScale,
            child: FadeTransition(opacity: foregroundOpacity, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        opaque: false,
      ),
    ).then((_) => onClosed());
  }

  String _formatActivityTime(DateTime? lastActive, bool isOnline) { return ''; }

  Future<void> _handleRefresh() async {
    setState(() {
      _viewedStories.clear();
    });
    _loadActiveStories();
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 500));
    print("Refresh Feed...");
  }

  Widget _buildSmallStoryAvatar(BuildContext context, DocumentSnapshot storyDoc) {
    final storyData = storyDoc.data() as Map<String, dynamic>? ?? {};
    final String storyUserId = storyData['userId'] ?? '';
    final String storyUserName = storyData['userName'] ?? 'Người dùng';
    final String? storyUserAvatarUrl = storyData['userAvatarUrl'] as String?;
    final String storyId = storyDoc.id;

    final bool isCurrentUserStory = storyUserId == _currentUser?.uid;
    final bool storyViewed = _viewedStories[storyId] ?? false;

    final ImageProvider? avatarProvider = (storyUserAvatarUrl != null && storyUserAvatarUrl.isNotEmpty)
        ? NetworkImage(storyUserAvatarUrl)
        : null;

    final BoxDecoration avatarBorder = (!storyViewed)
        ? BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [topazColor.withOpacity(0.8), earthYellow.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
    )
        : BoxDecoration( /* ... grey border ... */ );

    return GestureDetector(
      onTap: () {
        if (!isCurrentUserStory) {
          setState(() { _viewedStories[storyId] = true; });
        }
        _navigateToStoryScreen(
            StoryViewScreen(
                userName: storyUserName,
                avatarUrl: storyUserAvatarUrl,
                storyDocs: [storyDoc]
            ),
            _forceRebuild
        );
      },
      child: Container(
        width: 70,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: avatarBorder,
              child: CircleAvatar(
                radius: 30,
                backgroundColor: darkSurface,
                backgroundImage: avatarProvider,
                child: avatarProvider == null ? const Icon(Icons.person, color: sonicSilver, size: 30) : null,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              isCurrentUserStory ? 'Tin của bạn' : storyUserName.split(' ').first,
              style: TextStyle(
                color: (!storyViewed) ? Colors.white : sonicSilver,
                fontSize: 12,
                fontWeight: (!storyViewed) ? FontWeight.w500 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyStoryCreatorAvatar(BuildContext context) {
    final String? currentUserAvatar = _currentUser?.photoURL;
    final ImageProvider? avatarProvider = (currentUserAvatar != null && currentUserAvatar.isNotEmpty)
        ? NetworkImage(currentUserAvatar)
        : null;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CreateStoryScreen()))
            .then((_) => _forceRebuild());
      },
      child: Container(
        width: 70,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: darkSurface,
                  backgroundImage: avatarProvider,
                  child: avatarProvider == null ? const Icon(Icons.person, color: sonicSilver, size: 30) : null,
                ),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: const Icon(Icons.add, size: 12, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const Text(
              'Tin của bạn',
              style: TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }


  bool isOnlineOrRecent(DateTime? lastActive) { return false; }
  void _navigateToProfile(String targetUsernameOrUid) { /* ... */ }

  // Widget header nội dung (không bao gồm padding status bar)
  Widget _buildHeaderContent() {
    return Container(
      color: Colors.black,
      height: _headerContentHeight - 10, // Chiều cao nội dung (45 - 10 = 35)
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // =======================================================
          // THAY ĐỔI: Tăng kích thước chữ "Zink"
          // =======================================================
          const Text(
            'Zink',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: topazColor), // Tăng fontSize lên 32
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, color: sonicSilver, size: 24),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SearchScreen()));
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 20,
          ),
          const SizedBox(width: 8),
          AnimatedNotificationBell(
            onOpenNotification: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const NotificationScreen()));
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.message_outlined, color: sonicSilver, size: 24),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const MessageScreen()),
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }


  Widget _buildSuggestedFriendsSection(BuildContext context) {
    final List<Map<String, dynamic>> suggestedFriends = [];
    if (suggestedFriends.isEmpty) { return const SizedBox.shrink(); }
    return Column( /*...*/ );
  }

  // Widget hiển thị danh sách bài viết (TRẢ VỀ SLIVERLIST)
  Widget _buildPostFeedSliver() {
    final currentUserId = _currentUser?.uid ?? '';
    Query query = _firestore.collection('posts').orderBy('timestamp', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.limit(20).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: topazColor)),
            hasScrollBody: false,
          );
        }
        if (snapshot.hasError) {
          print("Lỗi tải bài viết: ${snapshot.error}");
          return SliverFillRemaining(
            child: Center(child: Text('Lỗi tải bài viết: ${snapshot.error}', style: const TextStyle(color: coralRed))),
            hasScrollBody: false,
          );
        }

        final posts = snapshot.data?.docs ?? [];
        if (posts.isEmpty) {
          return SliverFillRemaining(
            child: const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Chưa có bài viết nào.', style: TextStyle(color: sonicSilver)))),
            hasScrollBody: false,
          );
        }

        // =======================================================
        // THAY ĐỔI: Sử dụng SliverList thay vì SliverList.separated
        // =======================================================
        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final doc = posts[index];
              Map<String, dynamic> postData = doc.data() as Map<String, dynamic>? ?? {};
              postData['id'] = doc.id;

              postData['userAvatarUrl'] = postData['userAvatarUrl'];
              postData['imageUrl'] = postData['imageUrl'];

              postData['locationTime'] = (postData['timestamp'] as Timestamp?) != null ? _formatTimestampAgo(postData['timestamp']) : 'Vừa xong';

              // Thêm khoảng cách dưới cho mỗi PostCard (ngoại trừ cái cuối cùng)
              return Padding(
                padding: EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  // Thêm padding bottom nếu không phải item cuối
                  bottom: index < posts.length - 1 ? 8.0 : 0, // Ví dụ khoảng cách 8.0
                ),
                child: PostCard(
                  key: ValueKey(postData['id']),
                  postData: postData,
                ),
              );
            },
            childCount: posts.length,
          ),
        );
      },
    );
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
    final double topPadding = MediaQuery.of(context).padding.top;
    final double appBarTotalHeight = topPadding + _headerContentHeight;
    final double collapsedAppBarHeight = (kToolbarHeight + topPadding < appBarTotalHeight) ? kToolbarHeight + topPadding : appBarTotalHeight;


    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: topazColor,
        backgroundColor: darkSurface,
        displacement: appBarTotalHeight,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: <Widget>[
            SliverAppBar(
              backgroundColor: Colors.black,
              floating: true,
              pinned: false,
              elevation: 0,
              automaticallyImplyLeading: false,
              expandedHeight: appBarTotalHeight,
              collapsedHeight: collapsedAppBarHeight,
              toolbarHeight: collapsedAppBarHeight,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: Colors.black,
                  padding: EdgeInsets.only(
                      top: topPadding + 5,
                      bottom: 5
                  ),
                  child: _buildHeaderContent(),
                ),
                titlePadding: EdgeInsets.zero,
                centerTitle: false,
                title: const SizedBox.shrink(),
              ),
              titleSpacing: 0,
            ),

            // Story Avatars Row
            SliverToBoxAdapter(
              child: SizedBox(
                height: 100,
                child: StreamBuilder<QuerySnapshot>(
                  stream: _storiesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !_storiesStreamHasData(snapshot)) {
                      return const SizedBox.shrink();
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Icon(Icons.error_outline, color: sonicSilver));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        children: [_buildMyStoryCreatorAvatar(context)],
                      );
                    }
                    final currentUserId = _currentUser?.uid;
                    return ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      children: [
                        _buildMyStoryCreatorAvatar(context),
                        ...snapshot.data!.docs
                            .where((doc) => (doc.data() as Map<String, dynamic>?)?['userId'] != currentUserId)
                            .map((doc) => _buildSmallStoryAvatar(context, doc))
                            .toList(),
                      ],
                    );
                  },
                ),
              ),
            ),

            // Suggested Friends
            SliverToBoxAdapter(
              child: _buildSuggestedFriendsSection(context),
            ),

            // Post Feed
            _buildPostFeedSliver(),

            // Padding cuối cùng
            const SliverToBoxAdapter(
              child: SizedBox(height: 50),
            ),
          ],
        ),
      ),
    );
  }

  bool _storiesStreamHasData(AsyncSnapshot<QuerySnapshot> snapshot) {
    return snapshot.connectionState != ConnectionState.waiting || (snapshot.hasData || snapshot.hasError);
  }

} // End _FeedScreenState


// =======================================================
// PostCard Widget
// =======================================================
class PostCard extends StatefulWidget {
  final Map<String, dynamic> postData;
  const PostCard({super.key, required this.postData}); // <- Sửa lại constructor
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

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _updateStateFromWidget();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nếu dữ liệu được truyền vào thay đổi, hãy cập nhật lại state của PostCard
    if (widget.postData != oldWidget.postData) {
      // print("PostCard [${widget.postData['id']}] didUpdateWidget!"); // Dùng để debug
      _updateStateFromWidget();
    }
  }

  void _updateStateFromWidget() {
    _postId = widget.postData['id'];
    _likesCount = widget.postData['likesCount'] ?? 0;
    _commentsCount = widget.postData['commentsCount'] ?? 0;
    _sharesCount = widget.postData['sharesCount'] ?? 0;

    // SỬA Ở ĐÂY: Đọc từ 'likedBy' thay vì 'likes'
    final List<dynamic> likes = widget.postData['likedBy'] ?? [];
    _isLiked = _currentUser != null ? likes.contains(_currentUser!.uid) : false;

    // SỬA Ở ĐÂY: Đọc từ 'savedBy' thay vì 'saves'
    final List<dynamic> saves = widget.postData['savedBy'] ?? [];
    _isSaved = _currentUser != null ? saves.contains(_currentUser!.uid) : false;
  }
  void _updateFirestoreLike() {
    if (_currentUser == null || _postId.isEmpty) return;
    final userId = _currentUser!.uid;
    final postRef = _firestore.collection('posts').doc(_postId);
    final updateData = _isLiked
        ? {'likedBy': FieldValue.arrayUnion([userId]), 'likesCount': FieldValue.increment(1)}
        : {'likedBy': FieldValue.arrayRemove([userId]), 'likesCount': FieldValue.increment(-1)};
    postRef.update(updateData).catchError((e) => print("Error updating like: $e"));
  }

  void _updateFirestoreSave() {
    if (_currentUser == null || _postId.isEmpty) return;
    final userId = _currentUser!.uid;
    final postRef = _firestore.collection('posts').doc(_postId);
    final updateData = _isSaved
        ? {'savedBy': FieldValue.arrayUnion([userId])} // <-- Sửa lại: Nếu isSaved là true -> Union
        : {'savedBy': FieldValue.arrayRemove([userId])}; // <-- Ngược lại -> Remove
    postRef.update(updateData).catchError((e) => print("Error updating save: $e"));
  }

  void _toggleLike() {
    if (_currentUser == null) return;
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    _updateFirestoreLike();
  }

  void _toggleSave() {
    if (_currentUser == null) return;
    setState(() { _isSaved = !_isSaved; });
    _updateFirestoreSave();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_isSaved ? 'Đã lưu bài viết!' : 'Đã bỏ lưu bài viết.'),
      backgroundColor: _isSaved ? topazColor : sonicSilver,
      duration: const Duration(seconds: 1),
    ));
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
            postUserName: widget.postData['userName'] ?? 'Người dùng',
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
          postUserName: widget.postData['userName'] ?? 'Người dùng',
          initialShares: _sharesCount,
          onSharesUpdated: (newCount) {
            if (mounted) setState(() { _sharesCount = newCount; });
          },
        );
      },
    );
  }

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
          // DÒNG widget.onStateChange() ĐÃ ĐƯỢC XÓA HOÀN TOÀN
        }
      } catch (e) { /* Handle error */ }
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


  Widget _buildMoreOptionsButton(BuildContext context) {
    final bool isMyPost = widget.postData['uid'] == _currentUser?.uid;
    List<PopupMenuItem<String>> items = [
      const PopupMenuItem<String>(value: 'report', child: Text('Báo cáo bài viết')),
      const PopupMenuItem<String>(value: 'hide', child: Text('Ẩn bài viết này')),
      const PopupMenuItem<String>(value: 'unfollow', child: Text('Bỏ theo dõi người này')),
    ];
    if (isMyPost) {
      items.insert(0, const PopupMenuItem<String>(value: 'delete', child: Text('Xóa bài viết', style: TextStyle(color: coralRed))));
      items.insert(1, const PopupMenuItem<String>(value: 'edit', child: Text('Chỉnh sửa bài viết')));
    }

    return PopupMenuButton<String>(
      itemBuilder: (BuildContext context) => items,
      onSelected: (String value) {
        if (value == 'delete') {
          _deletePost();
        }
        // TODO: Handle other options
      },
      icon: const Icon(Icons.more_horiz, color: sonicSilver),
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
          if (count > 0) // <--- ĐÂY LÀ ĐIỀU KIỆN KIỂM TRA
            Text( // <--- VÀ ĐÂY LÀ WIDGET HIỂN THỊ CON SỐ
              count.toString(),
              style: const TextStyle(color: sonicSilver, fontSize: 13, fontWeight: FontWeight.w500),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? avatarUrl = widget.postData['userAvatarUrl'] as String?;
    final String? imageUrl = widget.postData['imageUrl'] as String?;
    final String userName = widget.postData['userName'] as String? ?? 'Người dùng';
    final String locationTime = widget.postData['locationTime'] as String? ?? '';
    final String tag = widget.postData['tag'] as String? ?? '';
    final String caption = widget.postData['postCaption'] as String? ?? '';

    final ImageProvider? postImageProvider = (imageUrl != null && imageUrl.isNotEmpty && imageUrl.startsWith('http'))
        ? NetworkImage(imageUrl) : null;
    final ImageProvider? avatarImageProvider = (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
        ? NetworkImage(avatarUrl) : null;

    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.only(bottom: 0),
      // =======================================================
      // THAY ĐỔI: Thêm màu nền đen cho PostCard để che đi khoảng trắng nếu có
      // =======================================================
      color: Colors.black, // Đặt nền đen cho card
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
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
                        Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                        if (locationTime.isNotEmpty)
                          Text(locationTime, style: TextStyle(color: sonicSilver.withOpacity(0.8), fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                if (tag.isNotEmpty) /* ... Tag ... */
                  _buildMoreOptionsButton(context),
              ],
            ),
          ),

          // 2. Caption
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 0.0, bottom: 8.0, right: 0.0),
              child: Text(caption, style: const TextStyle(color: Colors.white, fontSize: 15)),
            ),

          // 3. Ảnh bài viết
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

          // 4. Actions
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
} // End _PostCardState
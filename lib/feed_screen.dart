// lib/feed_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// SỬA LỖI XUNG ĐỘT IMPORT:
import 'profile_screen.dart'; // Giữ lại ProfileScreen từ file này
import 'comment_screen.dart'; // Giữ lại Comment và CommentBottomSheetContent từ file này
import 'share_sheet.dart';
import 'search_screen.dart';
// Ẩn các định nghĩa trùng lặp từ các file khác:
import 'notification_screen.dart' hide Comment, StoryViewScreen, CommentBottomSheetContent, ProfileScreen;
import 'create_story_screen.dart' hide StoryState; // feed_screen có định nghĩa StoryState riêng
import 'story_view_screen.dart' hide StoryContent; // create_story_screen đã định nghĩa StoryContent
import 'story_manager_screen.dart' hide StoryContent;
import 'suggested_friend_card.dart' hide ProfileScreen;
import 'post_detail_screen.dart';

// --- Định nghĩa Comment (Giữ lại hoặc import từ file riêng) ---
class Comment {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatarUrl; // Chỉ dùng URL
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
      userName: data['userName'] ?? 'Người dùng ẩn',
      userAvatarUrl: data['userAvatarUrl'], // Lấy URL (có thể null)
      text: data['text'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      parentId: data['parentId'],
      likesCount: (data['likesCount'] is num ? (data['likesCount'] as num).toInt() : 0), // Ensure int
      likedBy: likedByList,
      isLiked: currentUserId.isNotEmpty && likedByList.contains(currentUserId),
    );
  }
}
// --- Kết thúc định nghĩa Comment ---

// =======================================================
// CONSTANTS (Giữ lại)
// =======================================================
const Color topazColor = Color(0xFFF6C886);
const Color earthYellow = Color(0xFFE0A263);
const Color coralRed = Color(0xFFFD402C);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color activeGreen = Color(0xFF32CD32);

// --- Story State (Giữ lại tạm thời nếu các màn hình khác cần) ---
class StoryState {
  DateTime? lastPostTime;
  List<String> likedBy = [];
  StoryContent? activeStoryContent;

  bool get hasActiveStory {
    if (lastPostTime == null) return false;
    return DateTime.now().difference(lastPostTime!) < const Duration(hours: 24);
  }
// No longer need selfStoryData referencing assets
}
final StoryState globalUserStoryState = StoryState();
// --- Kết thúc Story State ---


// =======================================================
// WIDGET CHUÔNG THÔNG BÁO (Giữ nguyên)
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

  Stream<QuerySnapshot>? _notificationStream; // Stream listener

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _animation = Tween(begin: 0.0, end: 5.0).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _listenForNotifications(); // Start listening
  }

  void _listenForNotifications() {
    final user = _auth.currentUser;
    if (user != null) {
      // Create the stream
      _notificationStream = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .limit(1) // Only need to know if at least one exists
          .snapshots();

      // Listen to the stream
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
        // Optionally handle the error, e.g., set _hasNotification to false
        if (mounted) {
          setState(() { _hasNotification = false; });
          _controller.stop();
          _controller.reset();
        }
      });
    } else {
      // Handle case where user is null (e.g., logged out)
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
    // Cancel the stream listener if needed, though streams usually handle this
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
            size: 28
        ),
        onPressed: () {
          // UI update will happen via stream when NotificationScreen marks as read
          widget.onOpenNotification(); // Open notification screen
        },
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        splashRadius: 24,
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
  String _selectedTag = 'All';
  User? _currentUser;
  final List<String> _availableTags = ['All', 'Art', 'Fashion', 'Food', 'Gaming', 'Music', 'Pet', 'Sport', 'Technology', 'Travel', 'New'];
  Stream<QuerySnapshot>? _storiesStream; // Stream for active stories
  Map<String, bool> _viewedStories = {}; // Local state to track viewed stories in this session

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _loadActiveStories(); // Load stories initially
  }

  void _loadActiveStories() {
    // Query stories collection for active stories (expiresAt > now)
    // You might want to filter further (e.g., only friends' stories)
    _storiesStream = _firestore
        .collection('stories')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt') // Or orderBy timestamp
        .limit(20) // Limit initial load
        .snapshots();
  }


  void _forceRebuild() { if (mounted) setState(() {}); }
  void _selectTag(String tag) { setState(() { _selectedTag = tag; }); }

  void _navigateToStoryScreen(Widget screen, VoidCallback onClosed) {
    Navigator.of(context).push(
      PageRouteBuilder( /* ... transitions ... */
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

  String _formatActivityTime(DateTime? lastActive, bool isOnline) { /* ... Giữ nguyên ... */ return ''; }

  // Logic Refresh Feed (Cập nhật để fetch lại data)
  Future<void> _handleRefresh() async {
    // Reset viewed stories locally
    setState(() {
      _viewedStories.clear();
    });
    // Re-trigger stream builders by calling setState (or fetch specific data)
    _loadActiveStories(); // Reload stories stream
    setState(() {}); // Trigger rebuild for post feed StreamBuilder
    // Giả lập thời gian tải lại
    await Future.delayed(const Duration(milliseconds: 500));
    print("Refresh Feed...");
  }

  // Widget Story Avatar nhỏ (Sử dụng data từ Firestore Stream)
  Widget _buildSmallStoryAvatar(BuildContext context, DocumentSnapshot storyDoc) {
    final storyData = storyDoc.data() as Map<String, dynamic>? ?? {};
    final String storyUserId = storyData['userId'] ?? '';
    final String storyUserName = storyData['userName'] ?? 'Người dùng';
    final String? storyUserAvatarUrl = storyData['userAvatarUrl'] as String?;
    final String storyId = storyDoc.id; // Unique ID for this story document

    final bool isCurrentUserStory = storyUserId == _currentUser?.uid;
    // Use local state _viewedStories to track viewed status in this session
    final bool storyViewed = _viewedStories[storyId] ?? false;

    // Xác định ImageProvider từ URL hoặc null
    final ImageProvider? avatarProvider = (storyUserAvatarUrl != null && storyUserAvatarUrl.isNotEmpty)
        ? NetworkImage(storyUserAvatarUrl)
        : null;

    // Viền avatar
    final BoxDecoration avatarBorder = (!storyViewed)
        ? BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [topazColor.withOpacity(0.8), earthYellow.withOpacity(0.8)], // Cung cấp màu
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
    )
        : BoxDecoration( /* ... grey border ... */ );

    return GestureDetector(
      onTap: () {
        // Truyền thông tin story vào StoryViewScreen
        // Cần lấy danh sách các story IDs của *cùng user này*
        // Điều này yêu cầu query phức tạp hơn hoặc thay đổi cấu trúc data
        // Tạm thời chỉ xem story này
        if (!isCurrentUserStory) { // Mark as viewed when tapping others' stories
          setState(() { _viewedStories[storyId] = true; });
        }
        _navigateToStoryScreen(
            StoryViewScreen(
                userName: storyUserName,
                avatarUrl: storyUserAvatarUrl, // Tham số này đã chấp nhận null
                storyDocs: [storyDoc] // Sửa lỗi: Truyền [storyDoc] cho tham số storyDocs
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
              isCurrentUserStory ? 'Tin của bạn' : storyUserName.split(' ').first, // Hiển thị tên ngắn gọn
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

  // Avatar của chính user để tạo story
  Widget _buildMyStoryCreatorAvatar(BuildContext context) {
    final String? currentUserAvatar = _currentUser?.photoURL;
    final ImageProvider? avatarProvider = (currentUserAvatar != null && currentUserAvatar.isNotEmpty)
        ? NetworkImage(currentUserAvatar)
        : null;

    return GestureDetector(
      onTap: () {
        // Navigate based on whether the user already has an active story
        // This requires checking the _storiesStream or querying Firestore
        // For simplicity, always navigate to CreateStoryScreen for now
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CreateStoryScreen()))
            .then((_) => _forceRebuild()); // Rebuild FeedScreen when returning
      },
      child: Container(
        width: 70,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack( // Use Stack to add the '+' icon
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: darkSurface,
                  backgroundImage: avatarProvider,
                  child: avatarProvider == null ? const Icon(Icons.person, color: sonicSilver, size: 30) : null,
                ),
                Container( // Blue '+' icon
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent, // Or topazColor
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
              style: TextStyle(color: Colors.white, fontSize: 12), // Always white for creator
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }


  // Helper kiểm tra online/hoạt động gần đây (Giữ nguyên)
  bool isOnlineOrRecent(DateTime? lastActive) { /* ... */ return false; }

  // Helper điều hướng đến Profile Screen (Giữ nguyên)
  void _navigateToProfile(String targetUsernameOrUid) { /* ... */ }

  // Widget Header đơn giản (Không dùng ảnh asset)
  Widget _buildSimpleHeader(BuildContext context) {
    final String? currentUserAvatar = _currentUser?.photoURL;
    final String currentUsername = _currentUser?.displayName ?? 'You';
    final ImageProvider? avatarProvider = (currentUserAvatar != null && currentUserAvatar.isNotEmpty)
        ? NetworkImage(currentUserAvatar)
        : null;

    return Padding( /* ... */
      padding: const EdgeInsets.only(top: 50, bottom: 10, left: 8, right: 16), // Đã sửa padding
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _navigateToProfile(_currentUser?.uid ?? currentUsername), // Use UID if available
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: avatarProvider,
                  backgroundColor: darkSurface,
                  child: avatarProvider == null ? const Icon(Icons.person, color: sonicSilver, size: 20) : null,
                ),
                // ... Rest of header
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, color: sonicSilver, size: 28),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SearchScreen()));
            },
            padding: EdgeInsets.zero,
            splashRadius: 24,
          ),
          const SizedBox(width: 10),
          AnimatedNotificationBell(
            onOpenNotification: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const NotificationScreen()));
            },
          ),
        ],
      ),
    );
  }

  // Widget Tag Filter (Giữ nguyên)
  Widget _buildTag(String tag, bool isSelected, VoidCallback onTap) { /* ... */ return GestureDetector(/* ... */); }

  // Widget Gợi ý kết bạn (Không dùng ảnh asset)
  // Widget Gợi ý kết bạn (Không dùng ảnh asset)
  Widget _buildSuggestedFriendsSection(BuildContext context) {
    // TODO: Lấy danh sách gợi ý từ Firestore/Backend
    final List<Map<String, dynamic>> suggestedFriends = [
      {'uid': 'mock_uid_1', 'name': 'Nguyễn T.', 'avatarUrl': null, 'mutual': 20},
      {'uid': 'mock_uid_2', 'name': 'Lê A.', 'avatarUrl': null, 'mutual': 15},
      // ... more mock data without local assets
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // Thêm căn lề trái
      children: [
        const Padding( // <- DÒNG 428 (Đã sửa)
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // <- Sửa lỗi: Cung cấp padding
          child: Text( // <- Sửa lỗi: Cung cấp child
            'Gợi ý cho bạn',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal, // Thêm hướng cuộn
            padding: const EdgeInsets.symmetric(horizontal: 16.0), // Thêm padding cho ListView
            itemCount: suggestedFriends.length,
            itemBuilder: (context, index) {
              final friend = suggestedFriends[index];
              return SuggestedFriendCard( // SuggestedFriendCard handles null avatarUrl
                key: ValueKey(friend['uid']),
                friendData: friend,
                onStateChange: _forceRebuild,
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  // Widget hiển thị danh sách bài viết (Không dùng ảnh asset)
  Widget _buildPostFeed() {
    final currentUserId = _currentUser?.uid ?? '';
    Query query = _firestore.collection('posts').orderBy('timestamp', descending: true);
    if (_selectedTag != 'All') { /* ... filter by tag ... */ }

    return StreamBuilder<QuerySnapshot>(
      stream: query.limit(20).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
              padding: EdgeInsets.only(top: 50.0),
              child: CircularProgressIndicator(color: topazColor)
          ));
        }
        if (snapshot.hasError) {
          print("Lỗi tải bài viết: ${snapshot.error}");
          return Center(child: Text('Lỗi tải bài viết: ${snapshot.error}', style: const TextStyle(color: coralRed)));
        }

        // SỬA LỖI: Tránh Null Check Operator
        final posts = snapshot.data?.docs ?? []; // Lấy docs hoặc danh sách rỗng
        if (posts.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Chưa có bài viết nào.', style: TextStyle(color: sonicSilver))));
        }
        return ListView.builder(
          itemCount: posts.length,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 16.0).copyWith(top: 10),
          itemBuilder: (context, index) {
            final doc = posts[index];
            Map<String, dynamic> postData = doc.data() as Map<String, dynamic>? ?? {}; // Handle null data
            postData['id'] = doc.id;

            // ... (Process likes, comments, shares, isLiked, isSaved) ...

            // Get URLs directly, allow null
            postData['userAvatarUrl'] = postData['userAvatarUrl'];
            postData['imageUrl'] = postData['imageUrl'];

            postData['locationTime'] = (postData['timestamp'] as Timestamp?) != null ? _formatTimestampAgo(postData['timestamp']) : 'Vừa xong';

            return PostCard( // PostCard handles null URLs
              key: ValueKey(postData['id']),
              postData: postData,
              onStateChange: _forceRebuild,
            );
          },
        );
      },
    );
  }

  // --- Hàm format Timestamp (Giữ nguyên) ---
  String _formatTimestampAgo(Timestamp timestamp) { /* ... */ return ''; }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: topazColor,
        backgroundColor: darkSurface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSimpleHeader(context),

              // Story Avatars Row (using StreamBuilder)
              SizedBox(
                height: 110,
                child: StreamBuilder<QuerySnapshot>(
                    stream: _storiesStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && !_storiesStreamHasData(snapshot)) {
                        // Show minimal loading or nothing while waiting for initial data
                        return const SizedBox.shrink(); // Or a subtle indicator
                      }
                      if (snapshot.hasError) {
                        return const Center(child: Icon(Icons.error_outline, color: sonicSilver));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        // Only show "My Story" creator if no other stories exist
                        return ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          children: [_buildMyStoryCreatorAvatar(context)],
                        );
                      }

                      final storyDocs = snapshot.data!.docs;
                      // TODO: Filter/Sort stories (e.g., friends first, unviewed first)
                      // Simple display for now: My Story Creator + Active Stories
                      return ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        children: [
                          _buildMyStoryCreatorAvatar(context), // Always show creator first
                          ...storyDocs
                              .where((doc) => (doc.data() as Map<String, dynamic>?)?['userId'] != _currentUser?.uid) // Exclude current user's stories from the main list
                              .map((doc) => _buildSmallStoryAvatar(context, doc))
                              .toList(),
                        ],
                      );
                    }
                ),
              ),
              const SizedBox(height: 10),

              _buildTagFilters(), // Tag Filters (Unchanged)
              const SizedBox(height: 15),

              if (_selectedTag == 'All') ...[ // Suggested Friends (Unchanged)
                _buildSuggestedFriendsSection(context),
                const Divider(color: darkSurface, height: 1, thickness: 8),
              ],

              _buildPostFeed(), // Post Feed (Updated)
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // Helper to check if the stories stream has emitted data at least once
  bool _storiesStreamHasData(AsyncSnapshot<QuerySnapshot> snapshot) {
    return snapshot.connectionState != ConnectionState.waiting || (snapshot.hasData || snapshot.hasError);
  }


  // Separate method for tag filters for clarity
  Widget _buildTagFilters() {
    return SizedBox(
      height: 45,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        children: _availableTags.map((tag) => _buildTag(tag, _selectedTag == tag, () => _selectTag(tag))).toList(),
      ),
    );
  }

} // End _FeedScreenState


// =======================================================
// PostCard Widget (Đã cập nhật để xử lý avatar/image null)
// =======================================================
class PostCard extends StatefulWidget {
  final Map<String, dynamic> postData;
  final VoidCallback onStateChange;
  const PostCard({super.key, required this.postData, required this.onStateChange});

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
    if (widget.postData['id'] != oldWidget.postData['id'] || widget.postData['timestamp'] != oldWidget.postData['timestamp']) {
      _updateStateFromWidget();
    }
  }

  void _updateStateFromWidget() {
    _postId = widget.postData['id'] as String? ?? '';
    _isLiked = widget.postData['isLiked'] as bool? ?? false;
    _isSaved = widget.postData['isSaved'] as bool? ?? false;
    _likesCount = widget.postData['likes'] as int? ?? 0;
    _commentsCount = widget.postData['comments'] as int? ?? 0;
    _sharesCount = widget.postData['shares'] as int? ?? 0;
  }

  // --- Firestore Update Logic (_updateFirestoreLike, _updateFirestoreSave) ---
  void _updateFirestoreLike() {
    if (_currentUser == null || _postId.isEmpty) return;
    final userId = _currentUser!.uid;
    final postRef = _firestore.collection('posts').doc(_postId);
    final updateData = _isLiked
        ? {'likedBy': FieldValue.arrayUnion([userId]), 'likesCount': FieldValue.increment(1)}
        : {'likedBy': FieldValue.arrayRemove([userId]), 'likesCount': FieldValue.increment(-1)};
    postRef.update(updateData).catchError((e) => print("Error updating like: $e"));
    // TODO: Add notification logic
  }

  void _updateFirestoreSave() {
    if (_currentUser == null || _postId.isEmpty) return;
    final userId = _currentUser!.uid;
    final postRef = _firestore.collection('posts').doc(_postId);
    final updateData = _isSaved
        ? {'savedBy': FieldValue.arrayUnion([userId])}
        : {'savedBy': FieldValue.arrayRemove([userId])};
    postRef.update(updateData).catchError((e) => print("Error updating save: $e"));
  }

  // --- UI Toggles (_toggleLike, _toggleSave) ---
  void _toggleLike() {
    if (_currentUser == null) return; // Prevent action if not logged in
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    _updateFirestoreLike();
  }

  void _toggleSave() {
    if (_currentUser == null) return; // Prevent action if not logged in
    setState(() { _isSaved = !_isSaved; });
    _updateFirestoreSave();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_isSaved ? 'Đã lưu bài viết!' : 'Đã bỏ lưu bài viết.'),
      backgroundColor: _isSaved ? topazColor : sonicSilver,
      duration: const Duration(seconds: 1),
    ));
  }

  // --- Show Bottom Sheets (_showCommentSheet, _showShareSheet) ---
  void _showCommentSheet(BuildContext context) {
    // Ensure CommentBottomSheetContent is defined/imported
    if (_postId.isEmpty) return;
    final String postMediaUrl = widget.postData['imageUrl'] ?? ''; // Pass empty string if null
    final bool isPostOwner = widget.postData['uid'] == _currentUser?.uid;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.95,
          child: CommentBottomSheetContent( // Assuming CommentBottomSheetContent handles null image URL
            postId: _postId,
            postUserName: widget.postData['userName'] ?? 'Người dùng',
            currentCommentCount: _commentsCount,
            postMediaUrl: postMediaUrl, // Pass potentially empty URL
            postCaption: widget.postData['postCaption'] ?? '',
            isPostOwner: isPostOwner,
            onCommentPosted: (newCount) {
              if (mounted) {
                setState(() { _commentsCount = newCount; });
                // Optionally call widget.onStateChange() if FeedScreen needs immediate update
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
      context: context, // Sửa lỗi: Thêm context
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) { // Sửa lỗi: Thêm builder
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

  // --- Delete Post Logic (_deletePost) ---
  void _deletePost() async {
    if (widget.postData['uid'] != _currentUser?.uid || _postId.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context, // Sửa lỗi: Thêm context
      builder: (BuildContext dialogContext) { // Sửa lỗi: Thêm builder
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
        // TODO: Delete image from Storage if applicable
        await _firestore.collection('posts').doc(_postId).delete();
        // TODO: Delete subcollections (comments, etc.) via Cloud Function recommended
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa bài viết.')));
          widget.onStateChange(); // Notify parent to rebuild
        }
      } catch (e) { /* Handle error */ }
    }
  }

  // --- Navigate to Profile (_navigateToProfile) ---
  void _navigateToProfile(String targetUsernameOrUid) {
    final targetUid = widget.postData['uid']; // Prefer UID from post data
    final fallbackId = (targetUsernameOrUid == (_currentUser?.displayName ?? 'You')) ? _currentUser?.uid : targetUsernameOrUid; // Fallback logic needs adjustment if username != UID
    final profileId = targetUid ?? fallbackId;

    if (profileId == null || profileId.isEmpty) {
      print("Error: Cannot navigate to profile, missing ID.");
      return;
    }

    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => ProfileScreen(
        targetUserId: profileId == _currentUser?.uid ? null : profileId, // Pass null for own profile
        onNavigateToHome: () => Navigator.pop(context),
        onLogout: () {}, // Provide dummy logout
      ),
    ));
  }


  // --- More Options Button (_buildMoreOptionsButton) ---
  // --- More Options Button (_buildMoreOptionsButton) ---
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
      itemBuilder: (BuildContext context) => items, // SỬA LỖI: Thêm itemBuilder
      onSelected: (String value) {
        if (value == 'delete') {
          _deletePost();
        }
        // TODO: Handle other options (edit, report, hide, unfollow)
      },
      icon: const Icon(Icons.more_horiz, color: sonicSilver),
      color: darkSurface,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  // --- Interaction Button Helper (_buildInteractionButton) ---
  Widget _buildInteractionButton({
    required IconData icon, // SỬA LỖI: Thêm tham số
    required Color color,    // SỬA LỖI: Thêm tham số
    required int count,      // SỬA LỖI: Thêm tham số
    required VoidCallback onTap, // SỬA LỖI: Thêm tham số
  }) {
    return InkWell(
      onTap: onTap,
      child: Row( // SỬA LỖI: Thêm child
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 4),
          if (count > 0)
            Text(
              count.toString(), // TODO: Format large numbers
              style: const TextStyle(color: sonicSilver, fontSize: 13, fontWeight: FontWeight.w500),
            ),
        ],
      ),
    );
  }

// --- Build Method ---
@override
Widget build(BuildContext context) {
  // Lấy dữ liệu từ state cục bộ
  final String? avatarUrl = widget.postData['userAvatarUrl'] as String?;
  final String? imageUrl = widget.postData['imageUrl'] as String?;
  final String userName = widget.postData['userName'] as String? ?? 'Người dùng';
  final String locationTime = widget.postData['locationTime'] as String? ?? '';
  final String tag = widget.postData['tag'] as String? ?? '';
  final String caption = widget.postData['postCaption'] as String? ?? '';

  // Xác định ImageProvider (có thể null)
  final ImageProvider? postImageProvider = (imageUrl != null && imageUrl.isNotEmpty && imageUrl.startsWith('http'))
      ? NetworkImage(imageUrl) : null;
  final ImageProvider? avatarImageProvider = (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
      ? NetworkImage(avatarUrl) : null;

  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8.0),
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 12.0, right: 0),
          child: Row(
            children: [
              GestureDetector(
                  onTap: () => _navigateToProfile(userName), // Pass username as fallback
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
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0, right: 8.0),
            child: Text(caption, style: const TextStyle(color: Colors.white, fontSize: 15)),
          ),

        // 3. Ảnh bài viết
        GestureDetector(
          onDoubleTap: _toggleLike,
          onTap: () { /* Navigate to PostDetailScreen */ },
          child: AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), color: darkSurface),
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
          padding: const EdgeInsets.only(top: 10.0, left: 8, right: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildInteractionButton(icon: _isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? coralRed : sonicSilver, count: _likesCount, onTap: _toggleLike),
                  const SizedBox(width: 15),
                  _buildInteractionButton(icon: Icons.chat_bubble_outline_rounded, color: sonicSilver, count: _commentsCount, onTap: () => _showCommentSheet(context)),
                  const SizedBox(width: 15),
                  _buildInteractionButton(icon: Icons.send_rounded, color: sonicSilver, count: _sharesCount, onTap: () => _showShareSheet(context)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(_isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: _isSaved ? topazColor : sonicSilver, size: 24),
                    onPressed: _toggleSave,
                    padding: const EdgeInsets.symmetric(horizontal: 12), constraints: const BoxConstraints(), splashRadius: 24,
                  ),
                ],
              ),
              if (_likesCount > 0) ... [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 4.0), // Sửa lỗi: Thêm padding
                  child: Text( // Sửa lỗi: Thêm child
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

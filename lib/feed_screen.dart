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
      userName: data['displayName'] ?? 'Người dùng Zink', // SỬA Ở ĐÂY
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
  // ... (giữ lại các biến final _auth, _firestore, _currentUser, _headerContentHeight)
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  final double _headerContentHeight = 45.0;

  // --- BẮT ĐẦU PHẦN CẦN THAY THẾ/THÊM VÀO ---

  // Lưu trữ danh sách bạn bè gợi ý
  List<DocumentSnapshot> _suggestedFriends = [];
  // Cờ để biết đã fetch dữ liệu hay chưa
  bool _hasFetchedSuggestions = false;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _fetchSuggestedFriends(); // Gọi hàm để tải dữ liệu gợi ý khi màn hình khởi động
  }

  Future<void> _handleRefresh() async {
    // Khi refresh, tải lại danh sách gợi ý và để StreamBuilder tự cập nhật bài viết
    _hasFetchedSuggestions = false;
    await _fetchSuggestedFriends();
    if (mounted) setState(() {});
  }

  Future<void> _fetchSuggestedFriends() async {
    if (_hasFetchedSuggestions || _currentUser == null) return;

    try {
      // 1. Lấy danh sách những người mà người dùng hiện tại đang theo dõi
      final followingSnapshot = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('following')
          .get();
      final followingIds = followingSnapshot.docs.map((doc) => doc.id).toList();
      followingIds.add(_currentUser!.uid); // Loại bỏ chính mình khỏi danh sách gợi ý

      // 2. Lấy danh sách người dùng, loại trừ những người đã theo dõi
      final usersSnapshot = await _firestore.collection('users').limit(10).get();

      final suggestions = usersSnapshot.docs.where((doc) {
        return !followingIds.contains(doc.id);
      }).toList();

      // Xáo trộn danh sách gợi ý và lấy 5 người
      suggestions.shuffle();
      if (mounted) {
        setState(() {
          _suggestedFriends = suggestions.take(5).toList();
          _hasFetchedSuggestions = true;
        });
      }
    } catch (e) {
      print("Lỗi khi lấy danh sách gợi ý kết bạn: $e");
    }
  }

  // Widget _buildPostFeedSliver đã được sửa
  Widget _buildPostFeedSliver() {
    Query query = _firestore.collection('posts').orderBy('timestamp', descending: true);
    const int suggestionInsertionIndex = 3;

    return StreamBuilder<QuerySnapshot>(
      stream: query.limit(20).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !_hasFetchedSuggestions) {
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

        // Chèn mục gợi ý vào danh sách nếu có đủ bài viết
        if (_suggestedFriends.isNotEmpty && posts.length >= suggestionInsertionIndex) {
          combinedList.insert(suggestionInsertionIndex, _suggestedFriends);
        } else if (_suggestedFriends.isNotEmpty) {
          // Nếu không đủ bài viết, chèn vào cuối
          combinedList.add(_suggestedFriends);
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final item = combinedList[index];

              // KIỂM TRA: Nếu item là danh sách gợi ý, hiển thị SuggestedFriendsSection
              if (item is List<DocumentSnapshot>) {
                return SuggestedFriendsSection(suggestedFriends: item);
              }

              // Nếu không, nó là một bài viết (DocumentSnapshot)
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

  // --- KẾT THÚC PHẦN THAY THẾ/THÊM VÀO ---

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
          // Zink Logo
          const Text(
            'Zink',
            style: TextStyle(
              fontFamily: 'Roboto', // Or your custom font
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: Colors.white,
            ),
          ),
          // Action Icons
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

  const SuggestedFriendsSection({
    Key? key,
    required this.suggestedFriends,
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
            height: 200, // Increased height to accommodate buttons
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: suggestedFriends.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final userDoc = suggestedFriends[index];
                final userData = userDoc.data() as Map<String, dynamic>;
                return SuggestedFriendCard(
                  userId: userDoc.id,
                  userName: userData['displayName'] ?? 'Người dùng', // SỬA Ở ĐÂY
                  userAvatarUrl: userData['photoURL'],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// SuggestedFriendCard Widget (STATEFUL VERSION)
// =======================================================
class SuggestedFriendCard extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userAvatarUrl;

  const SuggestedFriendCard({
    Key? key,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
  }) : super(key: key);

  @override
  State<SuggestedFriendCard> createState() => _SuggestedFriendCardState();
}

class _SuggestedFriendCardState extends State<SuggestedFriendCard> {
  bool _isFriendRequestSent = false;
  bool _isFollowing = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _navigateToProfile() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => ProfileScreen(
        targetUserId: widget.userId,
        onNavigateToHome: () {},
        onLogout: () {},
      ),
    ));
  }

  void _toggleFriendRequest() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final myDocRef = _firestore.collection('users').doc(currentUser.uid);
    final theirDocRef = _firestore.collection('users').doc(widget.userId);

    if (_isFriendRequestSent) {
      myDocRef.update({'sentRequests': FieldValue.arrayRemove([widget.userId])});
      theirDocRef.update({'receivedRequests': FieldValue.arrayRemove([currentUser.uid])});
    } else {
      myDocRef.update({'sentRequests': FieldValue.arrayUnion([widget.userId])});
      theirDocRef.update({'receivedRequests': FieldValue.arrayUnion([currentUser.uid])});
    }

    setState(() {
      _isFriendRequestSent = !_isFriendRequestSent;
    });
  }

  void _toggleFollow() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final myFollowingRef = _firestore.collection('users').doc(currentUser.uid).collection('following');
    final theirFollowersRef = _firestore.collection('users').doc(widget.userId).collection('followers');

    if (_isFollowing) {
      myFollowingRef.doc(widget.userId).delete();
      theirFollowersRef.doc(currentUser.uid).delete();
    } else {
      myFollowingRef.doc(widget.userId).set({'timestamp': FieldValue.serverTimestamp()});
      theirFollowersRef.doc(currentUser.uid).set({'timestamp': FieldValue.serverTimestamp()});
    }

    setState(() {
      _isFollowing = !_isFollowing;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          GestureDetector(
            onTap: _navigateToProfile,
            child: CircleAvatar(
              radius: 35,
              backgroundColor: sonicSilver,
              backgroundImage: (widget.userAvatarUrl != null) ? NetworkImage(widget.userAvatarUrl!) : null,
              child: (widget.userAvatarUrl == null) ? const Icon(Icons.person, size: 30, color: Colors.white) : null,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _navigateToProfile,
            child: Text(
              widget.userName,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 32,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _toggleFriendRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFriendRequestSent ? Colors.grey[800] : topazColor,
                foregroundColor: _isFriendRequestSent ? sonicSilver : Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(
                _isFriendRequestSent ? 'Hủy lời mời' : 'Kết bạn',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _toggleFollow,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFollowing ? Colors.grey[800] : Colors.blueAccent,
                foregroundColor: _isFollowing ? sonicSilver : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(
                _isFollowing ? 'Hủy theo dõi' : 'Theo dõi',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
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

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _updateStateFromWidget();
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
        ? {'savedBy': FieldValue.arrayUnion([userId])}
        : {'savedBy': FieldValue.arrayRemove([userId])};
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
            postUserName: widget.postData['displayName'] ?? 'Người dùng', // SỬA Ở ĐÂY
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
          postUserName: widget.postData['displayName'] ?? 'Người dùng', // SỬA Ở ĐÂY
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
          if (count > 0)
            Text(
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
    final String userName = widget.postData['displayName'] as String? ?? 'Người dùng'; // SỬA Ở ĐÂY
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
                        Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                        if (locationTime.isNotEmpty)
                          Text(locationTime, style: TextStyle(color: sonicSilver.withOpacity(0.8), fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                if (tag.isNotEmpty)
                  _buildMoreOptionsButton(context),
              ],
            ),
          ),

          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 0.0, bottom: 8.0, right: 0.0),
              child: Text(caption, style: const TextStyle(color: Colors.white, fontSize: 15)),
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
}

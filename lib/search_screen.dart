// lib/search_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart' hide PostDetailScreen;
import 'post_detail_screen.dart'; // <--- NEW IMPORT for navigation

// --- Giả định các file và hằng số này tồn tại ---
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C);
const Color activeGreen = Color(0xFF32CD32);

// --- PostCard Placeholder ĐÃ BỊ LOẠI BỎ ---

// --- NEW WIDGET: Post Grid Item ---
class _PostGridItem extends StatelessWidget {
  final Map<String, dynamic> postData;
  final Function(String postId, Map<String, dynamic> postData) onTap;

  const _PostGridItem({required this.postData, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final String postId = postData['id'] as String? ?? '';
    final String? imageUrl = postData['imageUrl'] as String?;
    final ImageProvider? imageProvider = (imageUrl != null && imageUrl.isNotEmpty && imageUrl.startsWith('http'))
        ? NetworkImage(imageUrl)
        : null;

    return GestureDetector(
      onTap: () => onTap(postId, postData),
      child: Container(
        decoration: BoxDecoration(
          color: darkSurface,
          image: imageProvider != null
              ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
              : null,
        ),
        child: imageProvider == null
            ? const Center(child: Icon(Icons.image_not_supported, color: sonicSilver, size: 30))
            : null,
      ),
    );
  }
}
// ---------------------------------


class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _isLoading = false;

  List<Map<String, dynamic>> _userSearchResults = [];
  List<Map<String, dynamic>> _postSearchResults = [];
  List<String> _recentSearches = [];
  Timer? _debounce;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    // _loadRecentSearches(); // TODO: Tải từ bộ nhớ cục bộ nếu cần
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text.trim();
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        // Khi xóa hết chữ, reset về trạng thái ban đầu để hiện list recent
        setState(() {
          _userSearchResults = [];
          _postSearchResults = [];
          _isLoading = false;
        });
      }
    });
    // Cập nhật query để rebuild UI (hiện nút clear)
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  void _addRecentSearch(String query) {
    if (query.isEmpty) return;
    setState(() {
      _recentSearches.remove(query); // Xóa nếu đã có để đưa lên đầu
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 10) {
        _recentSearches = _recentSearches.sublist(0, 10);
      }
      // _saveRecentSearches(); // TODO: Lưu vào bộ nhớ cục bộ
    });
  }

  void _navigateToProfile(Map<String, dynamic> userData) {
    final targetUid = userData['uid'] as String?;
    if (targetUid == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => ProfileScreen(
        targetUserId: targetUid,
        onNavigateToHome: () => Navigator.pop(context),
        onLogout: () {},
      ),
    ));
  }

  // --- NEW FUNCTION: Navigate to Post Detail ---
  void _navigateToPostDetail(String postId, Map<String, dynamic> postData) {
    if (postId.isEmpty) return;
    // Đảm bảo postData có 'id' trước khi truyền đi
    postData['id'] = postId;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(postData: postData),
      ),
    );
  }
  // ---------------------------------------------

  Future<void> _toggleFollow(Map<String, dynamic> targetUserData) async {
    final currentUserId = _currentUser?.uid;
    final targetUserId = targetUserData['uid'] as String?;
    if (currentUserId == null || targetUserId == null) return;

    final isCurrentlyFollowing = (targetUserData['isFollowing'] as bool?) ?? false;
    final writeBatch = _firestore.batch();

    final currentUserRef = _firestore.collection('users').doc(currentUserId);
    final targetUserRef = _firestore.collection('users').doc(targetUserId);

    if (isCurrentlyFollowing) {
      writeBatch.update(currentUserRef, {
        'followingUids': FieldValue.arrayRemove([targetUserId]),
        'followingCount': FieldValue.increment(-1),
      });
      writeBatch.update(targetUserRef, {
        'followerUids': FieldValue.arrayRemove([currentUserId]),
        'followerCount': FieldValue.increment(-1),
      });
    } else {
      writeBatch.update(currentUserRef, {
        'followingUids': FieldValue.arrayUnion([targetUserId]),
        'followingCount': FieldValue.increment(1),
      });
      writeBatch.update(targetUserRef, {
        'followerUids': FieldValue.arrayUnion([currentUserId]),
        'followerCount': FieldValue.increment(1),
      });
    }
    await writeBatch.commit();
  }

  Future<void> _toggleFriendRequest(Map<String, dynamic> targetUserData) async {
    final currentUserId = _currentUser?.uid;
    final targetUserId = targetUserData['uid'] as String?;
    if (currentUserId == null || targetUserId == null) return;

    final isPending = (targetUserData['isPending'] as bool?) ?? false;

    final currentUserRef = _firestore.collection('users').doc(currentUserId);
    final targetUserRef = _firestore.collection('users').doc(targetUserId);
    final theirNotifications = targetUserRef.collection('notifications');

    try {
      if (isPending) {
        // Hủy lời mời đã gửi
        await currentUserRef.update({'outgoingRequests': FieldValue.arrayRemove([targetUserId])});

        // Xóa thông báo tương ứng ở người nhận
        final notifQuery = await theirNotifications
            .where('type', isEqualTo: 'friend_request')
            .where('senderId', isEqualTo: currentUserId)
            .limit(1)
            .get();
        for (var doc in notifQuery.docs) {
          await doc.reference.delete();
        }

      } else {
        // Gửi lời mời mới
        // 1. Lấy thông tin người gửi (là bạn)
        DocumentSnapshot myUserDoc = await currentUserRef.get();
        String senderName = 'Một người dùng';
        String? senderAvatarUrl;

        if (myUserDoc.exists) {
          final myData = myUserDoc.data() as Map<String, dynamic>;
          senderName = myData['displayName'] ?? 'Một người dùng';
          senderAvatarUrl = myData['photoURL'];
        }

        // 2. Cập nhật mảng lời mời đã gửi của bạn
        await currentUserRef.update({'outgoingRequests': FieldValue.arrayUnion([targetUserId])});

        // 3. TẠO THÔNG BÁO MỚI cho người nhận
        await theirNotifications.add({
          'type': 'friend_request',
          'senderId': currentUserId,
          'senderName': senderName,
          'senderAvatarUrl': senderAvatarUrl,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'actionTaken': false,
        });
      }

      // Cập nhật lại UI (vì _UserSearchResultTile dùng StreamBuilder nên nó sẽ tự cập nhật)

    } catch (e) {
      print("Lỗi khi gửi/hủy lời mời kết bạn (search_screen): $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã có lỗi xảy ra. Vui lòng thử lại.')),
        );
      }
    }
  }
  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _userSearchResults = [];
        _postSearchResults = [];
        _isLoading = false;
      });
      return;
    }

    _addRecentSearch(query);
    setState(() {
      _isLoading = true;
      _searchQuery = query;
    });

    try {
      final currentUserId = _currentUser?.uid;
      if (currentUserId == null) return;

      final queryLower = query.toLowerCase();

      final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
      final currentUserFriendUids = List<String>.from(currentUserDoc.data()?['friendUids'] ?? []);

      final usernameQuery = _firestore.collection('users').where('usernameLower', isGreaterThanOrEqualTo: queryLower).where('usernameLower', isLessThanOrEqualTo: '$queryLower\uf8ff').limit(10).get();
      final displayNameQuery = _firestore.collection('users').where('displayNameLower', isGreaterThanOrEqualTo: queryLower).where('displayNameLower', isLessThanOrEqualTo: '$queryLower\uf8ff').limit(10).get();
      final postTagQuery = _firestore.collection('posts').where('tags', arrayContains: queryLower).limit(10).get();
      final postAuthorQuery = _firestore.collection('posts').where('displayNameLower', isGreaterThanOrEqualTo: queryLower).where('displayNameLower', isLessThanOrEqualTo: '$queryLower\uf8ff').limit(10).get();

      final results = await Future.wait([usernameQuery, displayNameQuery, postTagQuery, postAuthorQuery]);

      final userSnapshots = [results[0] as QuerySnapshot, results[1] as QuerySnapshot];
      final Map<String, Map<String, dynamic>> userResultsMap = {};
      for (final snapshot in userSnapshots) {
        for (final doc in snapshot.docs) {
          if (doc.id == currentUserId) continue;
          final userData = doc.data() as Map<String, dynamic>;
          final targetUserFriendUids = List<String>.from(userData['friendUids'] ?? []);
          final mutualCount = targetUserFriendUids.where((uid) => currentUserFriendUids.contains(uid)).length;

          userResultsMap[doc.id] = {...userData, 'uid': doc.id, 'mutual': mutualCount};
        }
      }

      final postSnapshots = [results[2] as QuerySnapshot, results[3] as QuerySnapshot];
      final Map<String, Map<String, dynamic>> postResultsMap = {};

      // Kết hợp kết quả từ Tag và Tên tác giả, lọc trùng lặp
      for (final snapshot in postSnapshots) {
        for (final doc in snapshot.docs) {
          final postData = doc.data() as Map<String, dynamic>;
          postResultsMap[doc.id] = {...postData, 'id': doc.id};
        }
      }
      final finalPostResults = postResultsMap.values.toList();

      // Sắp xếp bài viết theo thời gian (mới nhất trước)
      finalPostResults.sort((a, b) {
        final aTime = (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
        final bTime = (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _userSearchResults = userResultsMap.values.toList();
          _postSearchResults = finalPostResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Lỗi tìm kiếm: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã xảy ra lỗi khi tìm kiếm. Vui lòng thử lại.'),
          backgroundColor: coralRed,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.black,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          textInputAction: TextInputAction.search,
          onSubmitted: (query) {
            _debounce?.cancel();
            _performSearch(query.trim());
          },
          decoration: InputDecoration(
            hintText: 'Tìm kiếm người dùng, tags...',
            hintStyle: TextStyle(color: sonicSilver.withOpacity(0.8)),
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, color: sonicSilver.withOpacity(0.8)),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear, color: sonicSilver),
              onPressed: () => _searchController.clear(),
            )
                : null,
          ),
        ),
      ),
      body: _buildBodyContent(),
    );
  }

  // --- SỬ DỤNG CustomScrollView và SliverGrid ---
  Widget _buildBodyContent() {
    if (_searchQuery.isEmpty) {
      return _buildRecentSearches();
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: topazColor));
    }
    if (_userSearchResults.isEmpty && _postSearchResults.isEmpty) {
      return Center(child: Text('Không có kết quả cho "$_searchQuery"', style: const TextStyle(color: sonicSilver)));
    }

    return CustomScrollView(
      slivers: [
        if (_userSearchResults.isNotEmpty)
          SliverList(
            delegate: SliverChildListDelegate([
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Tài khoản', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ..._userSearchResults.map((user) => _UserSearchResultTile(
                key: ValueKey(user['uid']),
                userData: user,
                currentUser: _currentUser,
                onToggleFollow: _toggleFollow,
                onToggleFriend: _toggleFriendRequest,
                onNavigateToProfile: () => _navigateToProfile(user),
              )),
              const SizedBox(height: 24), // Khoảng cách sau danh sách người dùng
            ]),
          ),

        if (_postSearchResults.isNotEmpty)
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('Bài viết', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ]),
          ),

        if (_postSearchResults.isNotEmpty)
          SliverPadding( // Thêm padding xung quanh Grid
            padding: const EdgeInsets.symmetric(horizontal: 0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 1.0,
                mainAxisSpacing: 1.0,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final post = _postSearchResults[index];
                  return _PostGridItem( // <-- SỬ DỤNG WIDGET MỚI
                    postData: post,
                    onTap: _navigateToPostDetail,
                  );
                },
                childCount: _postSearchResults.length,
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 50)), // Padding dưới cùng
      ],
    );
  }

  Widget _buildRecentSearches() {
    if (_recentSearches.isEmpty) {
      return const Center(child: Text('Nhập để tìm kiếm người dùng hoặc bài viết.', style: TextStyle(color: sonicSilver)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Tìm kiếm gần đây', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _recentSearches.length,
            itemBuilder: (context, index) {
              final term = _recentSearches[index];
              return ListTile(
                leading: const Icon(Icons.history, color: sonicSilver),
                title: Text(term, style: const TextStyle(color: Colors.white)),
                trailing: IconButton(
                  icon: const Icon(Icons.clear, color: sonicSilver, size: 20),
                  onPressed: () {
                    setState(() {
                      _recentSearches.removeAt(index);
                      // _saveRecentSearches(); // TODO
                    });
                  },
                ),
                onTap: () {
                  _searchController.text = term;
                  // Di chuyển con trỏ đến cuối
                  _searchController.selection = TextSelection.fromPosition(TextPosition(offset: term.length));
                  // Không cần gọi _performSearch ở đây vì listener đã làm việc đó
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UserSearchResultTile extends StatelessWidget {
  final Map<String, dynamic> userData;
  final User? currentUser;
  final Function(Map<String, dynamic>) onToggleFollow;
  final Function(Map<String, dynamic>) onToggleFriend;
  final VoidCallback onNavigateToProfile;

  const _UserSearchResultTile({
    super.key,
    required this.userData,
    required this.currentUser,
    required this.onToggleFollow,
    required this.onToggleFriend,
    required this.onNavigateToProfile,
  });

  @override
  Widget build(BuildContext context) {
    final String name = userData['displayName'] as String? ?? 'Người dùng';
    final String username = userData['username'] as String? ?? '';
    final String userId = userData['uid'] as String? ?? '';
    final String? avatarUrl = userData['photoURL'] as String?;
    final int mutual = userData['mutual'] as int? ?? 0;
    final ImageProvider? avatarImage = (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null;

    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return ListTile(
            leading: CircleAvatar(radius: 25, backgroundColor: darkSurface),
            title: Text(name, style: const TextStyle(color: Colors.white)),
            subtitle: Text('@$username', style: TextStyle(color: sonicSilver)),
          );
        }

        final myData = snapshot.data!.data() as Map<String, dynamic>;
        final isFriend = (myData['friendUids'] as List<dynamic>? ?? []).contains(userId);
        final isPending = (myData['outgoingRequests'] as List<dynamic>? ?? []).contains(userId);
        final isFollowing = (myData['followingUids'] as List<dynamic>? ?? []).contains(userId);

        final updatedUserData = {...userData, 'isFriend': isFriend, 'isPending': isPending, 'isFollowing': isFollowing};

        // --- Logic nút Kết bạn ---
        final friendButtonText = isFriend ? 'Bạn bè' : (isPending ? 'Hủy lời mời' : 'Kết bạn');
        final friendButtonColor = isFriend ? darkSurface : (isPending ? darkSurface : topazColor);
        final friendTextColor = isFriend ? sonicSilver : (isPending ? sonicSilver : Colors.black);
        final friendButtonSide = isFriend || isPending ? BorderSide(color: sonicSilver) : BorderSide.none;

        // --- Logic nút Theo dõi ---
        final followButtonText = isFollowing ? 'Bỏ theo dõi' : 'Theo dõi';
        final followButtonColor = isFollowing ? darkSurface : Colors.blueAccent;
        final followTextColor = Colors.white;
        final followButtonSide = isFollowing ? BorderSide(color: sonicSilver) : BorderSide.none;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          leading: CircleAvatar(
            radius: 25,
            backgroundImage: avatarImage,
            backgroundColor: darkSurface,
            child: avatarImage == null ? const Icon(Icons.person, color: sonicSilver, size: 25) : null,
          ),
          title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          subtitle: Text(
            mutual > 0 ? '$mutual bạn chung' : (username.isNotEmpty ? '@$username' : ''),
            style: TextStyle(color: sonicSilver),
          ),
          trailing: Wrap(
            spacing: 8,
            children: [
              // --- Nút Theo dõi ---
              if (!isFriend)
                SizedBox(
                  width: 90,
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () => onToggleFollow(updatedUserData),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: followButtonColor,
                      foregroundColor: followTextColor,
                      side: followButtonSide,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(followButtonText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              // --- Nút Kết bạn ---
              SizedBox(
                width: 90,
                height: 32,
                child: ElevatedButton(
                  onPressed: isFriend ? null : () => onToggleFriend(updatedUserData),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: friendButtonColor,
                    foregroundColor: friendTextColor,
                    side: friendButtonSide,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: EdgeInsets.zero,
                    disabledBackgroundColor: darkSurface,
                  ),
                  child: Text(friendButtonText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          onTap: onNavigateToProfile,
        );
      },
    );
  }
}
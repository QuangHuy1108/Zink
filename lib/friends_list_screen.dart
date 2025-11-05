// lib/friends_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';
import 'message_screen.dart';

// Constants
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C);

// =======================================================
// WIDGET CUSTOM: SLIDABLE LIST ITEM
// =======================================================
class SlidableListItem extends StatefulWidget {
  final Key itemKey;
  final double actionsWidth;
  final List<Widget> actions;
  final Widget child;
  final Function(Key) onOpen;
  final VoidCallback onCloseRequest;
  final VoidCallback onChildTap;

  const SlidableListItem({
    required Key key, // Giữ lại key này
    required this.itemKey,
    required this.actionsWidth,
    required this.actions,
    required this.child,
    required this.onOpen,
    required this.onCloseRequest,
    required this.onChildTap,
  }) : super(key: key); // Truyền key vào super constructor

  @override
  State<SlidableListItem> createState() => _SlidableListItemState();
}

class _SlidableListItemState extends State<SlidableListItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      // SỬA LỖI 1: Thêm duration
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(-widget.actionsWidth / 80, 0.0),
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void closeSlidable() {
    if (_isOpen) {
      _controller.reverse();
      _isOpen = false;
    }
  }

  void _openSlidable() {
    if (!_isOpen) {
      _controller.forward();
      _isOpen = true;
      widget.onOpen(widget.itemKey);
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isOpen) {
      if (details.delta.dx > 1) {
        widget.onCloseRequest();
      }
      return;
    }
    if (details.delta.dx < -2) {
      _openSlidable();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isOpen ? widget.onCloseRequest : widget.onChildTap,
      onHorizontalDragUpdate: _handleDragUpdate,
      child: Stack(
        children: [
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: widget.actions,
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: _animation.value * widget.actionsWidth,
                child: child,
              );
            },
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

// =======================================================
// MÀN HÌNH CHÍNH: FRIENDS LIST SCREEN
// =======================================================
class FriendsListScreen extends StatefulWidget {
  final VoidCallback onNavigateToHome;
  const FriendsListScreen({required this.onNavigateToHome, super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  // Trạng thái cho cả Kết bạn và Theo dõi
  Map<String, String> _requestStatus = {};
  Map<String, bool> _followStatus = {};
  bool _isProcessingRequest = false;

  bool _isSearchFieldVisible = true;
  static const double _searchBarHeight = 56.0;
  static const double _fixedHeaderHeight = 65.0;
  Key? _openItemKey;
  final Map<Key, GlobalKey<_SlidableListItemState>> _slidableKeys = {};

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    final query = _searchController.text.trim();
    if (_searchQuery != query) {
      setState(() {
        _searchQuery = query;
        _isSearching = query.isNotEmpty;
        if (!_isSearching) {
          _searchResults = [];
          _requestStatus = {};
          _followStatus = {}; // Reset cả follow status
        } else {
          _performUserSearch(query);
        }
      });
    }
  }

  void _performUserSearch(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }

    final queryLower = query.toLowerCase();
    final currentUserUid = _currentUser?.uid;

    try {
      final usernameQuery = _firestore.collection('users')
          .where('usernameLower', isGreaterThanOrEqualTo: queryLower)
          .where('usernameLower', isLessThanOrEqualTo: '$queryLower\uf8ff')
          .limit(15);

      final nameQuery = _firestore.collection('users')
          .where('displayNameLower', isGreaterThanOrEqualTo: queryLower)
          .where('displayNameLower', isLessThanOrEqualTo: '$queryLower\uf8ff')
          .limit(15);

      final List<QuerySnapshot> snapshots = await Future.wait([usernameQuery.get(), nameQuery.get()]);

      final Map<String, Map<String, dynamic>> resultsMap = {};
      final List<String> resultUids = [];

      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          if (doc.id == currentUserUid) continue;

          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          data['uid'] = doc.id;
          data['mutual'] = data['mutual'] ?? 0;
          if (!resultsMap.containsKey(doc.id)) {
            resultsMap[doc.id] = data;
            resultUids.add(doc.id);
          }
        }
      }

      final finalResults = resultsMap.values.toList();
      finalResults.sort((a, b) => (a['displayName'] as String? ?? '').compareTo(b['displayName'] as String? ?? ''));

      if (mounted) {
        setState(() => _searchResults = finalResults);
        await _updateSearchResultRequestStatus(resultUids);
      }

    } catch (e) {
      print("Error searching users: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi tìm kiếm người dùng.'), backgroundColor: coralRed));
    }
  }

  Future<void> _updateSearchResultRequestStatus(List<String> targetUserIds) async {
    final currentUserUid = _currentUser?.uid;
    if (currentUserUid == null || targetUserIds.isEmpty) return;

    final myDoc = await _firestore.collection('users').doc(currentUserUid).get();
    if (!myDoc.exists) return;

    final myData = myDoc.data() ?? {};
    final List<String> myOutgoingRequests = List<String>.from(myData['outgoingRequests'] ?? []);
    final List<String> myFriendUids = List<String>.from(myData['friendUids'] ?? []);
    final List<String> myFollowingUids = List<String>.from(myData['following'] ?? []);

    Map<String, String> newRequestStatus = {};
    Map<String, bool> newFollowStatus = {};

    for (var uid in targetUserIds) {
      if (myFriendUids.contains(uid)) {
        newRequestStatus[uid] = 'friend';
      } else if (myOutgoingRequests.contains(uid)) {
        newRequestStatus[uid] = 'pending';
      } else {
        newRequestStatus[uid] = 'none';
      }
      newFollowStatus[uid] = myFollowingUids.contains(uid);
    }

    if (mounted) {
      setState(() {
        _requestStatus = newRequestStatus;
        _followStatus = newFollowStatus;
      });
    }
  }

  void _toggleFriendRequest(Map<String, dynamic> user) async {
    final currentUser = _currentUser;
    final targetUserId = user['uid'] as String?;
    final targetUserName = user['displayName'] as String? ?? 'Người dùng';

    if (currentUser == null || targetUserId == null || _isProcessingRequest) return;
    if (mounted) setState(() => _isProcessingRequest = true);

    final isPending = _requestStatus[targetUserId] == 'pending';
    final userRef = _firestore.collection('users').doc(currentUser.uid);
    final targetNotificationRef = _firestore.collection('users').doc(targetUserId).collection('notifications');

    try {
      if (isPending) {
        await userRef.update({'outgoingRequests': FieldValue.arrayRemove([targetUserId])});
        final notificationQuery = await targetNotificationRef
            .where('type', isEqualTo: 'friend_request')
            .where('senderId', isEqualTo: currentUser.uid)
            .limit(1)
            .get();
        for (var doc in notificationQuery.docs) {
          await doc.reference.delete();
        }
        if (mounted) {
          setState(() { _requestStatus[targetUserId] = 'none'; });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã hủy lời mời kết bạn tới $targetUserName.'), backgroundColor: sonicSilver));
        }
      } else {
        DocumentSnapshot myUserDoc = await userRef.get();
        String senderName = 'Người dùng Zink';
        String? senderAvatarUrl;

        if (myUserDoc.exists) {
          final myData = myUserDoc.data() as Map<String, dynamic>;
          senderName = myData['displayName'] ?? 'Người dùng Zink';
          senderAvatarUrl = myData['photoURL'];
        }

        await userRef.update({'outgoingRequests': FieldValue.arrayUnion([targetUserId])});
        await targetNotificationRef.add({
          'type': 'friend_request',
          'senderId': currentUser.uid,
          'senderName': senderName,
          'senderAvatarUrl': senderAvatarUrl,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'actionTaken': false,
        });

        if (mounted) {
          setState(() { _requestStatus[targetUserId] = 'pending'; });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã gửi lời mời kết bạn tới $targetUserName.'), backgroundColor: topazColor));
        }
      }
    } catch (e) {
      print("Lỗi thao tác kết bạn: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi: Thao tác không thành công.'), backgroundColor: coralRed));
    } finally {
      if (mounted) setState(() => _isProcessingRequest = false);
    }
  }

  void _toggleFollow(Map<String, dynamic> user) async {
    final currentUser = _currentUser;
    final targetUserId = user['uid'] as String?;

    if (currentUser == null || targetUserId == null || _isProcessingRequest) return;
    if (mounted) setState(() => _isProcessingRequest = true);

    final isFollowing = _followStatus[targetUserId] ?? false;
    final myDocRef = _firestore.collection('users').doc(currentUser.uid);
    final theirDocRef = _firestore.collection('users').doc(targetUserId);
    final WriteBatch batch = _firestore.batch();

    try {
      if (isFollowing) {
        batch.update(myDocRef, {'following': FieldValue.arrayRemove([targetUserId])});
        batch.update(theirDocRef, {'followers': FieldValue.arrayRemove([currentUser.uid])});
      } else {
        DocumentSnapshot myUserDoc = await myDocRef.get();
        String senderName = 'Một người dùng';
        String? senderAvatarUrl;
        if (myUserDoc.exists) {
          final myData = myUserDoc.data() as Map<String, dynamic>;
          senderName = myData['displayName'] ?? 'Một người dùng';
          senderAvatarUrl = myData['photoURL'];
        }

        batch.update(myDocRef, {'following': FieldValue.arrayUnion([targetUserId])});
        batch.update(theirDocRef, {'followers': FieldValue.arrayUnion([currentUser.uid])});

        final notificationRef = theirDocRef.collection('notifications').doc();
        batch.set(notificationRef, {
          'type': 'follow',
          'senderId': currentUser.uid,
          'senderName': senderName,
          'senderAvatarUrl': senderAvatarUrl ?? '',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }
      await batch.commit();
      if (mounted) {
        setState(() {
          _followStatus[targetUserId] = !isFollowing;
        });
      }
    } catch(e) {
      print("Error toggling follow: $e");
    } finally {
      if (mounted) {
        setState(() => _isProcessingRequest = false);
      }
    }
  }

  void _navigateToProfileScreen(Map<String, dynamic> user) {
    final targetUid = user['uid'] as String?;
    if (targetUid == null) return;
    _closeOpenItem();
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => ProfileScreen(
        targetUserId: targetUid,
        onNavigateToHome: () => Navigator.pop(context),
        onLogout: () {}
    )));
  }

  void _navigateToMessageScreen(String targetUserId, String targetUserName) {
    _closeOpenItem();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => MessageScreen(
        targetUserId: targetUserId,
        targetUserName: targetUserName,
      ),
    ));
  }

  void _unfriend(String friendId, String friendName) async {
    if (_currentUser == null) return;
    final currentUserId = _currentUser!.uid;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: darkSurface,
          title: const Text('Hủy kết bạn', style: TextStyle(color: Colors.white)),
          content: Text('Bạn có chắc chắn muốn hủy kết bạn với $friendName không?', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              child: const Text('Không', style: TextStyle(color: sonicSilver)),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('Hủy kết bạn', style: TextStyle(color: coralRed)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final batch = _firestore.batch();
      final currentUserRef = _firestore.collection('users').doc(currentUserId);
      final friendUserRef = _firestore.collection('users').doc(friendId);

      try {
        batch.update(currentUserRef, {'friendUids': FieldValue.arrayRemove([friendId])});
        batch.update(friendUserRef, {'friendUids': FieldValue.arrayRemove([currentUserId])});

        await batch.commit();
        _closeOpenItem();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã hủy kết bạn với $friendName.'), backgroundColor: sonicSilver));

      } catch (e) {
        print("Lỗi hủy kết bạn: $e");
        _closeOpenItem();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi: Không thể hủy kết bạn.'), backgroundColor: coralRed));
      }
    } else {
      _closeOpenItem();
    }
  }

  void _handleItemOpen(Key key) {
    if (_openItemKey != null && _openItemKey != key) _closeOpenItem();
    _openItemKey = key;
  }

  void _closeOpenItem() {
    if (_openItemKey != null) {
      _slidableKeys[_openItemKey]?.currentState?.closeSlidable();
      _openItemKey = null;
    }
  }

  Widget _buildSearchField() {
    return Container(
      height: _searchBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.black,
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm bạn bè hoặc người dùng mới...',
          hintStyle: TextStyle(color: sonicSilver.withOpacity(0.7)),
          filled: true,
          fillColor: darkSurface,
          prefixIcon: const Icon(Icons.search, color: sonicSilver),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, color: sonicSilver, size: 18), onPressed: _searchController.clear, splashRadius: 18,) : null,
        ),
      ),
    );
  }

  Widget _buildFixedHeader(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 10, left: 10, right: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: widget.onNavigateToHome,
            splashRadius: 24,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Bạn bè',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedSearchBar() {
    final double translateY = _isSearchFieldVisible ? 0.0 : -_searchBarHeight;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      transform: Matrix4.translationValues(0.0, translateY, 0.0),
      color: Colors.black,
      child: ClipRect(
          child: Align(
              heightFactor: _isSearchFieldVisible ? 1.0 : 0.001,
              child: _buildSearchField()
          )
      ),
    );
  }

  Widget _buildSlidableAction({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 80,
        color: darkSurface,
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }

  Widget _buildFriendItem(Map<String, dynamic> friendData) {
    final String friendId = friendData['uid'] as String? ?? '';
    final String friendName = friendData['displayName'] as String? ?? 'Bạn bè';
    final String friendUsername = friendData['username'] as String? ?? '';
    final String? avatarUrl = friendData['photoURL'] as String?;
    final itemKey = ValueKey(friendId);
    _slidableKeys.putIfAbsent(itemKey, () => GlobalKey<_SlidableListItemState>());

    final ImageProvider? avatarImage = (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
        ? NetworkImage(avatarUrl) : null;

    final actions = <Widget>[
      _buildSlidableAction(
        icon: Icons.message_outlined,
        color: topazColor,
        onTap: () => _navigateToMessageScreen(friendId, friendName),
      ),
      _buildSlidableAction(
        icon: Icons.person_remove_alt_1_outlined,
        color: coralRed,
        onTap: () => _unfriend(friendId, friendName),
      ),
    ];

    final listTileChild = Container(
      color: Colors.black,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        leading: CircleAvatar(
          radius: 25, backgroundImage: avatarImage, backgroundColor: darkSurface,
          child: avatarImage == null ? const Icon(Icons.person, color: sonicSilver, size: 25) : null,
        ),
        title: Text( friendName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600) ),
        subtitle: Text( '@$friendUsername', style: TextStyle(color: sonicSilver) ),
        trailing: _openItemKey == itemKey ? null : const Icon(Icons.arrow_back_ios, color: sonicSilver, size: 16),
      ),
    );

    return SlidableListItem(
      key: _slidableKeys[itemKey]!,
      itemKey: itemKey,
      actionsWidth: 160.0,
      actions: actions,
      onOpen: _handleItemOpen,
      onCloseRequest: _closeOpenItem,
      onChildTap: () => _navigateToProfileScreen(friendData),
      child: listTileChild,
    );
  }

  Widget _buildSearchResultItem(Map<String, dynamic> userData) {
    final String userId = userData['uid'] as String? ?? '';
    final String name = userData['displayName'] as String? ?? 'Người dùng';
    final String username = userData['username'] as String? ?? '';
    final String? avatarUrl = userData['photoURL'] as String?;
    final int mutual = userData['mutual'] as int? ?? 0;

    final ImageProvider? avatarImage = (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
        ? NetworkImage(avatarUrl)
        : null;

    return StreamBuilder<DocumentSnapshot>(
      // LUÔN LẮNG NGHE TÀI LIỆU CỦA CHÍNH BẠN
      stream: _firestore.collection('users').doc(_currentUser!.uid).snapshots(),
      builder: (context, myDataSnapshot) {
        if (!myDataSnapshot.hasData) {
          // Trạng thái chờ, có thể hiển thị một placeholder đơn giản
          return ListTile(
            leading: CircleAvatar(radius: 25, backgroundColor: darkSurface),
            title: Text(name, style: const TextStyle(color: Colors.white)),
            subtitle: Text('@$username', style: TextStyle(color: sonicSilver)),
          );
        }

        final myData = myDataSnapshot.data!.data() as Map<String, dynamic>;

        // Lấy trạng thái mới nhất từ stream
        final isFriend = (myData['friendUids'] as List<dynamic>? ?? []).contains(userId);
        final isPending = (myData['outgoingRequests'] as List<dynamic>? ?? []).contains(userId);
        final isFollowing = (myData['following'] as List<dynamic>? ?? []).contains(userId);

        // --- Logic nút Kết bạn ---
        final friendButtonText = isFriend ? 'Bạn bè' : (isPending ? 'Hủy lời mời' : 'Kết bạn');
        final friendButtonColor = isFriend ? darkSurface : (isPending ? darkSurface : topazColor);
        final friendTextColor = isFriend ? sonicSilver : (isPending ? sonicSilver : Colors.black);
        final friendButtonSide = isFriend || isPending ? BorderSide(color: sonicSilver) : BorderSide.none;

        // --- Logic nút Theo dõi ---
        final followButtonText = isFollowing ? 'Hủy theo dõi' : 'Theo dõi';
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
                    onPressed: () => _toggleFollow(userData), // Cần đảm bảo hàm này tồn tại
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
                  onPressed: isFriend ? null : () => _toggleFriendRequest(userData), // Cần đảm bảo hàm này tồn tại
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
          onTap: () => _navigateToProfileScreen(userData),
        );
      },
    );
  }

  Widget _buildFriendsList() {
    final currentUserId = _currentUser?.uid;
    if (currentUserId == null) return const Center(child: Text('Vui lòng đăng nhập', style: TextStyle(color: sonicSilver)));

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(currentUserId).snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: topazColor));
        if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) return const Center(child: Text('Lỗi tải danh sách bạn bè.', style: TextStyle(color: coralRed)));

        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        final List<String> friendUids = List<String>.from(userData?['friendUids'] ?? []);

        if (friendUids.isEmpty) {
          return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text("Bạn chưa có người bạn nào.", style: TextStyle(color: sonicSilver, fontSize: 16))));
        }

        final queryUids = friendUids.length > 30 ? friendUids.sublist(0, 30) : friendUids;
        if (friendUids.length > 30) print("Warning: Friend list query limited to 30.");

        return StreamBuilder<QuerySnapshot>(
          stream: queryUids.isEmpty ? Stream.empty() : _firestore.collection('users').where(FieldPath.documentId, whereIn: queryUids).snapshots(),
          builder: (context, friendsSnapshot) {
            if (friendsSnapshot.connectionState == ConnectionState.waiting && !(friendsSnapshot.hasData || friendsSnapshot.hasError)) return const Center(child: Padding(padding: EdgeInsets.all(30.0), child: CircularProgressIndicator(color: topazColor, strokeWidth: 2)));
            if (friendsSnapshot.hasError) return const Center(child: Text('Lỗi tải thông tin bạn bè.', style: TextStyle(color: coralRed)));

            final friendDocs = friendsSnapshot.data?.docs ?? [];
            if (friendDocs.isEmpty && queryUids.isNotEmpty) return const Center(child: Text('Không tìm thấy thông tin bạn bè.', style: TextStyle(color: sonicSilver)));

            friendDocs.sort((a, b) {
              final nameA = (a.data() as Map<String, dynamic>)['displayName'] as String? ?? '';
              final nameB = (b.data() as Map<String, dynamic>)['displayName'] as String? ?? '';
              return nameA.compareTo(nameB);
            });

            final double dynamicPaddingTop = MediaQuery.of(context).padding.top + _fixedHeaderHeight + (_isSearchFieldVisible ? _searchBarHeight : 0);
            return ListView.separated(
              key: const ValueKey('friendsList'),
              padding: EdgeInsets.only(top: dynamicPaddingTop, bottom: 30),
              itemCount: friendDocs.length,
              itemBuilder: (context, index) {
                final friendDoc = friendDocs[index];
                final friendData = friendDoc.data() as Map<String, dynamic>;
                friendData['uid'] = friendDoc.id;
                return _buildFriendItem(friendData);
              },
              separatorBuilder: (context, index) => const Divider( color: darkSurface, height: 1, thickness: 1, indent: 80, ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double searchListPaddingTop = MediaQuery.of(context).padding.top + _fixedHeaderHeight + (_isSearchFieldVisible ? _searchBarHeight : 0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _closeOpenItem,
        child: Stack(
          children: [
            NotificationListener<UserScrollNotification>(
              onNotification: (notification) {
                if (!_isSearching) {
                  if (notification.metrics.axis == Axis.vertical) {
                    if (notification.direction == ScrollDirection.forward) {
                      if (!_isSearchFieldVisible) {
                        setState(() { _isSearchFieldVisible = true; });
                      }
                    }
                    else if (notification.direction == ScrollDirection.reverse) {
                      if (_isSearchFieldVisible && notification.metrics.pixels > 50) {
                        setState(() { _isSearchFieldVisible = false; });
                      }
                    }
                  }
                }
                return false;
              },
              child: _isSearching
                  ? (_searchResults.isEmpty && _searchQuery.isNotEmpty
                  ? Center(child: Padding(
                  padding: EdgeInsets.only(top: searchListPaddingTop),
                  child: Text('Không tìm thấy kết quả nào cho \"$_searchQuery\"', style: TextStyle(color: sonicSilver))
              ))
                  : ListView.separated(
                key: const ValueKey('searchResults'),
                padding: EdgeInsets.only(top: searchListPaddingTop, bottom: 30),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) => _buildSearchResultItem(_searchResults[index]),
                separatorBuilder: (context, index) => const Divider(color: darkSurface, height: 1, thickness: 1, indent: 80),
              )
              )
                  : _buildFriendsList(),
            ),
            Positioned( top: 0, left: 0, right: 0, child: _buildFixedHeader(context) ),
            Positioned(
                top: MediaQuery.of(context).padding.top + _fixedHeaderHeight,
                left: 0, right: 0,
                child: _buildAnimatedSearchBar()
            ),
          ],
        ),
      ),
    );
  }
}
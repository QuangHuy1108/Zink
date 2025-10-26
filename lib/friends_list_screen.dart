// lib/friends_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_friend_screen.dart' hide ProfileScreen;
import 'profile_screen.dart';
import 'message_screen.dart'; // <-- Đã thêm: Import MessageScreen

// Constants (Giữ nguyên)
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
    required Key key,
    required this.itemKey,
    required this.actionsWidth,
    required this.actions,
    required this.child,
    required this.onOpen,
    required this.onCloseRequest,
    required this.onChildTap,
  }) : super(key: key);

  @override
  State<SlidableListItem> createState() => _SlidableListItemState();
}

class _SlidableListItemState extends State<SlidableListItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;
  double _dragAmount = 0.0;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(-widget.actionsWidth / 80, 0.0), // Trượt sang trái
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
          // Actions (nằm dưới)
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: widget.actions,
            ),
          ),
          // Child (nằm trên, có thể trượt)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: _animation.value * widget.actionsWidth, // Áp dụng actionsWidth
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

  // Các biến thiếu
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

  // Listener for search text changes
  void _onSearchTextChanged() {
    final query = _searchController.text.trim();
    if (_searchQuery != query) {
      setState(() {
        _searchQuery = query;
        _isSearching = query.isNotEmpty;
        if (!_isSearching) {
          _searchResults = [];
        } else {
          _performUserSearch(query);
        }
      });
    }
  }

  // Perform user search based on query
  void _performUserSearch(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    if (mounted) setState(() => _searchResults = []);

    final queryLower = query.toLowerCase();
    final currentUserUid = _currentUser?.uid;

    try {
      final usernameQuery = _firestore.collection('users')
          .where('usernameLower', isGreaterThanOrEqualTo: queryLower)
          .where('usernameLower', isLessThanOrEqualTo: '$queryLower\uf8ff')
          .limit(15);

      final nameQuery = _firestore.collection('users')
          .where('nameLower', isGreaterThanOrEqualTo: queryLower)
          .where('nameLower', isLessThanOrEqualTo: '$queryLower\uf8ff')
          .limit(15);

      final List<QuerySnapshot> snapshots = await Future.wait([usernameQuery.get(), nameQuery.get()]);

      final Map<String, Map<String, dynamic>> resultsMap = {};

      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          if (doc.id == currentUserUid) continue;

          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          data['uid'] = doc.id;
          data['isFriend'] = false;
          data['mutual'] = data['mutual'] ?? 0;
          resultsMap[doc.id] = data;
        }
      }

      final finalResults = resultsMap.values.toList();
      finalResults.sort((a, b) => (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));

      if (mounted) setState(() => _searchResults = finalResults);

    } catch (e) {
      print("Error searching users: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi tìm kiếm người dùng.'), backgroundColor: coralRed));
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  // --- Logic Điều hướng ---
  void _navigateToAddFriendScreen() {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AddFriendScreen()));
  }

  void _navigateToProfileScreen(Map<String, dynamic> user) {
    final targetUid = user['uid'] as String?;
    if (targetUid == null) return;
    _closeOpenItem();
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => ProfileScreen(
        targetUserId: targetUid,
        onNavigateToHome: () => Navigator.pop(context),
        onLogout: () {}
    )
    ));
  }

  // Hàm mới: Điều hướng đến MessageScreen (Đã sửa lỗi)
  void _navigateToMessageScreen(String targetUserId, String targetUserName) {
    _closeOpenItem();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => MessageScreen(
        targetUserId: targetUserId,
        targetUserName: targetUserName,
      ),
    ));
  }

  // --- Logic Hủy kết bạn (Đã hoàn thiện) ---
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
        // 1. Xóa friendId khỏi friendUids của mình
        batch.update(currentUserRef, {'friendUids': FieldValue.arrayRemove([friendId])});

        // 2. Xóa currentUserId khỏi friendUids của họ
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

  // --- Logic cho Slidable Item ---
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

  // --- Các hàm build UI ---
  Widget _buildSearchField() {
    return Container(
      height: _searchBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.black,
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm bạn bè...',
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
              'Danh sách Bạn bè',
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

  // Widget Friend Item (Cập nhật Slidable Action để gọi _navigateToMessageScreen)
  Widget _buildFriendItem(Map<String, dynamic> friendData) {
    final String friendId = friendData['uid'] as String? ?? '';
    final String friendName = friendData['name'] as String? ?? 'Bạn bè';
    final String friendUsername = friendData['username'] as String? ?? '';
    final String? avatarUrl = friendData['avatarUrl'] as String?;
    final itemKey = ValueKey(friendId);
    _slidableKeys.putIfAbsent(itemKey, () => GlobalKey<_SlidableListItemState>());

    final ImageProvider? avatarImage = (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
        ? NetworkImage(avatarUrl) : null;

    final actions = <Widget>[
      _buildSlidableAction(
        icon: Icons.message_outlined,
        color: topazColor,
        onTap: () => _navigateToMessageScreen(friendId, friendName), // <-- Đã sửa
      ),
      _buildSlidableAction(
        icon: Icons.person_remove_alt_1_outlined,
        color: coralRed,
        onTap: () => _unfriend(friendId, friendName),
      ),
    ];

    return SlidableListItem(
      key: itemKey, itemKey: itemKey, actionsWidth: 160.0, actions: actions,
      onOpen: _handleItemOpen, onCloseRequest: _closeOpenItem,
      onChildTap: () => _navigateToProfileScreen(friendData),
      child: Container(
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
      ),
    );
  }


  // Widget Search Result Item (Giữ nguyên)
  Widget _buildSearchResultItem(Map<String, dynamic> userData) {
    final String userId = userData['uid'] as String? ?? '';
    final String name = userData['name'] as String? ?? 'Người dùng';
    final String username = userData['username'] as String? ?? '';
    final String? avatarUrl = userData['avatarUrl'] as String?;
    final int mutual = userData['mutual'] as int? ?? 0;

    final ImageProvider? avatarImage = (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
        ? NetworkImage(avatarUrl) : null;

    return Container(
      color: Colors.black,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        leading: CircleAvatar(
          radius: 25, backgroundImage: avatarImage, backgroundColor: darkSurface,
          child: avatarImage == null ? const Icon(Icons.person, color: sonicSilver, size: 25) : null,
        ),
        title: Text( name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600) ),
        subtitle: Text( '$mutual bạn chung', style: TextStyle(color: sonicSilver) ),
        trailing: ElevatedButton(
          onPressed: () { /* TODO: Send friend request logic */ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã gửi lời mời tới $name'))); },
          style: ElevatedButton.styleFrom( backgroundColor: topazColor, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), minimumSize: const Size(0, 30), ),
          child: const Text('Kết bạn', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        onTap: () => _navigateToProfileScreen(userData),
      ),
    );
  }


  // Widget Danh sách Bạn bè
  Widget _buildFriendsList() {
    final currentUserId = _currentUser?.uid;
    if (_currentUser == null) return const Center(child: Text('Vui lòng đăng nhập', style: TextStyle(color: sonicSilver)));
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(currentUserId).snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: topazColor));
        if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) return const Center(child: Text('Lỗi tải danh sách bạn bè.', style: TextStyle(color: coralRed)));

        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        final List<String> friendUids = List<String>.from(userData?['friendUids'] ?? []);

        if (friendUids.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off_outlined, color: sonicSilver, size: 60),
                  const SizedBox(height: 16),
                  Text('Bạn chưa có bạn bè nào. Hãy tìm kiếm và kết nối!', style: TextStyle(color: sonicSilver, fontSize: 16), textAlign: TextAlign.center,),
                ],
              ),
            ),
          );
        }

        final queryUids = friendUids.length > 10 ? friendUids.sublist(0, 10) : friendUids;
        if (friendUids.length > 10) print("Warning: Friend list query limited to 10.");

        return StreamBuilder<QuerySnapshot>(
          stream: queryUids.isEmpty ? Stream.empty() : _firestore.collection('users').where(FieldPath.documentId, whereIn: queryUids).snapshots(),
          builder: (context, friendsSnapshot) {
            if (friendsSnapshot.connectionState == ConnectionState.waiting && !(friendsSnapshot.hasData || friendsSnapshot.hasError)) return const Center(child: Padding(padding: EdgeInsets.all(30.0), child: CircularProgressIndicator(color: topazColor, strokeWidth: 2)));
            if (friendsSnapshot.hasError) return const Center(child: Text('Lỗi tải thông tin bạn bè.', style: TextStyle(color: coralRed)));

            final friendDocs = friendsSnapshot.data?.docs ?? [];
            if (friendDocs.isEmpty) return const Center(child: Text('Không tìm thấy thông tin bạn bè.', style: TextStyle(color: sonicSilver)));

            // Sắp xếp theo tên (tạm thời)
            friendDocs.sort((a, b) {
              final nameA = (a.data() as Map<String, dynamic>)['name'] as String? ?? '';
              final nameB = (b.data() as Map<String, dynamic>)['name'] as String? ?? '';
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

  // --- BUILD METHOD CHÍNH (Đã sửa lỗi thiếu build) ---
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
                // Logic ẩn/hiện search bar
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
                return false;
              },
              child: _isSearching
                  ? (_searchResults.isEmpty
                  ? Center(child: Text('Không tìm thấy kết quả nào cho "$_searchQuery"', style: TextStyle(color: sonicSilver)))
                  : ListView.separated( // Search results list
                key: const ValueKey('searchResults'),
                padding: EdgeInsets.only(top: searchListPaddingTop, bottom: 30),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) => _buildSearchResultItem(_searchResults[index]),
                separatorBuilder: (context, index) => const Divider(color: darkSurface, height: 1, thickness: 1, indent: 80),
              )
              )
                  : _buildFriendsList(), // Friend list
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
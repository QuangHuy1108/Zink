// lib/add_friend_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- IMPORT FIRESTORE
import 'package:firebase_auth/firebase_auth.dart'; // <--- IMPORT AUTH (Để lấy user ID hiện tại)
// import 'profile_screen.dart'; // Import ProfileScreen (Giả định tồn tại)

// --- Giả định ProfileScreen tồn tại ---
class ProfileScreen extends StatelessWidget { final String? targetUserId; final VoidCallback onNavigateToHome; final VoidCallback onLogout; const ProfileScreen({super.key, this.targetUserId, required this.onNavigateToHome, required this.onLogout}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text("Profile ${targetUserId ?? 'Me'}")), body: Center(child: Text("Profile Screen")));}
// --- Kết thúc giả định ---


// Constants (Giữ nguyên)
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C);

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _currentQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  int _selectedTabIndex = 0;

  // Header state
  bool _isHeaderVisible = true;
  static const double _headerContentHeight = 135.0;

  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  // Key: targetUserId, Value: 'pending', 'friend', or 'none'
  Map<String, String> _requestStatus = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  // --- Logic tìm kiếm và cập nhật trạng thái (ĐÃ HỢP NHẤT VÀ SỬA LỖI) ---

  // Hàm này được gọi khi text thay đổi để kích hoạt tìm kiếm
  void _onSearchTextChanged() {
    final query = _searchController.text.trim();
    if (_currentQuery != query) {
      setState(() {
        _currentQuery = query;
        _searchResults = [];
        _requestStatus = {};
        if (query.isEmpty) {
          _isLoading = false;
        } else if (_selectedTabIndex == 0) { // Chỉ tìm kiếm theo tên/username khi tab 0
          _performUserSearch(query);
        }
        // Nếu là tab SĐT, chỉ tìm khi user nhấn enter (_performPhoneSearch)
      });
    }
  }

  // LOGIC: Thực hiện tìm kiếm user bằng Username/Name
  void _performUserSearch(String query) async {
    if (query.isEmpty || _selectedTabIndex != 0) return;
    if (mounted) setState(() => _isLoading = true);

    final queryLower = query.toLowerCase();
    final currentUserUid = _auth.currentUser?.uid;

    try {
      // 1. Tìm kiếm theo username/name
      final usernameQuery = _firestore.collection('users')
          .where('usernameLower', isGreaterThanOrEqualTo: queryLower)
          .where('usernameLower', isLessThanOrEqualTo: '$queryLower\uf8ff')
          .limit(10);
      final nameQuery = _firestore.collection('users')
          .where('nameLower', isGreaterThanOrEqualTo: queryLower)
          .where('nameLower', isLessThanOrEqualTo: '$queryLower\uf8ff')
          .limit(10);

      final List<QuerySnapshot> snapshots = await Future.wait([usernameQuery.get(), nameQuery.get()]);

      final Map<String, Map<String, dynamic>> resultsMap = {};
      final List<String> resultUids = [];

      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          if (doc.id == currentUserUid) continue;

          final data = doc.data() as Map<String, dynamic>;
          data['uid'] = doc.id;
          data['mutual'] = data['mutual'] ?? 0;

          if (!resultsMap.containsKey(doc.id)) {
            resultsMap[doc.id] = data;
            resultUids.add(doc.id);
          }
        }
      }

      final finalResults = resultsMap.values.toList();
      finalResults.sort((a, b) => (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));

      if (mounted) {
        setState(() {
          _searchResults = finalResults;
        });
        await _updateRequestStatus(resultUids);
      }

    } catch (e) {
      print("Error searching users: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi tìm kiếm người dùng.'), backgroundColor: coralRed));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // LOGIC: Tìm kiếm user bằng SĐT
  void _performPhoneSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _selectedTabIndex != 1) return;
    if (mounted) setState(() => _isLoading = true);

    // Đặt lại kết quả tìm kiếm theo SĐT
    setState(() { _searchResults = []; });

    try {
      final querySnapshot = await _firestore.collection('users')
          .where('phone', isEqualTo: query)
          .limit(1)
          .get();

      final currentUserUid = _auth.currentUser?.uid;
      final resultsMap = <String, Map<String, dynamic>>{};
      final resultUids = <String>[];

      for (final doc in querySnapshot.docs) {
        if (doc.id == currentUserUid) continue;

        final data = doc.data() as Map<String, dynamic>;
        data['uid'] = doc.id;
        data['mutual'] = 0;
        data['phone'] = query; // Đảm bảo SĐT hiển thị trong subtitle

        if (!resultsMap.containsKey(doc.id)) {
          resultsMap[doc.id] = data;
          resultUids.add(doc.id);
        }
      }

      if (mounted) {
        setState(() { _searchResults = resultsMap.values.toList(); });
        await _updateRequestStatus(resultUids);
      }
      if (resultsMap.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không tìm thấy người dùng với SĐT này.'), backgroundColor: sonicSilver));
      }

    } catch (e) {
      print("Error searching by phone: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi tìm kiếm theo số điện thoại.'), backgroundColor: coralRed));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // LOGIC: Kiểm tra trạng thái lời mời đã gửi/bạn bè (Fix Error 1: Duplicate definition)
  Future<void> _updateRequestStatus(List<String> targetUserIds) async {
    final currentUserUid = _auth.currentUser?.uid;
    if (currentUserUid == null || targetUserIds.isEmpty) return;

    final myDoc = await _firestore.collection('users').doc(currentUserUid).get();
    final myData = myDoc.data() ?? {};
    final List<String> myOutgoingRequests = List<String>.from(myData['outgoingRequests'] ?? []);
    final List<String> myFriendUids = List<String>.from(myData['friendUids'] ?? []);

    Map<String, String> newStatus = {};
    for (var uid in targetUserIds) {
      if (myFriendUids.contains(uid)) {
        newStatus[uid] = 'friend';
      } else if (myOutgoingRequests.contains(uid)) {
        newStatus[uid] = 'pending';
      }
    }

    if (mounted) {
      setState(() {
        _requestStatus = newStatus;
      });
    }
  }

  // LOGIC: Gửi hoặc Hủy lời mời kết bạn
  void _toggleFriendRequest(Map<String, dynamic> user) async {
    final currentUser = _auth.currentUser;
    final targetUserId = user['uid'] as String?;
    final targetUserName = user['name'] as String? ?? 'Người dùng';

    if (currentUser == null || targetUserId == null) return;
    if (mounted) setState(() => _isLoading = true);

    final isPending = _requestStatus[targetUserId] == 'pending';
    final userRef = _firestore.collection('users').doc(currentUser.uid);
    final targetNotificationRef = _firestore.collection('users').doc(targetUserId).collection('notifications');

    try {
      if (isPending) {
        // Hủy lời mời
        await userRef.update({'outgoingRequests': FieldValue.arrayRemove([targetUserId])});

        // Xóa thông báo tương ứng
        final notificationQuery = await targetNotificationRef
            .where('type', isEqualTo: 'friend_request')
            .where('senderId', isEqualTo: currentUser.uid)
            .limit(1)
            .get();
        for (var doc in notificationQuery.docs) {
          await doc.reference.delete();
        }

        if (mounted) {
          setState(() { _requestStatus.remove(targetUserId); });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã hủy lời mời kết bạn tới $targetUserName.'), backgroundColor: sonicSilver));
        }

      } else {
        // Gửi lời mời
        await userRef.update({'outgoingRequests': FieldValue.arrayUnion([targetUserId])});

        // Tạo thông báo cho người nhận
        final senderName = currentUser.displayName ?? currentUser.email?.split('@').first ?? 'Người dùng Zink';
        await targetNotificationRef.add({
          'type': 'friend_request',
          'senderId': currentUser.uid,
          'senderName': senderName,
          'senderAvatarUrl': currentUser.photoURL,
          'destinationId': currentUser.uid,
          'contentPreview': 'đã gửi lời mời kết bạn cho bạn.',
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToProfile(Map<String, dynamic> user) {
    final targetUid = user['uid'] as String?;
    if (targetUid == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => ProfileScreen(
        targetUserId: targetUid,
        onNavigateToHome: () => Navigator.pop(context),
        onLogout: () {},
      ),
    ));
  }


  // Widget hiển thị kết quả tìm kiếm (Fix Error 2 & 3)
  Widget _buildSearchResultTile(Map<String, dynamic> user) {
    final targetUserId = user['uid'] as String?;
    final status = targetUserId != null ? _requestStatus[targetUserId] : null;

    final isFriend = status == 'friend';
    final isPending = status == 'pending';

    final buttonText = isFriend ? 'Bạn bè' : (isPending ? 'Hủy lời mời' : 'Kết bạn');
    final buttonColor = isFriend ? darkSurface : (isPending ? darkSurface : topazColor);
    final textColor = isFriend ? sonicSilver : (isPending ? sonicSilver : Colors.black);
    final sideBorder = isFriend || isPending ? BorderSide(color: sonicSilver) : BorderSide.none;

    // Fix Error 2: Khai báo subtitleText
    final subtitleText = _selectedTabIndex == 0
        ? (user['username'] != null ? '@${user['username']} (${user['mutual'] ?? 0} bạn chung)' : '...')
        : user['phone'] as String? ?? '...';

    // Lấy avatar URL (có thể null)
    final avatarUrl = user['avatarUrl'] as String?;
    final ImageProvider? avatarImage = (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
        ? NetworkImage(avatarUrl)
        : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      leading: GestureDetector(
        onTap: () => _navigateToProfile(user),
        child: CircleAvatar(
          radius: 25,
          backgroundImage: avatarImage,
          backgroundColor: darkSurface,
          child: avatarImage == null ? const Icon(Icons.person, color: sonicSilver, size: 25) : null,
        ),
      ),
      onTap: () => _navigateToProfile(user),
      title: Text(user['name'] as String? ?? '...', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitleText, style: TextStyle(color: sonicSilver, fontSize: 13)), // Sử dụng subtitleText
      // Fix Error 3: Chỉ có một trailing
      trailing: ElevatedButton(
        onPressed: isFriend ? null : () => _toggleFriendRequest(user),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: textColor,
          side: sideBorder,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          minimumSize: const Size(0, 30),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          disabledBackgroundColor: darkSurface,
        ),
        child: Text(buttonText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // Widget chọn tab tìm kiếm (Giữ nguyên)
  Widget _buildSearchTab(String label, int index) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedTabIndex != index) {
            setState(() {
              _selectedTabIndex = index;
              _searchController.clear(); // Xóa tìm kiếm khi đổi tab
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? darkSurface : Colors.black, // Màu nền tab
            border: Border(
              bottom: BorderSide(
                color: isSelected ? topazColor : Colors.transparent,
                width: 2.0,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : sonicSilver,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  // Widget ô nhập liệu tìm kiếm (Giữ nguyên)
  Widget _buildSearchInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        textInputAction: _selectedTabIndex == 0 ? TextInputAction.search : TextInputAction.done,
        keyboardType: _selectedTabIndex == 1 ? TextInputType.phone : TextInputType.text,
        onSubmitted: (_) {
          if (_selectedTabIndex == 0) {
            _performUserSearch(_searchController.text.trim());
          } else {
            _performPhoneSearch();
          }
        },
        decoration: InputDecoration(
          hintText: _selectedTabIndex == 0 ? 'Tìm kiếm Tên hoặc Username...' : 'Tìm kiếm SĐT...',
          hintStyle: TextStyle(color: sonicSilver.withOpacity(0.7)),
          filled: true,
          fillColor: darkSurface,
          prefixIcon: const Icon(Icons.search, color: sonicSilver),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          suffixIcon: _currentQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, color: sonicSilver, size: 18),
            onPressed: _searchController.clear,
            splashRadius: 18,
          )
              : null,
        ),
      ),
    );
  }

  // Widget header động (Giữ nguyên)
  Widget _buildAnimatedHeader() {
    final double headerHeight = _isHeaderVisible ? _headerContentHeight : 0.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300), // Thêm duration
      height: headerHeight,
      color: Colors.black,
      child: SingleChildScrollView( // Dùng SingleChildScrollView để tránh lỗi render khi ẩn
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            // Search Tabs
            Row(
              children: [
                _buildSearchTab('Tên', 0),
                _buildSearchTab('SĐT', 1),
              ],
            ),
            // Search Input
            _buildSearchInput(),
            const Divider(color: darkSurface, height: 1, thickness: 1),
          ],
        ),
      ),
    );
  }

  // Widget trạng thái rỗng/loading (Giữ nguyên)
  Widget _buildEmptyStateOrLoading(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 50.0),
          child: CircularProgressIndicator(color: topazColor),
        ),
      );
    }
    if (_currentQuery.isNotEmpty && _searchResults.isEmpty && _isHeaderVisible) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_search, color: sonicSilver, size: 60),
              const SizedBox(height: 16),
              Text('Không tìm thấy người dùng nào cho "$_currentQuery"', style: TextStyle(color: sonicSilver, fontSize: 16), textAlign: TextAlign.center,),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, color: sonicSilver, size: 60),
            const SizedBox(height: 16),
            Text('Tìm kiếm để kết nối với bạn bè mới', style: TextStyle(color: sonicSilver, fontSize: 16), textAlign: TextAlign.center,),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // ... (Giữ nguyên các đoạn code trước)

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        // THỐNG NHẤT NÚT BACK
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
          splashRadius: 28,
        ),
        title: const Text('Thêm Bạn Bè', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20)),
        backgroundColor: Colors.black, elevation: 0, iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // 1. Animated Header (Tabs + Input)
          _buildAnimatedHeader(),

          // 2. Title và Danh sách
          Expanded(
            child: NotificationListener<UserScrollNotification>(
                onNotification: (notification) {
                  // Logic ẩn/hiện Header (Giữ nguyên)
                  if (notification.metrics.axis == Axis.vertical) {
                    if (notification.direction == ScrollDirection.forward) {
                      if (!_isHeaderVisible) setState(() => _isHeaderVisible = true);
                    } else if (notification.direction == ScrollDirection.reverse) {
                      if (_isHeaderVisible && notification.metrics.pixels > 20) setState(() => _isHeaderVisible = false);
                    }
                  }
                  return false;
                },
                child: _isLoading
                    ? _buildEmptyStateOrLoading(context)
                    : (_searchResults.isEmpty && _currentQuery.isNotEmpty
                    ? _buildEmptyStateOrLoading(context) // Hiển thị trạng thái không tìm thấy
                    : (_searchResults.isEmpty && _currentQuery.isEmpty
                    ? _buildEmptyStateOrLoading(context) // Hiển thị trạng thái ban đầu
                    : Column( // Kết quả tìm kiếm
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0, top: 10.0, bottom: 10.0),
                      child: Text(
                        'Kết quả cho "$_currentQuery"',
                        style: const TextStyle(color: sonicSilver, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        key: const ValueKey('searchResults'),
                        padding: const EdgeInsets.only(bottom: 20), // Remove top padding, rely on Column/Header
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          return _buildSearchResultTile(_searchResults[index]); // Đã cập nhật avatar
                        },
                        separatorBuilder: (context, index) => const Divider(color: darkSurface, height: 1, thickness: 1, indent: 80),
                      ),
                    ),
                  ],
                )
                )
                )
            ),
          ),
        ],
      ),
    );
  }
}

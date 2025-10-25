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
  Map<String, String> _requestStatus = {}; // Key: targetUserId, Value: 'pending' or 'none'

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

  // --- Logic tìm kiếm và cập nhật trạng thái (Giữ nguyên logic Firestore) ---
  void _onSearchTextChanged() async { /* ... Logic tìm kiếm theo Tên/Username ... */ }
  void _performPhoneSearch() async { /* ... Logic tìm kiếm theo SĐT ... */ }
  Future<void> _updateRequestStatus(List<String> targetUserIds) async { /* ... Logic cập nhật trạng thái request ... */ }
  void _toggleFriendRequest(Map<String, dynamic> user) async { /* ... Logic gửi/hủy request ... */ }
  void _navigateToProfile(Map<String, dynamic> user) { /* ... Logic điều hướng ... */ }


  // Widget hiển thị kết quả tìm kiếm (Cập nhật Avatar)
  Widget _buildSearchResultTile(Map<String, dynamic> user) {
    final targetUserId = user['uid'] as String?;
    final isPending = targetUserId != null && _requestStatus[targetUserId] == 'pending';
    final buttonText = isPending ? 'Hủy lời mời' : 'Kết bạn';
    final buttonColor = isPending ? darkSurface : topazColor;
    final textColor = isPending ? sonicSilver : Colors.black;
    final sideBorder = isPending ? BorderSide(color: sonicSilver) : BorderSide.none;
    final subtitleText = _selectedTabIndex == 0 ? '@${user['username'] ?? '...'} (${user['mutual'] ?? 0} bạn chung)' : user['phone'] as String? ?? '...';

    // Lấy avatar URL (có thể null)
    final avatarUrl = user['avatarUrl'] as String?;
    final ImageProvider? avatarImage = (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
        ? NetworkImage(avatarUrl)
        : null; // Không còn fallback AssetImage

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      leading: GestureDetector(
        onTap: () => _navigateToProfile(user),
        child: CircleAvatar( // Avatar đã xử lý null
          radius: 25,
          backgroundImage: avatarImage, // Có thể null
          backgroundColor: darkSurface,
          // Hiển thị Icon nếu không có ảnh
          child: avatarImage == null ? const Icon(Icons.person, color: sonicSilver, size: 25) : null,
        ),
      ),
      onTap: () => _navigateToProfile(user),
      title: Text(user['name'] as String? ?? '...', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitleText, style: TextStyle(color: sonicSilver, fontSize: 13)),
      trailing: ElevatedButton(
        onPressed: () => _toggleFriendRequest(user),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: textColor,
          side: sideBorder,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          minimumSize: const Size(0, 30),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
  // Widget ô nhập liệu tìm kiếm
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
            // Listener đã xử lý
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
  // Widget header động
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
  Widget _buildEmptyStateOrLoading(BuildContext context) { /* ... */ return Center(/* ... */); }


  @override
  Widget build(BuildContext context) {
    // Di chuyển các biến tính toán vào trong hàm build
    final double searchListPaddingTop = MediaQuery.of(context).padding.top + _headerContentHeight + (_isHeaderVisible ? 0 : -_headerContentHeight); // Adjust padding based on header visibility

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
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
                    : (_searchResults.isEmpty
                    ? _buildEmptyStateOrLoading(context)
                    : Column( // Kết quả tìm kiếm
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 10.0),
                      child: Text(
                        'Kết quả cho "$_currentQuery"',
                        style: const TextStyle(color: sonicSilver, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        key: const ValueKey('searchResults'),
                        padding: EdgeInsets.only(bottom: 20), // Remove top padding, rely on Column/Header
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          return _buildSearchResultTile(_searchResults[index]); // Đã cập nhật avatar
                        },
                        separatorBuilder: (context, index) => const Divider( /* ... */ ),
                      ),
                    ),
                  ],
                )
                )
            ),
          ),
        ],
      ),
    );
  }
}

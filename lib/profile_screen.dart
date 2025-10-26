import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';

// Import các lớp cần thiết từ dự án của bạn (đã được sửa trong các bước trước)
import 'post_detail_screen.dart';
import 'message_screen.dart';

// --- Giả định các lớp/hàm cần thiết được định nghĩa ở đây hoặc đã được import ---
class PostDetailScreen extends StatelessWidget { final Map<String, dynamic> postData; const PostDetailScreen({super.key, required this.postData}); @override Widget build(BuildContext context) => PlaceholderScreen(title: "Post Detail", content: "Post Detail Placeholder");}
class PlaceholderScreen extends StatelessWidget { final String title; final String content; const PlaceholderScreen({super.key, required this.title, required this.content}); @override Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.black, appBar: AppBar(title: Text(title, style: const TextStyle(color: Colors.white))), body: Center(child: Text(content, style: const TextStyle(color: sonicSilver)))); }
class FullScreenImageView extends StatelessWidget { final String? imageUrl; final String? tag; const FullScreenImageView({super.key, required this.imageUrl, this.tag}); @override Widget build(BuildContext context) { final ImageProvider? imageProvider = (imageUrl != null && imageUrl!.isNotEmpty && imageUrl!.startsWith('http')) ? NetworkImage(imageUrl!) : null; return Scaffold( backgroundColor: Colors.black.withOpacity(0.9), body: Stack( children: [ Center( child: Hero( tag: tag ?? UniqueKey().toString(), child: InteractiveViewer( panEnabled: false, minScale: 1.0, maxScale: 4.0, child: imageProvider != null ? Image(image: imageProvider, fit: BoxFit.contain) : const Icon(Icons.broken_image, size: 60, color: sonicSilver), ), ), ), Positioned( top: MediaQuery.of(context).padding.top + 10, right: 16, child: IconButton( icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context), style: IconButton.styleFrom( backgroundColor: Colors.black.withOpacity(0.3), ), splashRadius: 24, ), ), ], ), ); } }

// --- Màn hình Chỉnh sửa Profile (ĐÃ HOÀN THIỆN) ---
class EditProfileScreen extends StatefulWidget {
  final String currentUserId;
  final String initialName;
  final String initialBio;
  final bool isAccountLocked;
  final VoidCallback onStateChange;

  const EditProfileScreen({
    super.key,
    required this.currentUserId,
    required this.initialName,
    required this.initialBio,
    required this.isAccountLocked,
    required this.onStateChange,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late bool _isPrivate;
  // Giả định trạng thái riêng tư cho các số liệu
  bool _lockFollowerFollowing = true;
  bool _lockLikedSavedPosts = true;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName;
    _bioController.text = widget.initialBio;
    _isPrivate = widget.isAccountLocked;
  }

  Future<void> _updateProfile() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final Map<String, dynamic> dataToUpdate = {
      'name': _nameController.text.trim(),
      'nameLower': _nameController.text.trim().toLowerCase(),
      'bio': _bioController.text.trim(),
      'isPrivate': _isPrivate,
      // Các trường khóa danh sách cần logic cập nhật thêm trong Firestore nếu cần
      'lockFollowerFollowing': _lockFollowerFollowing,
      'lockLikedSavedPosts': _lockLikedSavedPosts,
    };

    try {
      await _firestore.collection('users').doc(widget.currentUserId).update(dataToUpdate);
      widget.onStateChange(); // Cập nhật lại ProfileScreen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ thành công!'), backgroundColor: topazColor));
        Navigator.pop(context);
      }
    } catch (e) {
      print("Lỗi cập nhật hồ sơ: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: Không thể cập nhật hồ sơ.'), backgroundColor: coralRed));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Chỉnh sửa Trang cá nhân', style: TextStyle(color: Colors.white)),
        backgroundColor: darkSurface,
        actions: [
          _isLoading
              ? const Padding(padding: EdgeInsets.only(right: 16), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: topazColor))))
              : TextButton(
            onPressed: _updateProfile,
            child: const Text('Lưu', style: TextStyle(color: topazColor, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('THÔNG TIN CHUNG', style: TextStyle(color: sonicSilver, fontWeight: FontWeight.bold)),
            const Divider(color: darkSurface),

            // 1. Thay đổi Tên
            _buildEditField(
                controller: _nameController,
                label: 'Tên hiển thị',
                icon: Icons.person_outline
            ),

            // 2. Thay đổi Tiểu sử
            _buildEditField(
              controller: _bioController,
              label: 'Tiểu sử (Bio)',
              icon: Icons.info_outline,
              maxLines: 3,
            ),

            const SizedBox(height: 20),
            const Text('QUYỀN RIÊNG TƯ', style: TextStyle(color: sonicSilver, fontWeight: FontWeight.bold)),
            const Divider(color: darkSurface),

            // 3. Khóa Trang cá nhân (Private Account)
            SwitchListTile(
              secondary: Icon(_isPrivate ? Icons.lock : Icons.lock_open, color: sonicSilver),
              title: const Text('Khóa Trang cá nhân', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Chỉ người theo dõi được chấp thuận mới xem được bài viết.', style: TextStyle(color: sonicSilver)),
              value: _isPrivate,
              onChanged: (newValue) { setState(() => _isPrivate = newValue); },
              activeColor: topazColor,
              inactiveTrackColor: darkSurface,
            ),
            const Divider(color: darkSurface),

            // 4. Khóa số lượt Follower/Following
            SwitchListTile(
              secondary: const Icon(Icons.people_alt_outlined, color: sonicSilver),
              title: const Text('Khóa số lượt Theo dõi', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Ẩn số lượng Bài viết, Theo dõi, Đang theo dõi với người khác.', style: TextStyle(color: sonicSilver)),
              value: _lockFollowerFollowing,
              onChanged: (newValue) { setState(() => _lockFollowerFollowing = newValue); },
              activeColor: topazColor,
              inactiveTrackColor: darkSurface,
            ),
            const Divider(color: darkSurface),

            // 5. Khóa danh sách Đã Lưu/Đã Thích
            SwitchListTile(
              secondary: const Icon(Icons.favorite_border_outlined, color: sonicSilver),
              title: const Text('Khóa Bài viết đã Lưu/Thích', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Chỉ bạn mới xem được tab Bài viết đã Lưu và Đã Thích.', style: TextStyle(color: sonicSilver)),
              value: _lockLikedSavedPosts,
              onChanged: (newValue) { setState(() => _lockLikedSavedPosts = newValue); },
              activeColor: topazColor,
              inactiveTrackColor: darkSurface,
            ),
            const Divider(color: darkSurface),

          ],
        ),
      ),
    );
  }

  // Helper Widget cho TextField
  Widget _buildEditField({required TextEditingController controller, required String label, required IconData icon, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: sonicSilver),
          hintText: 'Nhập $label...',
          hintStyle: TextStyle(color: sonicSilver.withOpacity(0.5)),
          filled: true,
          fillColor: darkSurface,
          prefixIcon: Icon(icon, color: sonicSilver),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// --- Constants thực tế của dự án ---
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C);
const Color activeGreen = Color(0xFF32CD32);

// =======================================================
// WIDGET CHÍNH: ProfileScreen
// =======================================================
class ProfileScreen extends StatefulWidget {
  final VoidCallback onNavigateToHome;
  final VoidCallback onLogout;
  final String? targetUserId;

  const ProfileScreen({
    super.key,
    required this.onNavigateToHome,
    required this.onLogout,
    this.targetUserId
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  int _selectedTabIndex = 0;
  late final bool _isMyProfile;
  late final String _profileUserId;

  Stream<DocumentSnapshot>? _userStream;
  Stream<DocumentSnapshot>? _myUserDataStream;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _profileUserId = widget.targetUserId ?? _currentUser?.uid ?? '';
    _isMyProfile = widget.targetUserId == null || widget.targetUserId == _currentUser?.uid;

    if (_profileUserId.isNotEmpty) {
      _userStream = _firestore.collection('users').doc(_profileUserId).snapshots();
    }
    if (!_isMyProfile && _currentUser != null) {
      _myUserDataStream = _firestore.collection('users').doc(_currentUser!.uid).snapshots();
    }
  }

  // --- Hàm format Timestamp (Placeholder) ---
  String _formatTimestampAgo(Timestamp timestamp) {
    final difference = DateTime.now().difference(timestamp.toDate());
    if (difference.inHours < 1) return '${difference.inMinutes} phút';
    if (difference.inDays < 1) return '${difference.inHours} giờ';
    return '${difference.inDays} ngày';
  }

  // --- Hàm helper để cập nhật user profile trên Firestore (Placeholder) ---
  Future<void> _updateUserProfile(Map<String, dynamic> dataToUpdate) async {
    print("TODO: Update profile with $dataToUpdate");
    // Thường dùng: await _firestore.collection('users').doc(_profileUserId).update(dataToUpdate);
  }

  // --- Hàm xử lý Follow/Unfollow (Placeholder) ---
  Future<void> _toggleFollow(bool amIFollowingTarget) async {
    print("TODO: Follow/Unfollow action: ${amIFollowingTarget ? 'Unfollow' : 'Follow'}");
  }

  // --- Build Stats (ĐÃ SỬA: Bỏ Lượt thích, căn giữa Followers) ---
  Widget _buildStatsBlock(int posts, int followers, int following) {
    return Row(
      // Sử dụng MainAxisAlignment.spaceEvenly để căn đều
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem(posts, 'Bài viết'),
        // Không cần divider ở đây nếu chỉ có 3 mục
        _buildStatItem(followers, 'Người theo dõi'),
        // Không cần divider ở đây nếu chỉ có 3 mục
        _buildStatItem(following, 'Đang theo dõi'),
      ],
    );
  }

  Widget _buildStatItem(int count, String label) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: sonicSilver.withOpacity(0.8), fontSize: 14),
        ),
      ],
    );
  }

  // Widget _buildVerticalDivider() { // Không cần nữa nếu dùng spaceEvenly cho 3 mục
  //   return Container(
  //     height: 25,
  //     width: 1,
  //     color: sonicSilver.withOpacity(0.4),
  //   );
  // }

  // --- Action Buttons ---
  Widget _buildActionButtons(BuildContext context, bool isAccountLocked, String name, String bio) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<DocumentSnapshot>(
        stream: _myUserDataStream,
        builder: (context, myDataSnapshot) {
          if (_isMyProfile) {
            return const SizedBox.shrink(); // Không hiển thị nút nào cho profile của mình
          }

          // Logic cho profile người khác
          bool amIFollowingTarget = false;
          if (myDataSnapshot.hasData && myDataSnapshot.data!.exists) {
            final myData = myDataSnapshot.data!.data() as Map<String, dynamic>? ?? {};
            amIFollowingTarget = (myData['following'] as List<dynamic>? ?? []).contains(_profileUserId);
          }

          return Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _toggleFollow(amIFollowingTarget),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: amIFollowingTarget ? darkSurface : topazColor,
                    foregroundColor: amIFollowingTarget ? Colors.white : Colors.black,
                    side: amIFollowingTarget ? const BorderSide(color: sonicSilver) : BorderSide.none,
                    minimumSize: const Size(0, 45),
                  ),
                  child: Text(amIFollowingTarget ? 'Đang theo dõi' : 'Theo dõi', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => MessageScreen(targetUserId: _profileUserId)));
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: sonicSilver),
                    minimumSize: const Size(0, 45),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Nhắn tin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Start of newly defined methods ---

  // Hiển thị ảnh FullScreen
  void _showFullScreenImage(String? imageUrl, {String? tag}) {
    if (imageUrl == null || imageUrl.isEmpty || !imageUrl.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không có ảnh để hiển thị.')));
      return;
    }
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false, barrierColor: Colors.black.withOpacity(0.7),
        pageBuilder: (BuildContext context, _, __) {
          return FullScreenImageView(imageUrl: imageUrl, tag: tag);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }


  // Hiển thị Bottom Sheet Menu
  void _showSubMenu(String title, List<Widget> items) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: topazColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: darkSurface, height: 1),
              ...items,
            ],
          ),
        );
      },
    );
  }

  // Xử lý khi bấm vào Avatar
  void _handleAvatarTap(BuildContext context, String? avatarImageUrl) {
    final heroTag = 'userAvatar_$_profileUserId';
    if (!_isMyProfile) {
      _showFullScreenImage(avatarImageUrl, tag: heroTag);
      return;
    }

    // Profile của tôi
    _showSubMenu('Tùy chọn Ảnh đại diện', [
      ListTile(
          leading: const Icon(Icons.zoom_in, color: Colors.white),
          title: const Text('Xem ảnh đại diện', style: TextStyle(color: Colors.white)),
          onTap: () { Navigator.pop(context); _showFullScreenImage(avatarImageUrl, tag: heroTag); }
      ),
      ListTile(
          leading: const Icon(Icons.camera_alt, color: Colors.white),
          title: const Text('Đổi ảnh đại diện', style: TextStyle(color: Colors.white)),
          onTap: () { Navigator.pop(context); /* TODO: Pick/Upload logic */ }
      ),
      if (avatarImageUrl != null && avatarImageUrl.isNotEmpty)
        ListTile(
            leading: const Icon(Icons.delete_forever, color: coralRed),
            title: const Text('Xóa ảnh đại diện', style: TextStyle(color: coralRed)),
            onTap: () { Navigator.pop(context); _updateUserProfile({'avatarUrl': null}); }
        ),
    ]);
  }

  // Xử lý khi bấm vào Ảnh bìa
  void _handleCoverTap(BuildContext context, String? coverImageUrl) {
    final heroTag = 'userCover_$_profileUserId';

    if (!_isMyProfile) {
      _showFullScreenImage(coverImageUrl, tag: null);
      return;
    }

    _showSubMenu('Tùy chọn Ảnh bìa', [
      ListTile(
          leading: const Icon(Icons.zoom_in, color: Colors.white),
          title: const Text('Xem ảnh bìa', style: TextStyle(color: Colors.white)),
          onTap: () { Navigator.pop(context); _showFullScreenImage(coverImageUrl, tag: heroTag); }
      ),
      ListTile(
          leading: const Icon(Icons.camera_alt, color: Colors.white),
          title: const Text('Đổi ảnh bìa', style: TextStyle(color: Colors.white)),
          onTap: () { Navigator.pop(context); /* TODO: Pick/Upload logic */ }
      ),
      if (coverImageUrl != null && coverImageUrl.isNotEmpty)
        ListTile(
            leading: const Icon(Icons.delete_forever, color: coralRed),
            title: const Text('Xóa ảnh bìa', style: TextStyle(color: coralRed)),
            onTap: () { Navigator.pop(context); _updateUserProfile({'coverImageUrl': null}); }
        ),
    ]);
  }

  // Widget cho menu Profile của tôi
  Widget _buildMyProfileMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu, color: Colors.white),
      color: darkSurface,
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem<String>(value: 'edit', child: Text('Chỉnh sửa trang cá nhân')),
        const PopupMenuItem<String>(value: 'settings', child: Text('Cài đặt')),
        const PopupMenuItem<String>(value: 'logout', child: Text('Đăng xuất', style: TextStyle(color: coralRed))),
      ],
      onSelected: (String value) {
        if (value == 'logout') {
          widget.onLogout();
        } else if (value == 'edit') {
          final currentSnapshot = (_userStream as Stream<DocumentSnapshot>).first;
          currentSnapshot.then((snapshot) {
            final data = snapshot.data() as Map<String, dynamic>? ?? {};
            Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfileScreen(
              currentUserId: _profileUserId,
              initialName: data['name'] ?? '',
              initialBio: data['bio'] ?? data['title'] ?? '',
              isAccountLocked: data['isPrivate'] ?? false,
              onStateChange: () => setState(() {}),
            )));
          }).catchError((e) {
            print("Lỗi khi lấy dữ liệu: $e");
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể tải dữ liệu để chỉnh sửa.'), backgroundColor: coralRed));
          });
        }
      },
    );
  }

  // Widget cho menu Profile của người khác
  Widget _buildOtherProfileMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      color: darkSurface,
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem<String>(value: 'report', child: Text('Báo cáo người dùng')),
        const PopupMenuItem<String>(value: 'block', child: Text('Chặn người dùng')),
      ],
      onSelected: (String value) { /* TODO: Xử lý logic report/block */ },
    );
  }

  // --- End of newly defined methods ---


  // --- Gallery Tabs ---
  Widget _buildGalleryTabs() {
    final isMyProfile = _isMyProfile;
    return Container(
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border( bottom: BorderSide( color: darkSurface, width: 0.5, ), ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTabIcon(Icons.grid_on_rounded, 0),
          if (isMyProfile) _buildTabIcon(Icons.lock_outline_rounded, 1),
          _buildTabIcon(Icons.favorite_border_rounded, isMyProfile ? 2 : 1),
          if (isMyProfile) _buildTabIcon(Icons.bookmark_border_rounded, 3),
        ],
      ),
    );
  }

  Widget _buildTabIcon(IconData icon, int index) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () { if (_selectedTabIndex != index) setState(() { _selectedTabIndex = index; }); },
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          decoration: BoxDecoration( border: Border( bottom: BorderSide( color: isSelected ? Colors.white : Colors.transparent, width: isSelected ? 2.0 : 0.0, ), ), ),
          child: Icon( icon, color: isSelected ? Colors.white : sonicSilver.withOpacity(0.8), size: 24 ),
        ),
      ),
    );
  }


  // --- Content Grid ---
  Widget _buildContentGrid() {
    if (_profileUserId.isEmpty) { return const Center(child: Padding( padding: EdgeInsets.all(40.0), child: Text('Không tìm thấy ID người dùng.', style: TextStyle(color: coralRed)) )); }
    final currentUserId = _currentUser?.uid ?? '';
    Query postsQuery;

    postsQuery = _firestore.collection('posts').where('uid', isEqualTo: _profileUserId).where('privacy', isEqualTo: 'Công khai').orderBy('timestamp', descending: true);
    final tabIndex = _selectedTabIndex;
    final isMyProfile = _isMyProfile;

    if (isMyProfile) {
      switch (tabIndex) {
        case 0: postsQuery = _firestore.collection('posts').where('uid', isEqualTo: _profileUserId).where('privacy', isEqualTo: 'Công khai').orderBy('timestamp', descending: true); break;
        case 1: postsQuery = _firestore.collection('posts').where('uid', isEqualTo: _profileUserId).where('privacy', isEqualTo: 'Chỉ mình tôi').orderBy('timestamp', descending: true); break;
        case 2: postsQuery = _firestore.collection('posts').where('likedBy', arrayContains: currentUserId).orderBy('timestamp', descending: true); break;
        case 3: postsQuery = _firestore.collection('posts').where('savedBy', arrayContains: currentUserId).orderBy('timestamp', descending: true); break;
      }
    } else {
      switch (tabIndex) {
        case 0: postsQuery = _firestore.collection('posts').where('uid', isEqualTo: _profileUserId).where('privacy', isEqualTo: 'Công khai').orderBy('timestamp', descending: true); break;
        case 1: return const Center(child: Padding(padding: EdgeInsets.all(40.0), child: Text('Không thể xem bài viết đã thích của người khác.', style: TextStyle(color: sonicSilver))));
        default: postsQuery = _firestore.collection('posts').where('uid', isEqualTo: _profileUserId).where('privacy', isEqualTo: 'Công khai').orderBy('timestamp', descending: true);
      }
    }

    return StreamBuilder<QuerySnapshot>(
      stream: postsQuery.limit(21).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: Padding( padding: EdgeInsets.symmetric(vertical: 40.0), child: CircularProgressIndicator(color: topazColor) )); }
        if (snapshot.hasError) { return Center(child: Padding( padding: const EdgeInsets.all(40.0), child: Text('Lỗi tải nội dung: ${snapshot.error}', style: const TextStyle(color: coralRed)) )); }
        final postDocs = snapshot.data?.docs ?? [];
        if (postDocs.isEmpty) { return Center(child: Padding( padding: const EdgeInsets.all(40.0), child: Text(_selectedTabIndex == 0 ? 'Chưa có bài viết nào được đăng.' : 'Không có nội dung cho tab này.', style: TextStyle(color: sonicSilver)) )); }

        return GridView.builder(
          padding: EdgeInsets.zero, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          itemCount: postDocs.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount( crossAxisCount: 3, crossAxisSpacing: 1.0, mainAxisSpacing: 1.0, childAspectRatio: 1.0),
          itemBuilder: (context, index) {
            final doc = postDocs[index];
            final postData = doc.data() as Map<String, dynamic>? ?? {};
            final String? imageUrl = postData['imageUrl'] as String?;
            final List<String> likedByList = List<String>.from(postData['likedBy'] ?? []);
            final int likes = (postData['likesCount'] is num ? (postData['likesCount'] as num).toInt() : likedByList.length);
            return _buildGridItem(doc.id, imageUrl, likes);
          },
        );
      },
    );
  }

  // Widget cho một item trong Grid
  Widget _buildGridItem(String postId, String? imagePathOrUrl, int likes) {
    final ImageProvider? imageProvider = (imagePathOrUrl != null && imagePathOrUrl.isNotEmpty && imagePathOrUrl.startsWith('http')) ? NetworkImage(imagePathOrUrl) : null;
    return GestureDetector(
      onTap: () => _navigateToPostDetail(postId),
      child: Container(
          decoration: const BoxDecoration( color: darkSurface ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageProvider != null ? Image( image: imageProvider, fit: BoxFit.cover, loadingBuilder: (context, child, progress) => progress == null ? child : Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24))), errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: sonicSilver), ) : const Icon(Icons.image_not_supported, color: sonicSilver, size: 40),
              if (likes > 0) Align( alignment: Alignment.bottomLeft, child: Padding( padding: const EdgeInsets.all(6.0), child: Row( mainAxisSize: MainAxisSize.min, children: [ const Icon(Icons.favorite, color: Colors.white, size: 14), const SizedBox(width: 4), Text( likes.toString(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), ), ], ), ), ),
            ],
          )
      ),
    );
  }

  // Hàm điều hướng đến Post Detail
  Future<void> _navigateToPostDetail(String postId) async {
    print("Navigating to Post Detail for: $postId");
    // TODO: Implement navigation logic
  }

  // --- Hàm Build chính ---
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: Scaffold( backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: topazColor)) )); }
        if (snapshot.hasError) { return Center(child: Scaffold( backgroundColor: Colors.black, body: Center(child: Text('Lỗi tải dữ liệu người dùng: ${snapshot.error}', style: const TextStyle(color: coralRed))) )); }

        final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final String displayedName = userData['name'] ?? 'Người dùng Zink';
        final String displayedTitle = userData['title'] ?? userData['bio'] ?? '';
        final String displayedBio = userData['bio'] ?? userData['title'] ?? '';
        final bool isAccountLocked = userData['isPrivate'] ?? false;
        final String? avatarUrl = userData['avatarUrl'] as String?;
        final String? coverUrl = userData['coverImageUrl'] as String?; // Vẫn lấy coverUrlเผื่อ dùng sau
        final List<String> followers = List<String>.from(userData['followers'] ?? []);
        final List<String> following = List<String>.from(userData['following'] ?? []);
        final int postsCount = (userData['postsCount'] is num ? (userData['postsCount'] as num).toInt() : 0);

        final ImageProvider? avatarImageProvider = (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) ? NetworkImage(avatarUrl) : null;

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black, elevation: 0,
            title: Row( mainAxisSize: MainAxisSize.min, children: [ Text(displayedName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), if (isAccountLocked) const Padding( padding: EdgeInsets.only(left: 6.0), child: Icon(Icons.lock, color: sonicSilver, size: 18), ), ], ),
            centerTitle: true,
            leading: _isMyProfile ? null : IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
            actions: [ _isMyProfile ? _buildMyProfileMenu(context) : _buildOtherProfileMenu(context), ],
          ),
          body: Column(
            children: [
              // 1. HEADER INFO (Đã bỏ totalLikes)
              _buildProfileHeaderContent(
                  context, displayedName, displayedTitle, displayedBio,
                  avatarUrl, avatarImageProvider,
                  postsCount, followers.length, following.length,
                  isAccountLocked
              ),
              // 2. TABS
              _buildGalleryTabs(),
              // 3. CONTENT GRID
              Expanded( child: SingleChildScrollView( child: _buildContentGrid(), ), ),
            ],
          ),
        );
      },
    );
  }

  // --- Phương thức xây dựng nội dung Header (ĐÃ SỬA: Bỏ totalLikes) ---
  Widget _buildProfileHeaderContent(
      BuildContext context, String name, String title, String bio,
      String? avatarPathOrUrl, ImageProvider? avatarImageProvider,
      int postsCount, int followersCount, int followingCount,
      bool isAccountLocked
      ) {
    final heroTag = 'userAvatar_$_profileUserId';
    final bool hideSensitiveStats = !_isMyProfile && isAccountLocked;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          const SizedBox(height: 5),
          // Avatar
          GestureDetector( onTap: () => _handleAvatarTap(context, avatarPathOrUrl), child: Hero( tag: heroTag, child: CircleAvatar( radius: 40, backgroundColor: darkSurface, backgroundImage: avatarImageProvider, child: avatarImageProvider == null ? const Icon(Icons.person, color: sonicSilver, size: 40) : null, ), ), ),
          // Bio
          if (bio.isNotEmpty) Padding( padding: const EdgeInsets.only(top: 10.0, bottom: 10.0), child: Text( bio, textAlign: TextAlign.center, style: TextStyle(color: sonicSilver, fontSize: 16) ), ),
          const SizedBox(height: 10),
          // Stats Block (ĐÃ CẬP NHẬT)
          _buildStatsBlock(
              postsCount,
              hideSensitiveStats ? 0 : followersCount,
              hideSensitiveStats ? 0 : followingCount
          ),
          const SizedBox(height: 20),
          // Action Buttons
          _buildActionButtons( context, isAccountLocked, name, bio ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
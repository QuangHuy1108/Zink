// lib/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui'; // Dùng cho ImageFilter

// Import các màn hình/widgets liên quan (Giả định chúng tồn tại hoặc được định nghĩa trong file này)
// import 'feed_screen.dart'; // Để dùng _StatItem và Constants
// import 'post_detail_screen.dart';
// import 'models.dart';

// --- Giả định các lớp này được định nghĩa ở đâu đó ---
class FeedScreen extends StatelessWidget { const FeedScreen({super.key}); @override Widget build(BuildContext context) => PlaceholderScreen(title: "Feed", content: "Feed Screen Placeholder");}
class PostDetailScreen extends StatelessWidget { final Map<String, dynamic> postData; const PostDetailScreen({super.key, required this.postData}); @override Widget build(BuildContext context) => PlaceholderScreen(title: "Post Detail", content: "Post Detail Placeholder");}
class PostCard extends StatelessWidget { final Map<String, dynamic> postData; final VoidCallback onStateChange; const PostCard({super.key, required this.postData, required this.onStateChange}); @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(8), margin: const EdgeInsets.symmetric(vertical: 4), color: darkSurface, child: Text("Post ${postData['id']}", style: const TextStyle(color: Colors.white))); }
class Comment { final String id; final String userId; final String userName; final String? userAvatarUrl; final String text; final Timestamp timestamp; final String? parentId; bool isLiked; int likesCount; final List<String> likedBy; Comment({required this.id, required this.userId, required this.userName, this.userAvatarUrl, required this.text, required this.timestamp, this.parentId, this.isLiked = false, required this.likesCount, required this.likedBy}); factory Comment.fromFirestore(DocumentSnapshot doc, String currentUserId) => Comment(id: doc.id, userId: '', userName: '', text: '', timestamp: Timestamp.now(), likesCount: 0, likedBy: []);}
class PlaceholderScreen extends StatelessWidget { final String title; final String content; const PlaceholderScreen({super.key, required this.title, required this.content}); @override Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.black, appBar: AppBar(title: Text(title, style: const TextStyle(color: Colors.white))), body: Center(child: Text(content, style: const TextStyle(color: sonicSilver)))); }
class FollowersScreen extends StatelessWidget { const FollowersScreen({super.key}); @override Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.black, appBar: AppBar(title: const Text('Followers', style: TextStyle(color: Colors.white))), body: const Center(child: Text('Followers List Placeholder', style: TextStyle(color: sonicSilver)))); }
class MessageScreen extends StatefulWidget { final String? targetUserId; const MessageScreen({this.targetUserId, super.key}); @override State<MessageScreen> createState() => _MessageScreenState();}
class _MessageScreenState extends State<MessageScreen> { @override Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.black, appBar: AppBar(title: Text('Nhắn tin ${widget.targetUserId ?? ""}', style: const TextStyle(color: Colors.white))), body: const Center(child: Text('Message Screen Placeholder', style: TextStyle(color: sonicSilver)))); }
// --- Kết thúc giả định ---


// Constants
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C);
const Color activeGreen = Color(0xFF32CD32);

// --- ĐÃ XÓA: _userAssets, _postAssets ---

// =======================================================
// WIDGET CHÍNH: ProfileScreen (Đã cập nhật với Firestore và xóa ảnh assets)
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

  // --- Hàm format Timestamp (Giữ nguyên) ---
  String _formatTimestampAgo(Timestamp timestamp) { /* ... */ return '';}

  // Xem ảnh FullScreen (Cập nhật để xử lý URL null)
  void _showFullScreenImage(String? imageUrl, {String? tag}) { // Nhận URL có thể null
    if (imageUrl == null || imageUrl.isEmpty || !imageUrl.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không có ảnh để hiển thị.')));
      return; // Không mở nếu không có URL hợp lệ
    }
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false, barrierColor: Colors.black.withOpacity(0.7),
        pageBuilder: (BuildContext context, _, __) {
          // FullScreenImageView giờ cũng cần xử lý URL null (hoặc không gọi nếu null)
          return FullScreenImageView(imageUrl: imageUrl, tag: tag);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  // Hiển thị Bottom Sheet Menu (Giữ nguyên UI)
  void _showSubMenu(String title, List<Widget> items) { /* ... */ }

  // Xử lý khi bấm vào Ảnh bìa (Cập nhật logic URL)
  void _handleCoverTap(BuildContext context, String? coverImageUrl) { // Nhận URL có thể null
    if (!_isMyProfile) { // Xem profile người khác
      _showFullScreenImage(coverImageUrl, tag: null); // Truyền URL (có thể null)
      return;
    }
    // Profile của tôi
    _showSubMenu('Tùy chọn Ảnh bìa', [
      ListTile( /* ... Xem ảnh bìa ... */ onTap: () { Navigator.pop(context); _showFullScreenImage(coverImageUrl, tag: null); }),
      ListTile( /* ... Đổi ảnh bìa ... */ onTap: () { /* TODO: Pick/Upload logic */ }),
      if (coverImageUrl != null && coverImageUrl.isNotEmpty) // Chỉ hiện nếu có ảnh
        ListTile( /* ... Xóa ảnh bìa ... */ onTap: () { /* TODO: Update Firestore */ _updateUserProfile({'coverImageUrl': null}); }),
    ]);
  }

  // Xử lý khi bấm vào Avatar (Cập nhật logic URL)
  void _handleAvatarTap(BuildContext context, String? avatarImageUrl) { // Nhận URL có thể null
    final heroTag = 'userAvatar_$_profileUserId'; // Giữ tag cho Hero
    if (!_isMyProfile) {
      _showFullScreenImage(avatarImageUrl, tag: heroTag); // Truyền URL (có thể null)
      return;
    }
    // Profile của tôi
    _showSubMenu('Tùy chọn Ảnh đại diện', [
      ListTile( /* ... Xem ảnh đại diện ... */ onTap: () { Navigator.pop(context); _showFullScreenImage(avatarImageUrl, tag: heroTag); }),
      ListTile( /* ... Đổi ảnh đại diện ... */ onTap: () { /* TODO: Pick/Upload logic */ }),
      if (avatarImageUrl != null && avatarImageUrl.isNotEmpty) // Chỉ hiện nếu có ảnh
        ListTile( /* ... Xóa ảnh đại diện ... */ onTap: () { /* TODO: Update Firestore */ _updateUserProfile({'avatarUrl': null}); }),
    ]);
  }


  // Hàm helper để cập nhật user profile trên Firestore (Giữ nguyên)
  Future<void> _updateUserProfile(Map<String, dynamic> dataToUpdate) async { /* ... */ }

  // Hàm xử lý Follow/Unfollow (Giữ nguyên)
  Future<void> _toggleFollow(bool amIFollowingTarget) async { /* ... */ }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: CircularProgressIndicator(color: topazColor))
          ));
        }
        if (snapshot.hasError) {
          return Center(child: Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: Text('Lỗi tải dữ liệu người dùng: ${snapshot.error}', style: const TextStyle(color: coralRed)))
          ));
        }

        // SỬA LỖI: Kiểm tra an toàn cho snapshot.data trước khi truy cập
        // Nếu không có dữ liệu người dùng (document không tồn tại), sử dụng map rỗng
        final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};

        // ĐẢM BẢO CÁC TRƯỜNG DỮ LIỆU ĐƯỢC XỬ LÝ AN TOÀN VỚI GIÁ TRỊ MẶC ĐỊNH
        final String displayedName = userData['name'] ?? 'Người dùng mới';
        final String displayedTitle = userData['title'] ?? userData['bio'] ?? '';
        final String? avatarUrl = userData['avatarUrl'] as String?;
        final String? coverUrl = userData['coverImageUrl'] as String?;

        // XỬ LÝ AN TOÀN CHO LIST VÀ SỐ
        final List<String> followers = List<String>.from(userData['followers'] ?? []);
        final List<String> following = List<String>.from(userData['following'] ?? []);

        // XỬ LÝ AN TOÀN CHO CÁC TRƯỜNG SỐ (CÓ THỂ LÀ num HOẶC int/null)
        final int postsCount = (userData['postsCount'] is num ? (userData['postsCount'] as num).toInt() : 0);
        final int totalLikes = (userData['totalLikes'] is num ? (userData['totalLikes'] as num).toInt() : 0);

        // Xác định ImageProvider (giữ nguyên)
        final ImageProvider? avatarImageProvider = (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
            ? NetworkImage(avatarUrl) : null;
        final ImageProvider? coverImageProvider = (coverUrl != null && coverUrl.isNotEmpty && coverUrl.startsWith('http'))
            ? NetworkImage(coverUrl) : null;

        return Scaffold(
          backgroundColor: Colors.black,
          body: SingleChildScrollView(
            child: Column(
              children: [
                _buildProfileHeader(
                  context, displayedName, displayedTitle,
                  avatarUrl,
                  coverUrl,
                  avatarImageProvider, coverImageProvider,
                  postsCount, followers.length, totalLikes,
                ),
                _buildGalleryTabs(),
                _buildContentGrid(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Header Section (Cập nhật tham số và Avatar/Cover) ---
  Widget _buildProfileHeader(
      BuildContext context, String name, String title,
      String? avatarPathOrUrl, String? coverPathOrUrl, // Nhận URL có thể null
      ImageProvider? avatarImageProvider, ImageProvider? coverImageProvider, // Nhận Provider có thể null
      int postsCount, int followersCount, int totalLikes,
      ) {
    final heroTag = 'userAvatar_$_profileUserId'; // Tag cho Hero

    return Stack(
      alignment: Alignment.topCenter, clipBehavior: Clip.none,
      children: [
        // 1. Ảnh bìa (Hiển thị màu nền nếu coverImageProvider là null)
        GestureDetector(
          onTap: () => _handleCoverTap(context, coverPathOrUrl), // Truyền URL gốc
          child: Container(
            height: 250, width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF222222), // Màu nền nếu không có ảnh
              image: coverImageProvider != null ? DecorationImage(
                image: coverImageProvider, fit: BoxFit.cover, alignment: Alignment.center,
                // Optional: Error builder for cover image
                onError: (exception, stackTrace) {
                  print("Error loading cover image: $exception");
                  // Don't show anything, rely on background color
                },
              ) : null,
            ),
            child: coverImageProvider != null ? Container( /* Gradient */ ) : null,
          ),
        ),

        // 2. Main Content
        Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10),
          child: Column(
            children: [
              // Top Bar (Giữ nguyên)
              Row( /* ... Back button, Menu ... */ ),
              const SizedBox(height: 30),

              // Avatar (Cập nhật để hiển thị Icon nếu provider null)
              Transform.translate(
                offset: const Offset(0, -70),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => _handleAvatarTap(context, avatarPathOrUrl), // Truyền URL gốc
                      child: Hero(
                        tag: heroTag,
                        child: CircleAvatar(
                          radius: 50, backgroundColor: Colors.black,
                          child: CircleAvatar(
                            radius: 47, backgroundColor: darkSurface,
                            backgroundImage: avatarImageProvider, // Có thể null
                            // Hiển thị Icon nếu không có ảnh
                            child: avatarImageProvider == null ? const Icon(Icons.person, color: sonicSilver, size: 50) : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Name and Title (Giữ nguyên)
                    Text(name, /* ... */),
                    if (title.isNotEmpty) Text(title, /* ... */),
                  ],
                ),
              ),

              // Stats Block (Giữ nguyên)
              _buildStatsBlock(postsCount, followersCount, totalLikes),
              const SizedBox(height: 25),

              // Action Buttons (Giữ nguyên)
              _buildActionButtons(context),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ],
    );
  }

  // Widget cho menu 3 chấm (Giữ nguyên)
  Widget _buildOtherProfileMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      color: darkSurface,
      // Sửa lỗi: Thêm itemBuilder
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem<String>(value: 'report', child: Text('Báo cáo người dùng')),
        const PopupMenuItem<String>(value: 'block', child: Text('Chặn người dùng')),
      ],
      onSelected: (String value) {
        // TODO: Xử lý logic report/block
      },
    );
  }

  Widget _buildMyProfileMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu, color: Colors.white),
      color: darkSurface,
      // Sửa lỗi: Thêm itemBuilder
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem<String>(value: 'edit', child: Text('Chỉnh sửa trang cá nhân')),
        const PopupMenuItem<String>(value: 'settings', child: Text('Cài đặt')),
        const PopupMenuItem<String>(value: 'logout', child: Text('Đăng xuất', style: TextStyle(color: coralRed))),
      ],
      onSelected: (String value) {
        if (value == 'logout') {
          widget.onLogout();
        }
        // TODO: Xử lý logic edit/settings
      },
    );
  }

  // --- Stats Block (Giữ nguyên) ---
  Widget _buildStatsBlock(int posts, int followers, int likes) { /* ... */ return Row(/* ... */); }
  Widget _buildVerticalDivider() { /* ... */ return Container(/* ... */); }

  // --- Action Buttons (Giữ nguyên) ---
  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16), // Sửa lỗi: Thêm padding
      child: StreamBuilder<DocumentSnapshot>( // Sửa lỗi: Thêm child (ví dụ)
        stream: _myUserDataStream,
        builder: (context, myDataSnapshot) {
          if (_isMyProfile) {
            return ElevatedButton(
              onPressed: () { /* TODO: Navigate to Edit Profile */ },
              style: ElevatedButton.styleFrom(
                backgroundColor: topazColor,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 45),
              ),
              child: const Text('Chỉnh sửa trang cá nhân', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            );
          }

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
  // --- Gallery Tabs (Giữ nguyên) ---
  Widget _buildGalleryTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Sửa lỗi: Thêm padding
      child: Row( // Sửa lỗi: Thêm child
        children: [
          _buildTabIcon(Icons.grid_on_rounded, 0),
          _buildTabIcon(Icons.bookmark_border_rounded, 1),
          if (!_isMyProfile)
            _buildTabIcon(Icons.favorite_border_rounded, 2, isOtherProfile: true),
        ],
      ),
    );
  }  Widget _buildTabIcon(IconData icon, int index, {bool isOtherProfile = false}) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: IconButton( // Sửa lỗi: Thêm child
        icon: Icon(icon, color: isSelected ? Colors.white : sonicSilver, size: 28),
        onPressed: () {
          if (_selectedTabIndex != index) {
            setState(() { _selectedTabIndex = index; });
          }
        },
        splashRadius: 24,
      ),
    );
  }

  // --- Content Grid (Cập nhật để dùng _buildGridItem đã xử lý null) ---
  // lib/profile_screen.dart

// ... (Các phần code trên giữ nguyên) ...

  // --- Content Grid (SỬA LỖI NULL CHECK) ---
  Widget _buildContentGrid() {
    if (_profileUserId.isEmpty) {
      return const Center(child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Text('Không tìm thấy ID người dùng.', style: TextStyle(color: coralRed))
      ));
    }
    final currentUserId = _currentUser?.uid ?? '';
    Query postsQuery;

    // Tạm thời chỉ hiển thị posts, giả định logic query đã đúng
    // Mặc định là posts của profile đang xem
    postsQuery = _firestore.collection('posts')
        .where('uid', isEqualTo: _profileUserId)
        .orderBy('timestamp', descending: true);

    switch (_selectedTabIndex) {
      case 0: // Posts
        postsQuery = _firestore.collection('posts')
            .where('uid', isEqualTo: _profileUserId)
            .orderBy('timestamp', descending: true);
        break;
      case 1: // Reels (Giả định có collection 'reels')
        postsQuery = _firestore.collection('reels')
            .where('uid', isEqualTo: _profileUserId)
            .orderBy('timestamp', descending: true);
        break;
      case 2: // Saved Posts (Chỉ dành cho profile của tôi)
        if (_isMyProfile) {
          // Query posts where 'savedBy' array contains currentUserId
          postsQuery = _firestore.collection('posts')
              .where('savedBy', arrayContains: currentUserId)
              .orderBy('timestamp', descending: true);
        } else {
          // Không hiển thị Saved Posts của người khác
          return const Center(child: Padding(padding: EdgeInsets.all(40.0), child: Text('Không thể xem bài viết đã lưu của người khác.', style: TextStyle(color: sonicSilver))));
        }
        break;
    }


    return StreamBuilder<QuerySnapshot>(
      stream: postsQuery.limit(21).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // HIỂN THỊ LOADING THAY VÌ LỖI MÀN HÌNH ĐỎ
          return const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: CircularProgressIndicator(color: topazColor)
          ));
        }
        if (snapshot.hasError) {
          return Center(child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Text('Lỗi tải nội dung: ${snapshot.error}', style: const TextStyle(color: coralRed))
          ));
        }

        // SỬA LỖI NULL CHECK BẰNG CÁCH SỬ DỤNG ?.docs ?? []
        final postDocs = snapshot.data?.docs ?? [];

        if (postDocs.isEmpty) {
          return const Center(child: Padding(
              padding: EdgeInsets.all(40.0),
              child: Text('Chưa có bài viết nào được đăng.', style: TextStyle(color: sonicSilver))
          ));
        }

        // Khắc phục lỗi bố cục (RenderIndexedSemantics) bằng cách đảm bảo GridView có giới hạn kích thước
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          // RẤT QUAN TRỌNG: Đảm bảo GridView có thể Scroll (phần tử cha là SingleChildScrollView)
          // và không xung đột kích thước với cha nó.
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), // Ngăn GridView scroll độc lập
          itemCount: postDocs.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2, childAspectRatio: 1.0),
          itemBuilder: (context, index) {
            final doc = postDocs[index];
            final postData = doc.data() as Map<String, dynamic>? ?? {};
            final String? imageUrl = postData['imageUrl'] as String?;

            final List<String> likedByList = List<String>.from(postData['likedBy'] ?? []);
            // SỬA LỖI: Cần kiểm tra an toàn cho likesCount (có thể là null)
            final int likes = (postData['likesCount'] is num ? (postData['likesCount'] as num).toInt() : likedByList.length);

            return _buildGridItem(doc.id, imageUrl, likes);
          },
        );
      },
    );
  }

// ... (Phần còn lại của code giữ nguyên) ...

  // Widget cho một item trong Grid (Cập nhật để xử lý URL null)
  Widget _buildGridItem(String postId, String? imagePathOrUrl, int likes) { // Nhận URL có thể null
    // Xác định ImageProvider (có thể null)
    final ImageProvider? imageProvider = (imagePathOrUrl != null && imagePathOrUrl.isNotEmpty && imagePathOrUrl.startsWith('http'))
        ? NetworkImage(imagePathOrUrl) : null;

    return GestureDetector(
      onTap: () => _navigateToPostDetail(postId),
      child: Container(
        decoration: BoxDecoration( color: darkSurface ), // Màu nền chờ
        // Hiển thị ảnh nếu có, ngược lại hiển thị Icon placeholder
        child: imageProvider != null
            ? Image(
          image: imageProvider,
          fit: BoxFit.cover,
          // Loading/Error builder
          loadingBuilder: (context, child, progress) => progress == null ? child : Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24))),
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: sonicSilver),
        )
            : const Icon(Icons.image_not_supported, color: sonicSilver), // Placeholder
        // Overlay hiển thị số lượt thích (Giữ nguyên)
        // child: Align(/* ... Like count overlay ... */), // Commented out for clarity, keep if needed
      ),
    );
  }


  // Hàm điều hướng đến Post Detail (Cập nhật xử lý URL null)
  Future<void> _navigateToPostDetail(String postId) async {
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (postDoc.exists && mounted) {
        Map<String, dynamic> postData = postDoc.data()!;
        postData['id'] = postDoc.id;
        // --- Xử lý postData (likes, comments, isLiked, isSaved) ---
        final currentUserId = _currentUser?.uid ?? '';
        // ... (logic counts, isLiked, isSaved)
        // --- Xóa fallback ảnh asset ---
        postData['userAvatarUrl'] = postData['userAvatarUrl']; // Chỉ lấy URL
        postData['imageUrl'] = postData['imageUrl']; // Chỉ lấy URL
        postData['locationTime'] = (postData['timestamp'] as Timestamp?) != null ? _formatTimestampAgo(postData['timestamp']) : '';

        Navigator.push( context, MaterialPageRoute(builder: (context) => PostDetailScreen(postData: postData)), );
      } else if (mounted) { /* Show error SnackBar */ }
    } catch (e) { /* Show error SnackBar */ }
  }

} // End _ProfileScreenState

// --- FullScreenImageView (Cập nhật để xử lý imageProvider null) ---
class FullScreenImageView extends StatelessWidget {
  final String? imageUrl; // Nhận URL có thể null
  final String? tag;
  const FullScreenImageView({super.key, required this.imageUrl, this.tag});

  @override
  Widget build(BuildContext context) {
    // Xác định ImageProvider (có thể null)
    final ImageProvider? imageProvider = (imageUrl != null && imageUrl!.isNotEmpty && imageUrl!.startsWith('http'))
        ? NetworkImage(imageUrl!) : null;

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.9),
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: tag ?? UniqueKey().toString(),
              child: InteractiveViewer(
                panEnabled: false, minScale: 1.0, maxScale: 4.0,
                // Hiển thị ảnh nếu có, ngược lại hiển thị Icon lỗi
                child: imageProvider != null
                    ? Image(image: imageProvider, fit: BoxFit.contain)
                    : const Icon(Icons.broken_image, size: 60, color: sonicSilver),
              ),
            ),
          ),
          // ...
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: IconButton( // Sửa lỗi: Thêm child
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.3),
              ),
              splashRadius: 24,
            ),
          ),
        ],
      ),
// ...


    );
  }
}

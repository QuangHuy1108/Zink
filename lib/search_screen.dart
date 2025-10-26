// lib/search_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Import ProfileScreen để điều hướng đến hồ sơ người dùng
import 'profile_screen.dart';

// Import PostCard và các hằng số/hàm helper (Giả định chúng tồn tại)
// --- Giả định PostCard và _formatTimestampAgo tồn tại ---
// Constants (Giữ nguyên)
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C);
const Color activeGreen = Color(0xFF32CD32); // <--- FIX: Thêm constant thiếu

// Giả định PostCard (Đã có trong file gốc)
class PostCard extends StatelessWidget {
  final Map<String, dynamic> postData;
  final VoidCallback onStateChange;
  const PostCard({super.key, required this.postData, required this.onStateChange});

  Widget _buildImagePlaceholder(String? imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty && imageUrl.startsWith('http')) {
      return Container(height: 150, color: Colors.grey.shade800, alignment: Alignment.center, child: Text('Image URL: $imageUrl', style: const TextStyle(color: Colors.white54, fontSize: 10)));
    } else {
      return Container( height: 150, color: darkSurface, alignment: Alignment.center, child: const Icon(Icons.image_not_supported, color: sonicSilver, size: 40), );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
            color: darkSurface,
            borderRadius: BorderRadius.circular(12)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Post by: ${postData['userName'] ?? 'Người dùng'}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            _buildImagePlaceholder(postData['imageUrl']),
            const SizedBox(height: 5),
            Text(postData['postCaption'] ?? '', style: const TextStyle(color: Colors.white70)),
            Text(_formatTimestampAgo(postData['timestamp'] ?? Timestamp.now()), style: const TextStyle(color: sonicSilver, fontSize: 12)),
          ],
        )
    );
  }
}

String _formatTimestampAgo(Timestamp timestamp) {
  final DateTime dateTime = timestamp.toDate();
  final difference = DateTime.now().difference(dateTime);
  if (difference.inSeconds < 60) return '${difference.inSeconds} giây';
  if (difference.inMinutes < 60) return '${difference.inMinutes} phút';
  if (difference.inHours < 24) return '${difference.inHours} giờ';
  return '${difference.inDays} ngày';
}
// --- Kết thúc giả định ---


class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _currentQuery = ''; // Từ khóa đang nhập (dùng cho so sánh)
  String _searchQuery = ''; // Từ khóa đã gửi (dùng cho hiển thị kết quả)

  bool _hasSearched = false;
  bool _isLoading = false;
  bool _isSearching = false;

  List<Map<String, dynamic>> _userSearchResults = [];
  List<Map<String, dynamic>> _postSearchResults = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _searchController.addListener(_onSearchQueryChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchQueryChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchQueryChanged() {
    final query = _searchController.text.trim();
    if (_searchQuery != query) {
      setState(() {
        _searchQuery = query; // Sử dụng _searchQuery
        _isSearching = query.isNotEmpty;
        if (query.isEmpty) {
          _hasSearched = false;
          _userSearchResults = [];
          _postSearchResults = [];
          _isLoading = false;
        }
      });
    }
  }

  // LOGIC: Hàm này để navigate đến ProfileScreen (Đã fix lỗi undefined ProfileScreen)
  void _navigateToProfileScreen(Map<String, dynamic> userData) {
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


  // LOGIC: Thực hiện tìm kiếm TÀI KHOẢN VÀ BÀI VIẾT trên Firestore
  void _performSearch() async {
    final searchQuery = _searchController.text.trim();
    if (searchQuery.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _userSearchResults = [];
      _postSearchResults = [];
    });
    FocusScope.of(context).unfocus();

    try {
      final queryLower = searchQuery.toLowerCase();
      final currentUserId = _currentUser?.uid ?? '';

      // === 1. TÌM KIẾM TÀI KHOẢN (USERS) ===
      // FIX: Use explicit type arguments for Future.wait
      final userQuerySnapshots = await Future.wait<QuerySnapshot>([
        _firestore.collection('users')
            .where('usernameLower', isGreaterThanOrEqualTo: queryLower)
            .where('usernameLower', isLessThanOrEqualTo: '$queryLower\uf8ff')
            .limit(10)
            .get(),
        _firestore.collection('users')
            .where('nameLower', isGreaterThanOrEqualTo: queryLower)
            .where('nameLower', isLessThanOrEqualTo: '$queryLower\uf8ff')
            .limit(10)
            .get(),
      ]);

      final Map<String, Map<String, dynamic>> userResultsMap = {};
      for (final snapshot in userQuerySnapshots) {
        for (final doc in snapshot.docs) {
          if (doc.id == currentUserId) continue; // Exclude self
          final data = doc.data() as Map<String, dynamic>;
          data['uid'] = doc.id;
          userResultsMap[doc.id] = data;
        }
      }
      final finalUserResults = userResultsMap.values.toList();


      // === 2. TÌM KIẾM BÀI VIẾT (POSTS) ===
      // FIX: Use explicit type arguments for Future.wait
      final postQuerySnapshots = await Future.wait<QuerySnapshot>([
        _firestore.collection('posts')
            .where('tag', isEqualTo: '#$queryLower')
            .orderBy('timestamp', descending: true)
            .limit(10).get(),
        _firestore.collection('posts')
            .where('userNameLower', isGreaterThanOrEqualTo: queryLower)
            .where('userNameLower', isLessThanOrEqualTo: '$queryLower\uf8ff')
            .orderBy('userNameLower')
            .orderBy('timestamp', descending: true)
            .limit(10).get(),
      ]);

      final Map<String, Map<String, dynamic>> postResultsMap = {};
      for (final snapshot in postQuerySnapshots) {
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          data['isLiked'] = false;
          data['likes'] = (data['likesCount'] is num ? (data['likesCount'] as num).toInt() : 0);
          postResultsMap[doc.id] = data;
        }
      }
      final finalPostResults = postResultsMap.values.toList();
      finalPostResults.sort((a, b) {
        final aTime = (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
        final bTime = (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });


      if (mounted) {
        setState(() {
          _userSearchResults = finalUserResults;
          _postSearchResults = finalPostResults;
          _isLoading = false;
        });
      }

    } catch (e) {
      print("Lỗi tìm kiếm: $e");
      if (mounted) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã xảy ra lỗi khi tìm kiếm.'),
          backgroundColor: coralRed,
        ));
      }
    }
  }


  // WIDGET MỚI: Xây dựng một item kết quả tìm kiếm TÀI KHOẢN
  Widget _buildUserResultItem(Map<String, dynamic> userData) {
    final String userId = userData['uid'] as String? ?? '';
    final String name = userData['name'] as String? ?? 'Người dùng';
    final String username = userData['username'] as String? ?? '';
    final String? avatarUrl = userData['avatarUrl'] as String?;
    final String? bio = userData['bio'] as String?;
    final bool isFriend = false; // Thay thế bằng logic kiểm tra bạn bè thực tế

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
        subtitle: Text(
            '@$username ${bio != null && bio.isNotEmpty ? ' • $bio' : ''}',
            style: TextStyle(color: sonicSilver)
        ),
        trailing: isFriend
            ? const Icon(Icons.check, color: activeGreen)
            : ElevatedButton(
          onPressed: () {
            // TODO: Logic Gửi lời mời kết bạn
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã gửi lời mời tới $name (Mock).')));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: topazColor,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            minimumSize: const Size(0, 30),
          ),
          child: const Text('Kết bạn', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        onTap: () => _navigateToProfileScreen(userData),
      ),
    );
  }


  // WIDGET: Xây dựng nội dung Body (Updated)
  Widget _buildBodyContent(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: topazColor));
    }

    final bool noResults = _userSearchResults.isEmpty && _postSearchResults.isEmpty;

    if (_currentQuery.isEmpty && !_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, color: sonicSilver, size: 80),
            const SizedBox(height: 16),
            Text('Nhập từ khóa để tìm kiếm bài viết hoặc tài khoản', style: TextStyle(color: sonicSilver, fontSize: 16), textAlign: TextAlign.center,),
            Text('Tìm kiếm theo Tag, Tên, hoặc Username.', style: TextStyle(color: sonicSilver.withOpacity(0.7), fontSize: 14), textAlign: TextAlign.center,),
          ],
        ),
      );
    }

    if (_hasSearched && noResults) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sentiment_dissatisfied_outlined, color: sonicSilver, size: 80),
            const SizedBox(height: 16),
            Text('Không tìm thấy kết quả nào cho "$_currentQuery"', style: TextStyle(color: sonicSilver, fontSize: 16)),
          ],
        ),
      );
    }

    if (_hasSearched && !noResults) {
      // Hiển thị kết quả (Users trước, Posts sau)
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 0.0).copyWith(top: 10, bottom: 50),
        children: [
          // 1. Kết quả Tài khoản
          if (_userSearchResults.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(left: 16.0, top: 10, bottom: 8),
              child: Text('Tài khoản', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            // Sử dụng map và toList để xây dựng danh sách Widgets
            ..._userSearchResults.map((user) => _buildUserResultItem(user)).toList(),
            if (_postSearchResults.isNotEmpty) const Divider(color: darkSurface, height: 20, thickness: 8),
          ],

          // 2. Kết quả Bài viết
          if (_postSearchResults.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(left: 16.0, top: 10, bottom: 8),
              child: Text('Bài viết', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            // Xây dựng danh sách PostCard
            ..._postSearchResults.map((post) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: PostCard(
                key: ValueKey(post['id']),
                postData: post,
                onStateChange: () {},
              ),
            )).toList(),
          ],
        ],
      );
    }

    return const SizedBox.shrink(); // Trường hợp mặc định
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        // THỐNG NHẤT NÚT BACK
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
          splashRadius: 28,
        ),
        backgroundColor: Colors.black,
        elevation: 0.5, shadowColor: darkSurface,
        iconTheme: const IconThemeData(color: Colors.white),
        title: SizedBox(
          height: 40,
          child: TextField( // Ô tìm kiếm trong AppBar
            controller: _searchController,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _performSearch(),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm Tag, Tên người dùng...',
              hintStyle: TextStyle(color: sonicSilver.withOpacity(0.8), fontSize: 15),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: sonicSilver.withOpacity(0.8), size: 22),
              suffixIcon: _currentQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, color: sonicSilver, size: 18),
                onPressed: _searchController.clear,
                splashRadius: 18,
              )
                  : null,
              filled: true, fillColor: darkSurface,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
              focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: topazColor.withOpacity(0.5), width: 1.5)),
              enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ),
      ),
      body: _buildBodyContent(context),
    );
  }
}
// lib/search_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // <--- Import Auth (để lấy currentUserId)

// Import PostCard và các hằng số/hàm helper (Giả định chúng tồn tại)
// import 'feed_screen.dart'; // Cần PostCard, Constants, _formatTimestampAgo
// --- Giả định PostCard và _formatTimestampAgo tồn tại ---
// ...
// --- Giả định PostCard và _formatTimestampAgo tồn tại ---
class PostCard extends StatelessWidget {
  final Map<String, dynamic> postData;
  final VoidCallback onStateChange;
  const PostCard({super.key, required this.postData, required this.onStateChange});

  // Sửa lỗi: Di chuyển hàm helper ra ngoài build()
  Widget _buildImagePlaceholder(String? imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty && imageUrl.startsWith('http')) {
      // In a real app, use Image.network here with loading/error builders
      return Container(height: 150, color: Colors.grey.shade800, alignment: Alignment.center, child: Text('Image URL: $imageUrl', style: const TextStyle(color: Colors.white54, fontSize: 10)));
    } else {
      return Container( height: 150, color: darkSurface, alignment: Alignment.center, child: const Icon(Icons.image_not_supported, color: sonicSilver, size: 40), );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sửa lỗi: Sửa lại cấu trúc Container và Column
    return Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: darkSurface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Post by: ${postData['userName']}", style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 5),
            _buildImagePlaceholder(postData['imageUrl']), // Gọi hàm helper đã sửa
            const SizedBox(height: 5),
            Text(postData['postCaption'] ?? '', style: const TextStyle(color: Colors.white70)),
            Text(_formatTimestampAgo(postData['timestamp'] ?? Timestamp.now()), style: const TextStyle(color: sonicSilver, fontSize: 12)),
          ],
        )
    ); // Sửa lỗi: Đặt dấu ; đúng chỗ
  }
}
// ...
String _formatTimestampAgo(Timestamp timestamp) { /* ... */ return ''; }
// --- Kết thúc giả định ---


// Constants (Giữ nguyên)
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C); // Cho màu lỗi

// --- ĐÃ XÓA: Mock assets (_userAssets, _postAssets) ---


class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _currentQuery = ''; // Từ khóa đang nhập

  // Trạng thái tìm kiếm
  bool _hasSearched = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _searchResults = []; // Lưu kết quả tìm kiếm (posts)

  // Firebase instances
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

  // Listener khi text trong ô tìm kiếm thay đổi
  void _onSearchQueryChanged() {
    final query = _searchController.text.trim();
    if (_currentQuery != query) {
      setState(() {
        _currentQuery = query;
        _hasSearched = false;
        _searchResults = [];
        _isLoading = false;
      });
    }
  }

  // LOGIC: Thực hiện tìm kiếm bài viết trên Firestore
  void _performSearch() async {
    final searchQuery = _searchController.text.trim();
    if (searchQuery.isEmpty) return;

    setState(() { _isLoading = true; _hasSearched = true; _searchResults = []; });
    FocusScope.of(context).unfocus();

    try {
      final queryLower = searchQuery.toLowerCase();
      final currentUserId = _currentUser?.uid ?? '';

      // Query 1: Tìm theo Tag
      final tagQuery = _firestore.collection('posts')
          .where('tag', whereIn: ['#$searchQuery', searchQuery, '#$queryLower', queryLower])
          .orderBy('timestamp', descending: true)
          .limit(10);

      // Query 2: Tìm theo Tên người đăng
      final userQuery = _firestore.collection('posts')
          .where('userNameLower', isGreaterThanOrEqualTo: queryLower)
          .where('userNameLower', isLessThanOrEqualTo: '$queryLower\uf8ff')
          .orderBy('userNameLower')
          .orderBy('timestamp', descending: true)
          .limit(10);

      final List<QuerySnapshot> snapshots = await Future.wait([tagQuery.get(), userQuery.get()]);

      final Map<String, Map<String, dynamic>> resultsMap = {};

      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;

          // Xử lý isLiked, isSaved, counts (giữ nguyên logic)
          // ... (logic xử lý like/save/counts)
          final List<String> likedByList = List<String>.from(data['likedBy'] ?? []);
          final List<String> savedByList = List<String>.from(data['savedBy'] ?? []);
          data['isLiked'] = currentUserId.isNotEmpty && likedByList.contains(currentUserId);
          data['isSaved'] = currentUserId.isNotEmpty && savedByList.contains(currentUserId);
          data['likes'] = (data['likesCount'] is num ? (data['likesCount'] as num).toInt() : likedByList.length);
          data['comments'] = (data['commentsCount'] is num ? (data['commentsCount'] as num).toInt() : 0);
          data['shares'] = (data['sharesCount'] is num ? (data['sharesCount'] as num).toInt() : 0);


          // --- Xóa fallback ảnh asset ---
          data['userAvatarUrl'] = data['userAvatarUrl']; // Chỉ lấy URL (có thể null)
          data['imageUrl'] = data['imageUrl']; // Chỉ lấy URL (có thể null)
          data['locationTime'] = (data['timestamp'] as Timestamp?) != null ? _formatTimestampAgo(data['timestamp']) : '';


          resultsMap[doc.id] = data;
        }
      }

      final finalResults = resultsMap.values.toList();
      finalResults.sort((a, b) { /* Sắp xếp theo timestamp */ return 0; });

      if (mounted) {
        setState(() { _searchResults = finalResults; _isLoading = false; });
      }

    } catch (e) {
      print("Lỗi tìm kiếm bài viết: $e");
      // ...
      if (mounted) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã xảy ra lỗi khi tìm kiếm.'), // Sửa lỗi: Thêm content
          backgroundColor: coralRed,
        ));
      }
// ...
    }
  }

  // WIDGET: Xây dựng nội dung Body
  Widget _buildBodyContent(BuildContext context) {
    if (_isLoading) { /* Loading */ }
    if (_currentQuery.isEmpty && !_hasSearched) { /* Placeholder ban đầu */ }
    if (_hasSearched && _searchResults.isEmpty) { /* Không có kết quả */ }
    if (_hasSearched && _searchResults.isNotEmpty) {
      // Hiển thị danh sách PostCard (PostCard cần xử lý ảnh null)
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0).copyWith(top: 10),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final post = _searchResults[index];
          // PostCard sẽ nhận data với URL ảnh có thể null
          return PostCard(
              key: ValueKey(post['id']),
              postData: post,
              onStateChange: () { }
          );
        },
      );
    }
    return Container();
  }

  // --- Hàm format Timestamp (Giữ nguyên) ---
  // String _formatTimestampAgo(Timestamp timestamp) { /* ... */ }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
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
// ...
              suffixIcon: _currentQuery.isNotEmpty
                  ? IconButton(
                // Sửa lỗi: Thêm icon
                icon: const Icon(Icons.clear, color: sonicSilver, size: 18),
                // Sửa lỗi: Thêm onPressed
                onPressed: _searchController.clear,
                splashRadius: 18,
              )
                  : null,
              filled: true, fillColor: darkSurface,
// ...              filled: true, fillColor: darkSurface,
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

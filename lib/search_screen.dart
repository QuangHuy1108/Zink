import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // <--- Import Auth (để lấy currentUserId)

// Import PostCard và các hằng số/hàm helper (Giả định chúng tồn tại)
// import 'feed_screen.dart'; // Cần PostCard, Constants, _formatTimestampAgo
// --- Giả định PostCard và _formatTimestampAgo tồn tại ---
// ...
// Constants (Giữ nguyên)
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C); // Cho màu lỗi

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
        // KHÔNG reset _hasSearched và _searchResults ngay lập tức
        // Chỉ reset khi query rỗng
        if (query.isEmpty) {
          _hasSearched = false;
          _searchResults = [];
          _isLoading = false;
        }
        // else: Giữ nguyên kết quả cũ cho đến khi người dùng nhấn Search
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

      // Query 1: Tìm theo Tag (đã sửa)
      final tagQuery = _firestore.collection('posts')
      // Tìm kiếm chính xác tag (cần index)
          .where('tag', isEqualTo: '#$queryLower')
          .orderBy('timestamp', descending: true)
          .limit(10);

      // Query 2: Tìm theo Tên người đăng (đã sửa)
      // Giả định bạn đã tạo trường 'userNameLower' trong Firestore
      final userQuery = _firestore.collection('posts')
          .where('userNameLower', isGreaterThanOrEqualTo: queryLower)
          .where('userNameLower', isLessThanOrEqualTo: '$queryLower\uf8ff')
          .orderBy('userNameLower')
          .orderBy('timestamp', descending: true)
          .limit(10);

      // Query 3: Tìm theo Caption (Tùy chọn, cần index)
      // Tạm thời bỏ qua vì tìm kiếm full-text phức tạp trong Firestore

      final List<QuerySnapshot> snapshots = await Future.wait([tagQuery.get(), userQuery.get()]);

      final Map<String, Map<String, dynamic>> resultsMap = {};

      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;

          // Xử lý isLiked, isSaved, counts (giữ nguyên logic)
          final List<String> likedByList = List<String>.from(data['likedBy'] ?? []);
          final List<String> savedByList = List<String>.from(data['savedBy'] ?? []);
          data['isLiked'] = currentUserId.isNotEmpty && likedByList.contains(currentUserId);
          data['isSaved'] = currentUserId.isNotEmpty && savedByList.contains(currentUserId);
          data['likes'] = (data['likesCount'] is num ? (data['likesCount'] as num).toInt() : likedByList.length);
          data['comments'] = (data['commentsCount'] is num ? (data['commentsCount'] as num).toInt() : 0);
          data['shares'] = (data['sharesCount'] is num ? (data['sharesCount'] as num).toInt() : 0);

          data['userAvatarUrl'] = data['userAvatarUrl'];
          data['imageUrl'] = data['imageUrl'];
          data['locationTime'] = (data['timestamp'] as Timestamp?) != null ? _formatTimestampAgo(data['timestamp']) : '';


          resultsMap[doc.id] = data;
        }
      }

      final finalResults = resultsMap.values.toList();
      // Sắp xếp theo Timestamp trong bộ nhớ (để kết hợp Tag và Username)
      finalResults.sort((a, b) {
        final aTime = (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
        final bTime = (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
        return bTime.compareTo(aTime); // descending
      });

      if (mounted) {
        setState(() { _searchResults = finalResults; _isLoading = false; });
      }

    } catch (e) {
      print("Lỗi tìm kiếm bài viết: $e");
      if (mounted) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã xảy ra lỗi khi tìm kiếm.'),
          backgroundColor: coralRed,
        ));
      }
    }
  }

  // WIDGET: Xây dựng nội dung Body
  Widget _buildBodyContent(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: topazColor));
    }

    if (_currentQuery.isEmpty && !_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, color: sonicSilver, size: 80),
            const SizedBox(height: 16),
            Text('Nhập từ khóa để tìm kiếm bài viết', style: TextStyle(color: sonicSilver, fontSize: 16)),
            Text('Tìm kiếm theo Tag hoặc Tên người dùng.', style: TextStyle(color: sonicSilver.withOpacity(0.7), fontSize: 14)),
          ],
        ),
      );
    }

    if (_hasSearched && _searchResults.isEmpty) {
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

    if (_hasSearched && _searchResults.isNotEmpty) {
      // Hiển thị danh sách PostCard
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0).copyWith(top: 10, bottom: 50),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final post = _searchResults[index];
          // Giả định PostCard chấp nhận tất cả các trường dữ liệu cần thiết
          return PostCard(
              key: ValueKey(post['id']),
              postData: post,
              onStateChange: () { }
          );
        },
      );
    }

    return const SizedBox.shrink(); // Trường hợp mặc định
  }

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

// lib/reels_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import các màn hình/widgets liên quan (Giả định tồn tại hoặc định nghĩa trong file)
// ... (Phần giả định các lớp giữ nguyên) ...


// Constants
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C);

// =======================================================
// WIDGET CHUNG: Reel Header (Cập nhật Avatar)
// =======================================================
Widget _buildReelHeader(BuildContext context, Map<String, dynamic> reelData, bool isFollowing, VoidCallback onFollowTap, VoidCallback onAvatarTap) {
  final String userName = reelData['userName'] ?? 'Người dùng';
  final String? avatarUrl = reelData['userAvatarUrl'] as String?;
  final bool canFollow = reelData['uid'] != FirebaseAuth.instance.currentUser?.uid;

  final ImageProvider? avatarProvider = (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
      ? NetworkImage(avatarUrl)
      : null;

  return GestureDetector(
    onTap: onAvatarTap,
    child: Row(
      children: [
        Stack(
          clipBehavior: Clip.none, alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: darkSurface,
              backgroundImage: avatarProvider,
              child: avatarProvider == null ? const Icon(Icons.person_outline, size: 18, color: sonicSilver) : null,
            ),
            // Nút Follow (+)
            if (canFollow && !isFollowing)
              Positioned(
                right: -4, bottom: -4,
                child: GestureDetector(
                  onTap: onFollowTap,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: topazColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: const Icon(Icons.add, size: 12, color: Colors.black),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(width: 8),
        // Chữ "Follow"
        if (canFollow && !isFollowing)
          GestureDetector(
            onTap: onFollowTap,
            child: const Text('Theo dõi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
      ],
    ),
  );
}

// =======================================================
// WIDGET ReelItem (ĐÃ SỬA LỖI NULL CHECK)
// =======================================================
class ReelItem extends StatefulWidget {
  final DocumentSnapshot reelDoc;
  final int index;
  final Stream<DocumentSnapshot>? myUserDataStream; // Giữ nguyên kiểu nullable

  const ReelItem({ super.key, required this.reelDoc, required this.index, required this.myUserDataStream });

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  late Map<String, dynamic> _reelData;
  late String _reelId;
  late bool _isLiked;
  late bool _isSaved;
  late bool _isFollowingUser;
  late int _likesCount;
  late int _commentsCount;
  late int _sharesCount;

  late AnimationController _likeAnimController;
  late Animation<double> _likeAnimation;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _initializeStateFromDoc();

    _likeAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _likeAnimation = Tween<double>(begin: 0.8, end: 1.5).animate(
      CurvedAnimation(parent: _likeAnimController, curve: Curves.elasticOut),
    )..addListener(() { setState(() {}); });
  }

  void _initializeStateFromDoc() {
    _reelData = widget.reelDoc.data() as Map<String, dynamic>? ?? {};
    _reelId = widget.reelDoc.id;
    final currentUserId = _currentUser?.uid ?? '';
    final List<String> likedByList = List<String>.from(_reelData['likedBy'] ?? []);
    final List<String> savedByList = List<String>.from(_reelData['savedBy'] ?? []);
    _isLiked = currentUserId.isNotEmpty && likedByList.contains(currentUserId);
    _isSaved = currentUserId.isNotEmpty && savedByList.contains(currentUserId);
    _likesCount = (_reelData['likesCount'] is num ? (_reelData['likesCount'] as num).toInt() : likedByList.length);
    _commentsCount = (_reelData['commentsCount'] is num ? (_reelData['commentsCount'] as num).toInt() : 0);
    _sharesCount = (_reelData['sharesCount'] is num ? (_reelData['sharesCount'] as num).toInt() : 0);
    _isFollowingUser = false;
  }

  @override
  void didUpdateWidget(covariant ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reelDoc.id != oldWidget.reelDoc.id || widget.reelDoc.data() != oldWidget.reelDoc.data()) {
      _initializeStateFromDoc();
      _likeAnimController.reset();
    }
  }

  @override
  void dispose() { _likeAnimController.dispose(); super.dispose(); }

  // --- Các hàm _toggleLike, _toggleSave, _toggleFollow, _showShareSheet, _showCommentSheet, _showMoreOptions, _navigateToUserProfile giữ nguyên logic Firestore ---
  // Bên trong _ReelItemState
  void _toggleLike() {
    if (_currentUser == null) return;
    final userId = _currentUser!.uid;

    // 1. Cập nhật UI ngay lập tức để người dùng thấy phản hồi
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _likesCount++;
        _likeAnimController.forward(from: 0); // Kích hoạt animation
      } else {
        _likesCount--;
      }
    });

    // 2. Cập nhật dữ liệu trên Firestore ở chế độ nền
    final reelRef = _firestore.collection('reels').doc(_reelId);
    final updateData = {
      'likedBy': _isLiked ? FieldValue.arrayUnion([userId]) : FieldValue.arrayRemove([userId]),
      'likesCount': FieldValue.increment(_isLiked ? 1 : -1),
    };

    reelRef.update(updateData).catchError((error) {
      // Nếu có lỗi, rollback lại thay đổi trên UI để đảm bảo tính nhất quán
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked; // Đảo ngược lại
          _isLiked ? _likesCount++ : _likesCount--;
        });
      }
      print("Lỗi cập nhật like: $error");
    });
  }
  void _toggleSave() {
    if (_currentUser == null) return;
    final userId = _currentUser!.uid;
    // 1. Cập nhật UI ngay lập tức
    setState(() {
    _isSaved = !_isSaved;
    });
    // 2. Cập nhật dữ liệu trên Firestore
    final reelRef = _firestore.collection('reels').doc(_reelId);
    final updateData = {
    'savedBy': _isSaved ? FieldValue.arrayUnion([userId]) : FieldValue.arrayRemove([userId]),
    };
    reelRef.update(updateData).catchError((error) {
    // Nếu có lỗi, rollback lại thay đổi trên UI
    if (mounted) {
    setState(() {
    _isSaved = !_isSaved; // Đảo ngược lại
    });
    }
    print("Lỗi cập nhật save: $error");
    });
  }
  // Bên trong _ReelItemState
  void _toggleFollow() async {
    if (_currentUser == null) return;
    final currentUserId = _currentUser!.uid;
    final targetUserId = _reelData['uid'];

    if (currentUserId == targetUserId) return; // Không thể tự theo dõi chính mình

    // 1. Cập nhật UI ngay lập tức
    setState(() {
      _isFollowingUser = !_isFollowingUser;
    });

    // 2. Chuẩn bị batch write để cập nhật cả hai tài liệu
    final WriteBatch batch = _firestore.batch();
    final myUserRef = _firestore.collection('users').doc(currentUserId);
    final targetUserRef = _firestore.collection('users').doc(targetUserId);

    if (_isFollowingUser) {
      // Thêm target vào ds "following" của tôi
      batch.update(myUserRef, {'following': FieldValue.arrayUnion([targetUserId])});
      // Thêm tôi vào ds "followers" của target
      batch.update(targetUserRef, {'followers': FieldValue.arrayUnion([currentUserId])});
    } else {
      // Xóa target khỏi ds "following" của tôi
      batch.update(myUserRef, {'following': FieldValue.arrayRemove([targetUserId])});
      // Xóa tôi khỏi ds "followers" của target
      batch.update(targetUserRef, {'followers': FieldValue.arrayRemove([currentUserId])});
    }

    // 3. Thực thi batch
    await batch.commit().catchError((error){
      // Nếu có lỗi, rollback lại UI
      if(mounted) {
        setState(() {
          _isFollowingUser = !_isFollowingUser;
        });
      }
      print("Lỗi cập nhật follow: $error");
    });
  }

  void _showShareSheet(BuildContext context) { /* ... */ }
  void _showCommentSheet(BuildContext context) { /* ... */ }
  void _showMoreOptions(BuildContext context) { /* ... Placeholder ... */ }
  void _navigateToUserProfile() { /* ... */ }


  @override
  Widget build(BuildContext context) {
    final String userName = _reelData['userName'] ?? 'Người dùng';
    final String description = _reelData['desc'] ?? '';
    final String? imageUrl = _reelData['imageUrl'] as String?;

    final ImageProvider? backgroundImageProvider = (imageUrl != null && imageUrl.isNotEmpty && imageUrl.startsWith('http'))
        ? NetworkImage(imageUrl)
        : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Ảnh/Video nền
        GestureDetector(
          onDoubleTap: _toggleLike,
          child: Container(
            color: darkSurface,
            child: backgroundImageProvider != null
                ? Image(
              image: backgroundImageProvider,
              fit: BoxFit.cover,
              loadingBuilder:(context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator(color: sonicSilver, strokeWidth: 2));
              },
              errorBuilder: (context, error, stackTrace) {
                print("Lỗi tải ảnh reel background: $error");
                return const Center(child: Icon(Icons.movie_filter_outlined, color: sonicSilver, size: 60));
              },
            )
                : Center(
              child: Text('REEL ${widget.index + 1}', style: TextStyle(color: sonicSilver, fontSize: 30, fontWeight: FontWeight.bold)),
            ),
          ),
        ),

        // Double-tap Like Animation (Giữ nguyên)
        if (_likeAnimController.isAnimating || _likeAnimController.value > 0)
          Center(
            child: Transform.scale(
              scale: _likeAnimation.value,
              child: Opacity(
                opacity: 1.0 - _likeAnimController.value,
                child: const Icon(Icons.favorite, color: Colors.white, size: 100),
              ),
            ),
          ),

        // Gradient overlay (Giữ nguyên)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.3), Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.7)],
              stops: const [0.0, 0.2, 0.7, 1.0],
            ),
          ),
        ),

        // 2. Nội dung và Tương tác (Dưới cùng)
        Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 15, left: 16, right: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // --- Cột trái: Thông tin Reel ---
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header (Avatar, Tên, Nút Follow) - StreamBuilder SỬA LỖI NULL CHECK
                    StreamBuilder<DocumentSnapshot>(
                        stream: widget.myUserDataStream,
                        builder: (context, myDataSnapshot) {
                          // SỬA LỖI NULL CHECK: Lấy data an toàn
                          final myData = myDataSnapshot.data?.data() as Map<String, dynamic>?;

                          bool amIFollowing = false;
                          if (myData != null) {
                            // KIỂM TRA AN TOÀN following LIST
                            final List<String> following = List<String>.from(myData['following'] ?? []);
                            amIFollowing = following.contains(_reelData['uid']);
                          }

                          // Cập nhật state cục bộ _isFollowingUser
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _isFollowingUser != amIFollowing) {
                              setState(() { _isFollowingUser = amIFollowing; });
                            }
                          });

                          // Gọi _buildReelHeader đã cập nhật
                          return _buildReelHeader(context, _reelData, amIFollowing, _toggleFollow, _navigateToUserProfile);
                        }
                    ),
                    const SizedBox(height: 10),
                    // Description (Giữ nguyên)
                    if (description.isNotEmpty) Text(description, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(width: 5),

              // --- Cột phải: Nút Tương tác (Giữ nguyên) ---
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInteractionButton(
                      icon: _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _isLiked ? coralRed : Colors.white,
                      count: _likesCount,
                      onTap: _toggleLike
                  ),
                  const SizedBox(height: 18),
                  _buildInteractionButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      color: Colors.white,
                      count: _commentsCount,
                      onTap: () => _showCommentSheet(context)
                  ),
                  const SizedBox(height: 18),
                  _buildInteractionButton(
                      icon: Icons.send_rounded,
                      color: Colors.white,
                      count: _sharesCount,
                      onTap: () => _showShareSheet(context)
                  ),
                  const SizedBox(height: 18),
                  _buildInteractionButton(
                      icon: _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: _isSaved ? topazColor : Colors.white,
                      count: 0, // Không hiển thị số lượt lưu
                      onTap: _toggleSave
                  ),
                  const SizedBox(height: 18),
                  _buildInteractionButton(
                      icon: Icons.more_horiz,
                      color: Colors.white,
                      count: 0,
                      onTap: () => _showMoreOptions(context)
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper widget cho các nút tương tác (Giữ nguyên)
  Widget _buildInteractionButton({ /* ... */ required IconData icon, required Color color, required int count, required VoidCallback onTap }) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: color, size: 28),
          onPressed: onTap,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          splashRadius: 24,
        ),
        if (count > 0)
          Text(_formatCount(count), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // Helper format số lượng lớn (Giữ nguyên)
  String _formatCount(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

} // End _ReelItemState


// =======================================================
// WIDGET CHÍNH: REELS SCREEN (ĐÃ SỬA LỖI HOT RELOAD)
// =======================================================
class ReelsScreen extends StatefulWidget {
  final VoidCallback onNavigateToHome;
  const ReelsScreen({required this.onNavigateToHome, super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  // KHỞI TẠO STREAM CỤC BỘ (Giữ nguyên kiểu nullable)
  Stream<DocumentSnapshot>? _myUserDataStream;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;

    // SỬA LỖI: CUNG CẤP GIÁ TRỊ NON-NULL HOẶC STREAM.EMPTY()
    // Đảm bảo Stream.empty() được gán nếu user là null, khắc phục lỗi hot reload.
    _myUserDataStream = _currentUser != null
        ? _firestore.collection('users').doc(_currentUser!.uid).snapshots()
        : Stream.empty(); // Stream an toàn
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. PAGEVIEW CHỨA CÁC REEL (StreamBuilder giữ nguyên)
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('reels').orderBy('timestamp', descending: true).limit(20).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: topazColor));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Lỗi tải Reels: ${snapshot.error}', style: const TextStyle(color: coralRed)));
              }

              final reelDocs = snapshot.data?.docs ?? [];
              if (reelDocs.isEmpty) {
                return const Center(child: Text('Chưa có Reels nào được đăng.', style: TextStyle(color: sonicSilver)));
              }

              return PageView.builder(
                scrollDirection: Axis.vertical,
                itemCount: reelDocs.length,
                itemBuilder: (context, index) {
                  // ReelItem nhận được stream an toàn
                  return ReelItem(
                    key: ValueKey(reelDocs[index].id),
                    reelDoc: reelDocs[index],
                    index: index,
                    myUserDataStream: _myUserDataStream,
                  );
                },
              );
            },
          ),

          // 2. HEADER NỔI (Giữ nguyên)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10, left: 10, right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: widget.onNavigateToHome,
                  splashRadius: 24,
                ),
                const Text('Reels', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.photo_camera_outlined, color: Colors.white),
                  onPressed: () { /* TODO: Navigate to create reel */ },
                  splashRadius: 24,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
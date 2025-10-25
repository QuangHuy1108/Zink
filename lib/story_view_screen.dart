// lib/story_view_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore để dùng Timestamp
import 'dart:async'; // Import để dùng Timer nếu cần cho progress bar

// Import StoryContent model (Giả định nó tồn tại)
// import 'models.dart' show StoryContent; // Chỉ import StoryContent
// --- Giả định StoryContent tồn tại ---
class StoryContent {
  final String text;
  final Offset textPosition;
  final String song;
  final Offset songPosition;
  final String location;
  final List<String> taggedFriends;
  StoryContent({
    required this.text,
    required this.textPosition,
    required this.song,
    required this.songPosition,
    required this.location,
    required this.taggedFriends,
  });
  factory StoryContent.fromFirestoreData(Map<String, dynamic> data) {
    // Triển khai logic parse thật từ data Firestore
    return StoryContent(
      text: data['text'] ?? '',
      textPosition: Offset((data['textPosition']?['dx'] as num?)?.toDouble() ?? 50, (data['textPosition']?['dy'] as num?)?.toDouble() ?? 200),
      song: data['song'] ?? '',
      songPosition: Offset((data['songPosition']?['dx'] as num?)?.toDouble() ?? 50, (data['songPosition']?['dy'] as num?)?.toDouble() ?? 100),
      location: data['location'] ?? '',
      taggedFriends: List<String>.from(data['taggedFriends'] ?? []),
    );
  }
}
// --- Kết thúc giả định ---

// Constants (Giữ nguyên)
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C);

class StoryViewScreen extends StatefulWidget {
  final String userName; // Tên người đăng story
  final String? avatarUrl; // URL Avatar người đăng (có thể null)
  final List<DocumentSnapshot> storyDocs;

  const StoryViewScreen({
    super.key,
    required this.userName,
    this.avatarUrl,
    required this.storyDocs,
  });

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> with SingleTickerProviderStateMixin {
  int _currentStoryIndex = 0;
  bool _isLiked = false;
  final TextEditingController _messageController = TextEditingController();

  // Animation/Drag State
  double _dragY = 0.0;
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Timer for progress bar (Optional but recommended)
  Timer? _progressTimer;
  double _currentProgress = 0.0;
  static const Duration _storyDuration = Duration(seconds: 5); // Thời gian hiển thị mỗi story

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animation = Tween<double>(begin: 0.0, end: MediaQuery.of(context).size.height).animate(_animationController)
          ..addListener(_updateDragY);
        _startStoryTimer(); // Bắt đầu timer cho story đầu tiên
      }
    });
    // TODO: Lấy trạng thái like ban đầu
  }

  @override
  void dispose() {
    _progressTimer?.cancel(); // Hủy timer
    // Kiểm tra listener trước khi remove
    // if (_animation != null) _animation.removeListener(_updateDragY); // Gây lỗi nếu _animation chưa khởi tạo
    if (_animationController.isAnimating || _animationController.value > 0) { // Check if listener exists
      // Kiểm tra xem _animation đã được khởi tạo chưa
      // Đoạn này có thể phức tạp hơn nếu addPostFrameCallback chưa chạy
      // Cách an toàn hơn là dùng biến bool để theo dõi
      try {
        _animation.removeListener(_updateDragY);
      } catch (e) {
        // Bỏ qua lỗi nếu listener chưa được thêm
      }
    }
    _animationController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _startStoryTimer() {
    _progressTimer?.cancel(); // Hủy timer cũ nếu có
    setState(() { _currentProgress = 0.0; }); // Reset progress
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _currentProgress += 50 / _storyDuration.inMilliseconds;
        if (_currentProgress >= 1.0) {
          timer.cancel();
          _nextStory(); // Tự động chuyển story
        }
      });
    });
  }

  void _pauseTimer() => _progressTimer?.cancel();
  void _resumeTimer() {
    if (_currentProgress < 1.0) _startStoryTimer(); // Chỉ resume nếu chưa xong
  }


  // --- Logic Animation Kéo-Thả ---
  void _updateDragY() { setState(() { if(mounted) _dragY = _animation.value; });}
  void _handleDragUpdate(DragUpdateDetails details) {
    _pauseTimer(); // Tạm dừng khi kéo
    double newDragY = _dragY + details.delta.dy;
    // Giới hạn kéo lên/xuống một chút để tránh đóng nhầm
    setState(() { _dragY = newDragY.clamp(-50.0, MediaQuery.of(context).size.height * 0.8); });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragY > MediaQuery.of(context).size.height * 0.3 || details.velocity.pixelsPerSecond.dy > 300) {
      // Kéo đủ xa hoặc đủ nhanh -> Đóng màn hình
      Navigator.pop(context);
    } else {
      // Không đủ -> Trả về vị trí cũ và resume timer
      _animationController.reverse(); // Hoặc setState trực tiếp _dragY = 0
      setState(() { _dragY = 0.0; });
      _resumeTimer();
    }
  }

  // Chuyển story
  void _moveToStory(int index) {
    if (index >= 0 && index < widget.storyDocs.length) {
      setState(() {
        _currentStoryIndex = index;
        _isLiked = false; // Reset like
        _messageController.clear();
        // TODO: Lấy trạng thái like thật
      });
      _startStoryTimer(); // Bắt đầu timer cho story mới
    } else if (index >= widget.storyDocs.length) {
      Navigator.pop(context); // Đóng nếu hết story
    }
  }

  void _nextStory() => _moveToStory(_currentStoryIndex + 1);
  void _previousStory() => _moveToStory(_currentStoryIndex - 1);


  // Logic Like Story
  void _likeStory() {
    final currentStoryId = widget.storyDocs[_currentStoryIndex].id;
    print("Like/Unlike action on story ID: $currentStoryId");
    // TODO: Cập nhật Firestore

    setState(() { _isLiked = !_isLiked; });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isLiked ? 'Đã thích tin!' : 'Đã bỏ thích tin.'),
        backgroundColor: _isLiked ? topazColor : sonicSilver,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // Logic Share Story (Placeholder)
  void _shareStory() {
    _pauseTimer();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chức năng chia sẻ chưa có.')));
    // _resumeTimer(); // Có thể resume sau khi SnackBar ẩn
  }


  // Logic Gửi Tin nhắn (Placeholder)
  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    _pauseTimer();
    print("Gửi tin nhắn: $message");
    _messageController.clear();
    FocusScope.of(context).unfocus(); // Ẩn bàn phím
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi tin nhắn (chưa triển khai).')));
    // _resumeTimer();
  }


  // Sửa lỗi: Triển khai hàm này (lỗi 22-25 trước đó)
  Widget _buildFixedContentWidget({
    required String content,
    required Offset position,
    required TextStyle style,
    Color shadowColor = Colors.black,
  }) {
    if (content.isEmpty) return const SizedBox.shrink();
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [ BoxShadow( color: shadowColor.withOpacity(0.7), blurRadius: 5, spreadRadius: 2, ) ],
        ),
        child: Text( content, textAlign: TextAlign.center, style: style, ),
      ),
    );
  }

  // Header Story
  // Sửa lỗi: Truyền tham số thay vì dùng widget/_currentStoryIndex trực tiếp (lỗi 3-11)
  Widget _buildStoryHeader(
      BuildContext context,
      ImageProvider? avatarProvider,
      String userName,
      int storyCount,
      int currentIndex,
      double currentProgress, // Thêm progress
      ) {
    // Thời gian đăng (lấy từ story hiện tại) - Cần lấy timestamp thật
    final Timestamp? timestamp = (widget.storyDocs[currentIndex].data() as Map<String, dynamic>?)?['timestamp'];
    final String timeAgo = timestamp != null ? _formatTimestampAgo(timestamp) : 'Vừa xong'; // Hàm helper format

    return Column(
      children: [
        // 1. Progress Bars
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0), // Sửa lỗi: Triển khai Padding
          child: Row( // Sửa lỗi: Thêm child
            children: List.generate(storyCount, (index) {
              double progressValue = 0.0;
              if (index < currentIndex) progressValue = 1.0;
              // Sửa lỗi: Sử dụng _currentProgress cho thanh hiện tại
              else if (index == currentIndex) progressValue = currentProgress;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0), // Sửa lỗi: Thêm padding
                  // Sửa lỗi: Triển khai LinearProgressIndicator
                  child: LinearProgressIndicator(
                    value: progressValue,
                    backgroundColor: Colors.white30,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 2.5,
                  ),
                ),
              );
            }),
          ),
        ),

        // 2. User Info & Menu
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row( // User info + Time
                children: [
                  CircleAvatar( radius: 18, backgroundImage: avatarProvider, backgroundColor: darkSurface, child: avatarProvider == null ? const Icon(Icons.person_outline, size: 18, color: sonicSilver) : null, ),
                  const SizedBox(width: 8),
                  Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text(timeAgo, style: const TextStyle(color: sonicSilver, fontSize: 12)), // Hiển thị thời gian thật
                ],
              ),
              // MENU 3 CHẤM
              // Sửa lỗi: Triển khai PopupMenuButton (lỗi 12)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                color: darkSurface,
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(value: 'report', child: Text('Báo cáo tin')),
                  // Thêm các tùy chọn khác nếu cần
                ],
                onSelected: (String value) {
                  _pauseTimer(); // Dừng khi mở menu
                  // TODO: Xử lý logic báo cáo
                  // _resumeTimer(); // Resume sau khi xử lý xong
                },
                onCanceled: () {
                  _resumeTimer(); // Resume nếu hủy menu
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Hàm helper format thời gian
  String _formatTimestampAgo(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final difference = DateTime.now().difference(dateTime);
    if (difference.inSeconds < 60) return '${difference.inSeconds} giây';
    if (difference.inMinutes < 60) return '${difference.inMinutes} phút';
    if (difference.inHours < 24) return '${difference.inHours} giờ';
    return '${difference.inDays} ngày';
  }

  // Input Tương tác
  // Sửa lỗi: Triển khai Container (lỗi 2)
  Widget _buildInteractionInput() {
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 10.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + paddingBottom + 10,
      ),
      color: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                onTap: _pauseTimer, // Dừng timer khi focus vào TextField
                onTapOutside: (_) => _resumeTimer(), // Resume khi unfocus
                decoration: InputDecoration(
                  hintText: 'Gửi tin nhắn...',
                  hintStyle: TextStyle(color: sonicSilver.withOpacity(0.7), fontSize: 14),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.4),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: Icon( _isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? coralRed : Colors.white, size: 28, ),
            onPressed: _likeStory,
            style: IconButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.4)),
            splashRadius: 24,
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 28),
            onPressed: _shareStory,
            style: IconButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.4)),
            splashRadius: 24,
          ),
        ],
      ),
    );
  }

  // Sửa lỗi: Triển khai phương thức build (lỗi 1, 13-21, 26)
  @override
  Widget build(BuildContext context) {
    if (widget.storyDocs.isEmpty) {
      // Trường hợp không có story nào được truyền vào
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('Không có tin nào để hiển thị.', style: TextStyle(color: sonicSilver))),
        appBar: AppBar(backgroundColor: Colors.black, leading: BackButton(color: Colors.white)),
      );
    }
    // Đảm bảo index hợp lệ
    if (_currentStoryIndex >= widget.storyDocs.length) {
      // Có thể xảy ra nếu danh sách story thay đổi đột ngột
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }


    final currentStoryDoc = widget.storyDocs[_currentStoryIndex];
    final storyData = currentStoryDoc.data() as Map<String, dynamic>? ?? {};
    final String? imageUrl = storyData['imageUrl'] as String?;
    final StoryContent currentStoryContent = StoryContent.fromFirestoreData(storyData);
    final ImageProvider? backgroundImageProvider = (imageUrl != null && imageUrl.isNotEmpty && imageUrl.startsWith('http'))
        ? NetworkImage(imageUrl)
        : null;
    final ImageProvider? avatarProvider = (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty && widget.avatarUrl!.startsWith('http'))
        ? NetworkImage(widget.avatarUrl!)
        : null;

    final paddingTop = MediaQuery.of(context).padding.top;
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    final size = MediaQuery.of(context).size; // Kích thước màn hình

    return Scaffold(
      backgroundColor: Colors.transparent, // Để thấy màn hình phía sau khi kéo
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        // GestureDetector bao ngoài cùng để xử lý kéo đóng và tap chuyển story
        onVerticalDragUpdate: _handleDragUpdate,
        onVerticalDragEnd: _handleDragEnd,
        onTapDown: (details) {
          _pauseTimer(); // Dừng khi chạm
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth * 0.3) {
            _previousStory();
          } else if (details.globalPosition.dx > screenWidth * 0.7) {
            _nextStory();
          }
        },
        onTapUp: (_) => _resumeTimer(), // Tiếp tục khi nhả tay
        onTapCancel: _resumeTimer, // Tiếp tục nếu tap bị hủy

        child: Transform.translate(
          offset: Offset(0, _dragY), // Áp dụng vị trí kéo
          child: Stack(
            children: [
              // 1. STORY CONTENT BACKGROUND
              Container( // Không cần GestureDetector ở đây nữa
                width: double.infinity, height: double.infinity,
                color: darkSurface,
                child: backgroundImageProvider != null
                    ? Image( image: backgroundImageProvider, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.image_not_supported, color: sonicSilver, size: 60)), )
                    : const Center(child: Icon(Icons.image_not_supported, color: sonicSilver, size: 60)),
              ),

              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.5), Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.7)],
                    stops: const [0.0, 0.2, 0.7, 1.0],
                  ),
                ),
              ),

              // 2. HEADER VÀ THANH PROGRESS
              Positioned(
                top: paddingTop, left: 16, right: 16,
                // Sửa lỗi: Truyền tham số vào _buildStoryHeader
                child: _buildStoryHeader(
                  context,
                  avatarProvider,
                  widget.userName,
                  widget.storyDocs.length,
                  _currentStoryIndex,
                  _currentProgress, // Truyền progress hiện tại
                ),
              ),

              // 3. HIỂN THỊ NỘI DUNG STORY
              // Sửa lỗi: Gọi hàm với đủ tham số (lỗi 22-25)
              _buildFixedContentWidget(
                content: currentStoryContent.text,
                position: currentStoryContent.textPosition,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              _buildFixedContentWidget(
                content: currentStoryContent.song.isNotEmpty ? '🎶 ${currentStoryContent.song}' : '',
                position: currentStoryContent.songPosition,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (currentStoryContent.location.isNotEmpty || currentStoryContent.taggedFriends.isNotEmpty)
                Positioned(
                    bottom: paddingBottom + 80, // Vị trí cố định
                    left: 16, right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration( color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(20), ),
                      child: Row( /* ... Nội dung Location & Tags ... */ ), // Triển khai Row này nếu cần
                    )
                ),

              // 4. INPUT VÀ TƯƠNG TÁC
              Align( alignment: Alignment.bottomCenter, child: _buildInteractionInput()),
            ],
          ),
        ),
      ),
    );
  }
} // <--- Dấu } này kết thúc lớp _StoryViewScreenState
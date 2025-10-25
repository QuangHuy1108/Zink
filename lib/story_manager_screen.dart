// lib/story_manager_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- Giả định các lớp này tồn tại ---
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

  factory StoryContent.fromFirestoreData(Map<String, dynamic> data) =>
      StoryContent(
        text: data['text'] ?? '',
        textPosition: Offset(20, 100),
        song: data['song'] ?? '',
        songPosition: Offset(20, 200),
        location: data['location'] ?? '',
        taggedFriends: List<String>.from(data['taggedFriends'] ?? []),
      );
}

class FullScreenImageView extends StatelessWidget {
  final String? imageUrl;
  final String? tag;
  const FullScreenImageView({super.key, this.imageUrl, this.tag});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black.withOpacity(0.9),
    body: Center(
      child: imageUrl != null
          ? Text("Full Screen: $imageUrl",
          style: const TextStyle(color: Colors.white))
          : const Icon(Icons.broken_image, color: Colors.grey),
    ),
  );
}

// --- Constants ---
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C);

class StoryManagerScreen extends StatefulWidget {
  const StoryManagerScreen({super.key});

  @override
  State<StoryManagerScreen> createState() => _StoryManagerScreenState();
}

class _StoryManagerScreenState extends State<StoryManagerScreen>
    with SingleTickerProviderStateMixin {
  int _currentStoryIndex = 0;
  List<DocumentSnapshot> _myActiveStories = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  Stream<QuerySnapshot>? _storiesStream;

  double _dragY = 0.0;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _initializeStream();

    _animationController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  void _initializeStream() {
    if (_currentUser != null) {
      _storiesStream = _firestore
          .collection('stories')
          .where('userId', isEqualTo: _currentUser!.uid)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .orderBy('timestamp', descending: false)
          .snapshots();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // --- Widget hiển thị text cố định trong story ---
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
          boxShadow: [
            BoxShadow(
              color: shadowColor.withOpacity(0.7),
              blurRadius: 5,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Text(
          content,
          textAlign: TextAlign.center,
          style: style,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final paddingTop = MediaQuery.of(context).padding.top;
    final paddingBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: _storiesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _myActiveStories.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Lỗi khi tải stories',
                  style: TextStyle(color: Colors.red)),
            );
          }

          if (snapshot.hasData) {
            _myActiveStories = snapshot.data!.docs;
          }

          if (_myActiveStories.isEmpty) {
            return const Center(
              child: Text('Chưa có story nào',
                  style: TextStyle(color: Colors.white)),
            );
          }

          if (_currentStoryIndex >= _myActiveStories.length) {
            _currentStoryIndex = _myActiveStories.length - 1;
          }

          final currentStoryDoc = _myActiveStories[_currentStoryIndex];
          final storyData =
              currentStoryDoc.data() as Map<String, dynamic>? ?? {};
          final String? imageUrl = storyData['imageUrl'] as String?;
          final storyContent = StoryContent.fromFirestoreData(storyData);

          final ImageProvider? backgroundImageProvider =
          (imageUrl != null && imageUrl.isNotEmpty)
              ? NetworkImage(imageUrl)
              : null;

          return GestureDetector(
            child: Stack(
              children: [
                // Ảnh nền story
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: darkSurface,
                  child: backgroundImageProvider != null
                      ? Image(
                    image: backgroundImageProvider,
                    fit: BoxFit.cover,
                  )
                      : const Center(
                    child: Icon(Icons.image_not_supported,
                        color: sonicSilver, size: 60),
                  ),
                ),

                // Header
                Positioned(
                  top: paddingTop,
                  left: 16,
                  right: 16,
                  child: _buildStoryHeader(context, storyData),
                ),

                // Text
                _buildFixedContentWidget(
                  content: storyContent.text,
                  position: storyContent.textPosition,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                ),

                // Bài hát
                _buildFixedContentWidget(
                  content: storyContent.song.isNotEmpty
                      ? '🎶 ${storyContent.song}'
                      : '',
                  position: storyContent.songPosition,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),

                // Vị trí / bạn bè
                if (storyContent.location.isNotEmpty ||
                    storyContent.taggedFriends.isNotEmpty)
                  Positioned(
                    bottom: paddingBottom + 80,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (storyContent.location.isNotEmpty) ...[
                            const Icon(Icons.location_on,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(storyContent.location,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13)),
                          ],
                          if (storyContent.location.isNotEmpty &&
                              storyContent.taggedFriends.isNotEmpty)
                            const Text(' - ',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 13)),
                          if (storyContent.taggedFriends.isNotEmpty) ...[
                            const Icon(Icons.person,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              storyContent.taggedFriends.length == 1
                                  ? storyContent.taggedFriends.first
                                  : '${storyContent.taggedFriends.length} người bạn',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                // Nút menu
                Positioned(
                  top: paddingTop + 10,
                  right: 16,
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        color: Colors.white, size: 28),
                    color: darkSurface,
                    itemBuilder: (BuildContext context) => const [
                      PopupMenuItem<String>(
                          value: 'download', child: Text('Tải xuống')),
                      PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Xóa tin',
                              style: TextStyle(color: coralRed))),
                    ],
                    onSelected: (String value) {
                      if (value == 'delete') {
                        // TODO: delete logic
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStoryHeader(BuildContext context, Map<String, dynamic> storyData) {
    final Timestamp expiresAt = storyData['expiresAt'] ??
        Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24)));
    final Duration timeLeft =
    expiresAt.toDate().difference(DateTime.now());
    final String timeLeftString = timeLeft.isNegative
        ? 'Đã hết hạn'
        : '${timeLeft.inHours} giờ còn lại';

    final String? avatarUrl = storyData['userAvatarUrl'] as String?;
    final ImageProvider? avatarProvider =
    (avatarUrl != null && avatarUrl.isNotEmpty)
        ? NetworkImage(avatarUrl)
        : null;

    return Column(
      children: [
        // Progress bar
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
          child: Row(
            children: List.generate(_myActiveStories.length, (index) {
              double progressValue = 0.0;
              if (index < _currentStoryIndex) progressValue = 1.0;
              else if (index == _currentStoryIndex) progressValue = 0.5;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
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
        // Avatar + time left
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: avatarProvider,
              backgroundColor: darkSurface,
              child: avatarProvider == null
                  ? const Icon(Icons.person, color: sonicSilver, size: 18)
                  : null,
            ),
            const SizedBox(width: 8),
            const Text('Tin của bạn',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(timeLeftString,
                style: const TextStyle(color: sonicSilver, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

// --- Hằng số màu ---
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C);

// =======================================================
// Widget con: Giao diện Chia sẻ Story
// =======================================================
class _ShareStorySheetContent extends StatefulWidget {
  final String storyId;
  final Map<String, dynamic> storyData;
  final String storyOwnerName;

  const _ShareStorySheetContent({required this.storyId, required this.storyData, required this.storyOwnerName});

  @override
  State<_ShareStorySheetContent> createState() => _ShareStorySheetContentState();
}

class _ShareStorySheetContentState extends State<_ShareStorySheetContent> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Stream<List<DocumentSnapshot>>? _friendsStream;
  final Map<String, bool> _sentStatus = {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  void _loadFriends() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final userDocStream = _firestore.collection('users').doc(currentUser.uid).snapshots();
    
    _friendsStream = userDocStream.asyncMap((userDoc) async {
      if (!userDoc.exists) return [];
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      final List<String> friendUids = List<String>.from(userData['friendUids'] ?? []);
      if (friendUids.isEmpty) return [];

      final friendDocs = await Future.wait(
        friendUids.map((uid) => _firestore.collection('users').doc(uid).get())
      );
      return friendDocs.where((doc) => doc.exists).toList();
    });
  }

  Future<void> _sendStoryToFriend(String friendId, String friendName) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    setState(() => _sentStatus[friendId] = true);

    final WriteBatch batch = _firestore.batch();
    final chatId = (currentUser.uid.hashCode <= friendId.hashCode) ? '${currentUser.uid}_$friendId' : '${friendId}_${currentUser.uid}';
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();

    batch.set(messageRef, {
      'senderId': currentUser.uid,
      'text': 'Đã chia sẻ một tin', 
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'messageType': 'story_share',
      'storyContext': { 
        'storyId': widget.storyId,
        'storyOwnerName': widget.storyOwnerName,
        'imageUrl': widget.storyData['imageUrl'], 
        'text': widget.storyData['text'] 
      }
    });
    batch.set(chatRef, {'lastMessage': 'Đã chia sẻ một tin', 'lastMessageTimestamp': FieldValue.serverTimestamp(), 'participants': [currentUser.uid, friendId]}, SetOptions(merge: true));

    try { await batch.commit(); } catch (e) { if(mounted) { setState(() => _sentStatus.remove(friendId)); } }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7, minChildSize: 0.5, maxChildSize: 0.9,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(color: darkSurface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            Container(width: 40, height: 5, margin: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: sonicSilver.withOpacity(0.5), borderRadius: BorderRadius.circular(12))),
            const Text('Chia sẻ đến', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(color: sonicSilver, height: 20),
            Expanded(child: StreamBuilder<List<DocumentSnapshot>>(
              stream: _friendsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: topazColor));
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Bạn chưa có bạn bè nào.', style: TextStyle(color: sonicSilver)));
                final friends = snapshot.data!;
                return ListView.builder(
                  controller: controller,
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friendData = friends[index].data() as Map<String, dynamic>;
                    final friendId = friends[index].id;
                    final name = friendData['name'] ?? 'Người dùng';
                    final avatarUrl = friendData['avatarUrl'] as String?;
                    final isSent = _sentStatus[friendId] == true;
                    return ListTile(
                      leading: CircleAvatar(backgroundImage: (avatarUrl != null ? NetworkImage(avatarUrl) : null)),
                      title: Text(name, style: const TextStyle(color: Colors.white)),
                      trailing: ElevatedButton(
                        onPressed: isSent ? null : () => _sendStoryToFriend(friendId, name),
                        style: ElevatedButton.styleFrom(backgroundColor: isSent ? Colors.grey[700] : topazColor, foregroundColor: isSent ? Colors.white70 : Colors.black),
                        child: Text(isSent ? 'Đã gửi' : 'Gửi'),
                      ),
                    );
                  },
                );
              },
            )),
          ]),
        );
      },
    );
  }
}


// =======================================================
// Màn hình hiển thị danh sách người đã thích Story
// =======================================================
class StoryViewersScreen extends StatelessWidget {
  final String storyId;
  const StoryViewersScreen({super.key, required this.storyId});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5, minChildSize: 0.3, maxChildSize: 0.9,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: const BoxDecoration(color: darkSurface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            Container(width: 40, height: 5, margin: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: sonicSilver.withOpacity(0.5), borderRadius: BorderRadius.circular(12))),
            const Text('Lượt thích', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(color: sonicSilver, height: 20),
            Expanded(child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('stories').doc(storyId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: Text('Chưa có lượt thích nào.', style: TextStyle(color: sonicSilver)));
                final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                final List<String> likedByUids = List<String>.from(data['likedBy'] ?? []);
                if (likedByUids.isEmpty) return const Center(child: Text('Chưa có lượt thích nào.', style: TextStyle(color: sonicSilver)));
                return ListView.builder(
                  controller: scrollController,
                  itemCount: likedByUids.length,
                  itemBuilder: (context, index) {
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(likedByUids[index]).get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) return const ListTile(title: Text('Đang tải...', style: TextStyle(color: sonicSilver)));
                        final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                        final String name = userData['name'] ?? 'Người dùng';
                        final String? avatarUrl = userData['avatarUrl'];
                        final ImageProvider? avatar = (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) ? NetworkImage(avatarUrl) : null;
                        return ListTile(leading: CircleAvatar(backgroundImage: avatar, backgroundColor: darkSurface), title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), trailing: const Icon(Icons.favorite, color: coralRed, size: 20));
                      },
                    );
                  },
                );
              },
            )),
          ]),
        );
      },
    );
  }
}

// =======================================================
// Widget hiển thị nội dung của một trang Story
// =======================================================
class _StoryPageItem extends StatelessWidget {
  final Map<String, dynamic> storyData;
  const _StoryPageItem({required this.storyData});

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = storyData['imageUrl'] as String?;
    final String storyText = storyData['text'] as String? ?? '';
    final Map<String, dynamic>? textPosMap = storyData['textPosition'] as Map<String, dynamic>?;
    final Offset textPosition = (textPosMap != null) ? Offset((textPosMap['dx'] as num).toDouble(), (textPosMap['dy'] as num).toDouble()) : const Offset(50, 200);
    final ImageProvider? imageProvider = (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null;

    return Stack(fit: StackFit.expand, children: [
      Container(color: darkSurface, child: imageProvider != null ? Image(image: imageProvider, fit: BoxFit.cover, loadingBuilder: (context, child, progress) => (progress == null) ? child : const Center(child: CircularProgressIndicator(color: topazColor)), errorBuilder: (c, e, s) => const Center(child: Icon(Icons.error_outline, color: coralRed, size: 40))) : null),
      if (storyText.isNotEmpty) Positioned(left: textPosition.dx, top: textPosition.dy, child: Text(storyText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 5.0, color: Colors.black54, offset: Offset(2.0, 2.0))]))),
    ]);
  }
}


// =======================================================
// Màn hình chính: StoryViewScreen
// =======================================================
class StoryViewScreen extends StatefulWidget {
  final String userName;
  final String? avatarUrl;
  final List<DocumentSnapshot> storyDocs;
  const StoryViewScreen({super.key, required this.userName, this.avatarUrl, required this.storyDocs});

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  late PageController _pageController; 
  late AnimationController _animationController;
  int _currentIndex = 0; 
  final Map<int, bool> _isLikedMap = {};

  @override
  void initState() { 
    super.initState();
    _currentUser = _auth.currentUser; 
    _pageController = PageController(); 
    _animationController = AnimationController(vsync: this);
    _animationController.addStatusListener((status) { 
      if (status == AnimationStatus.completed) _onTapNext(); 
    });
    _playStoryAtIndex(0);
  }
  
  @override
  void dispose() { 
    _animationController.dispose(); 
    _pageController.dispose(); 
    super.dispose(); 
  }

  void _playStoryAtIndex(int index) { 
    if (index >= widget.storyDocs.length) return;
    final storyData = widget.storyDocs[index].data() as Map<String, dynamic>? ?? {}; 
    final durationSeconds = (storyData['duration'] as num?)?.toInt() ?? 7; 
    _animationController.stop(); 
    _animationController.reset(); 
    _animationController.duration = Duration(seconds: durationSeconds); 
    _animationController.forward(); 
    _markStoryAsSeen(index); 
    _updateLikeStatus(index); 
  }
  
  void _updateLikeStatus(int index) { 
    if (index >= widget.storyDocs.length) return;
    final storyData = widget.storyDocs[index].data() as Map<String, dynamic>? ?? {}; 
    final List<String> likedBy = List<String>.from(storyData['likedBy'] ?? []); 
    if(mounted) setState(() => _isLikedMap[index] = likedBy.contains(_currentUser?.uid)); 
  }
  
  void _onPageChanged(int index) { 
    setState(() => _currentIndex = index); 
    _playStoryAtIndex(index); 
  }
  
  void _onTapDown(TapDownDetails details, BuildContext context) { 
    final screenWidth = MediaQuery.of(context).size.width; 
    if (details.globalPosition.dx < screenWidth / 3) { 
      _onTapPrevious(); 
    } else { 
      _onTapNext(); 
    } 
  }
  
  void _onTapNext() { 
    if (_currentIndex < widget.storyDocs.length - 1) { 
      _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeIn); 
    } else { 
      Navigator.of(context).pop(); 
    } 
  }
  
  void _onTapPrevious() { 
    if (_currentIndex > 0) { 
      _pageController.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeIn); 
    } else { 
      _playStoryAtIndex(0); 
    } 
  }
  
  void _pauseStory() => _animationController.stop();
  
  void _resumeStory() => _animationController.forward();
  
  void _markStoryAsSeen(int index) async { 
    if (_currentUser == null || index >= widget.storyDocs.length) return;
    final storyId = widget.storyDocs[index].id;
    final storyRef = _firestore.collection('stories').doc(storyId);
    try { 
      await storyRef.update({'viewedBy': FieldValue.arrayUnion([_currentUser!.uid])}); 
    } catch (e) { 
      /* Lỗi không quan trọng, bỏ qua */ 
    } 
  }

  void _toggleLike() async { 
    if (_currentUser == null || _currentIndex >= widget.storyDocs.length) return;
    final storyDoc = widget.storyDocs[_currentIndex];
    final storyData = storyDoc.data() as Map<String, dynamic>? ?? {};
    final storyOwnerId = storyData['userId'];
    final bool isCurrentlyLiked = _isLikedMap[_currentIndex] ?? false;
    setState(() => _isLikedMap[_currentIndex] = !isCurrentlyLiked);
    final WriteBatch batch = _firestore.batch();
    final storyRef = _firestore.collection('stories').doc(storyDoc.id);
    if (!isCurrentlyLiked) { 
      batch.update(storyRef, {'likedBy': FieldValue.arrayUnion([_currentUser!.uid])}); 
      if (storyOwnerId != null && storyOwnerId != _currentUser!.uid) { 
        final notificationRef = _firestore.collection('users').doc(storyOwnerId).collection('notifications').doc(); 
        batch.set(notificationRef, { 'type': 'story_like', 'senderId': _currentUser!.uid, 'senderName': _currentUser!.displayName ?? 'Một người dùng', 'destinationId': storyDoc.id, 'timestamp': FieldValue.serverTimestamp(), 'isRead': false, 'contentPreview': 'đã thích tin của bạn.' }); 
      } 
    } else { 
      batch.update(storyRef, {'likedBy': FieldValue.arrayRemove([_currentUser!.uid])}); 
    } 
    try { 
      await batch.commit(); 
    } catch(e) { 
      if(mounted) setState(() => _isLikedMap[_currentIndex] = isCurrentlyLiked); 
    } 
  }
  
  void _sendReply(String message) async { 
    if (_currentUser == null || _currentIndex >= widget.storyDocs.length) return;
    final storyDoc = widget.storyDocs[_currentIndex];
    final storyData = storyDoc.data() as Map<String, dynamic>? ?? {};
    final storyOwnerId = storyData['userId'] as String?;
    if (storyOwnerId == null || storyOwnerId == _currentUser!.uid) return;
    final WriteBatch batch = _firestore.batch();
    final notificationRef = _firestore.collection('users').doc(storyOwnerId).collection('notifications').doc();
    batch.set(notificationRef, { 'type': 'story_reply', 'senderId': _currentUser!.uid, 'senderName': _currentUser!.displayName ?? 'Người dùng', 'senderAvatarUrl': _currentUser!.photoURL ?? '', 'destinationId': storyDoc.id, 'contentPreview': message, 'timestamp': FieldValue.serverTimestamp(), 'isRead': false, });
    final chatId = (_currentUser!.uid.hashCode <= storyOwnerId.hashCode) ? '${_currentUser!.uid}_$storyOwnerId' : '${storyOwnerId}_${_currentUser!.uid}';
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();
    batch.set(messageRef, { 'senderId': _currentUser!.uid, 'text': message, 'timestamp': FieldValue.serverTimestamp(), 'isRead': false, 'storyContext': { 'storyId': storyDoc.id, 'imageUrl': storyData['imageUrl'], 'text': storyData['text'] } });
    batch.set(chatRef, {'lastMessage': message, 'lastMessageTimestamp': FieldValue.serverTimestamp(), 'participants': [_currentUser!.uid, storyOwnerId]}, SetOptions(merge: true));
    try { 
      await batch.commit(); 
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi tin nhắn.'))); 
    } catch(e) { 
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi: Không thể gửi tin nhắn.'), backgroundColor: coralRed)); 
    } 
  }

  void _showReplySheet() { 
    _pauseStory(); 
    final replyController = TextEditingController(); 
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => 
      Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom), 
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
      decoration: const BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.vertical(top: Radius.circular(20))), 
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: TextField(controller: replyController, autofocus: true, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Trả lời ${widget.userName}...', hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)), border: InputBorder.none), textInputAction: TextInputAction.send, onSubmitted: (value) { if (value.trim().isNotEmpty) { _sendReply(value.trim()); Navigator.pop(ctx); } },)), 
        IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: () { final message = replyController.text.trim(); if (message.isNotEmpty) { _sendReply(message); Navigator.pop(ctx); } })
      ])))
    ).whenComplete(_resumeStory); 
  }

  void _showShareSheet() { 
    _pauseStory(); 
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => 
      _ShareStorySheetContent(storyId: widget.storyDocs[_currentIndex].id, storyData: widget.storyDocs[_currentIndex].data() as Map<String, dynamic>, storyOwnerName: widget.userName)
    ).whenComplete(_resumeStory); 
  }
  
  void _deleteStory() async { 
    _pauseStory(); 
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => 
      AlertDialog(backgroundColor: darkSurface, title: const Text('Xóa tin', style: TextStyle(color: Colors.white)), content: const Text('Bạn có chắc chắn muốn xóa tin này vĩnh viễn không?', style: TextStyle(color: sonicSilver)), actions: [
        TextButton(child: const Text('Hủy', style: TextStyle(color: sonicSilver)), onPressed: () => Navigator.of(ctx).pop(false)), 
        TextButton(child: const Text('Xóa', style: TextStyle(color: coralRed)), onPressed: () => Navigator.of(ctx).pop(true))
      ])); 
    if (confirm == true) { 
      try { 
        await _firestore.collection('stories').doc(widget.storyDocs[_currentIndex].id).delete(); 
        if (mounted) Navigator.of(context).pop(); 
      } catch (e) { 
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi: Không thể xóa tin.'), backgroundColor: coralRed)); 
      } 
    } 
    _resumeStory(); 
  }
  
  void _reportStory() { 
    Navigator.pop(context); 
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cảm ơn bạn đã báo cáo.'))); 
  }
  
  void _unfollowUser() { 
    Navigator.pop(context); 
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã bỏ theo dõi người dùng này.'))); 
  }
  
  void _muteStories() { 
    Navigator.pop(context); 
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã ẩn tin từ người dùng này.'))); 
  }

  void _showStoryOptions() { 
    _pauseStory(); 
    final currentStoryData = widget.storyDocs[_currentIndex].data() as Map<String, dynamic>? ?? {}; 
    final bool isMyStory = currentStoryData['userId'] == _currentUser?.uid; 
    showModalBottomSheet(context: context, backgroundColor: darkSurface, builder: (ctx) => 
      SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [ 
        if (isMyStory) ListTile(leading: const Icon(Icons.delete_outline, color: coralRed), title: const Text('Xóa tin này', style: TextStyle(color: coralRed)), onTap: () { Navigator.pop(ctx); _deleteStory(); }), 
        if (!isMyStory) ...[ 
          ListTile(leading: const Icon(Icons.report_problem_outlined, color: Colors.white), title: const Text('Báo cáo tin'), onTap: _reportStory), 
          ListTile(leading: const Icon(Icons.person_remove_outlined, color: Colors.white), title: Text('Bỏ theo dõi ${widget.userName}'), onTap: _unfollowUser), 
          ListTile(leading: const Icon(Icons.volume_off_outlined, color: Colors.white), title: Text('Ẩn tin từ ${widget.userName}'), onTap: _muteStories), 
        ], 
        const Divider(color: sonicSilver, height: 1), 
        ListTile(leading: const Icon(Icons.close, color: sonicSilver), title: const Text('Hủy'), onTap: () => Navigator.of(ctx).pop()), 
      ]))
    ).whenComplete(_resumeStory); 
  }
  
  void _showLikers() { 
    _pauseStory(); 
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => 
      StoryViewersScreen(storyId: widget.storyDocs[_currentIndex].id)
    ).whenComplete(_resumeStory); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _onTapDown(details, context),
        onLongPress: _pauseStory,
        onLongPressUp: _resumeStory,
        child: Stack(children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.storyDocs.length,
            itemBuilder: (context, index) {
              final data = widget.storyDocs[index].data() as Map<String, dynamic>? ?? {};
              return _StoryPageItem(storyData: data);
            },
          ),
          _buildFixedContentWidget(),
        ]),
      ),
    );
  }

  Widget _buildStoryHeader() {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5)),
        child: CircleAvatar(radius: 16, backgroundImage: (widget.avatarUrl != null ? NetworkImage(widget.avatarUrl!) : null), backgroundColor: darkSurface),
      ),
      const SizedBox(width: 10),
      Text(widget.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(width: 8),
      // SỬA: Hiển thị thời gian thực tế hơn (nếu có)
      if (widget.storyDocs.isNotEmpty && _currentIndex < widget.storyDocs.length)
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('stories').doc(widget.storyDocs[_currentIndex].id).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Text('', style: TextStyle(color: sonicSilver));
            final storyData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final timestamp = storyData['timestamp'] as Timestamp?;
            return Text(timestamp != null ? _formatTimestamp(timestamp) : '', style: const TextStyle(color: sonicSilver));
          }
        ),
      const Spacer(),
      IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: _showStoryOptions, splashRadius: 20),
      IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(context).pop(), splashRadius: 20),
    ]);
  }
  
  String _formatTimestamp(Timestamp timestamp) {
    final difference = DateTime.now().difference(timestamp.toDate());
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    return '${difference.inDays}d';
  }

  Widget _buildFixedContentWidget() {
    if (widget.storyDocs.isEmpty || _currentIndex >= widget.storyDocs.length) return const SizedBox.shrink();
    final storyData = widget.storyDocs[_currentIndex].data() as Map<String, dynamic>? ?? {};
    final int likeCount = (storyData['likedBy'] as List?)?.length ?? 0;
    final bool isMyStory = storyData['userId'] == _currentUser?.uid;

    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Column(children: [
            Row(children: widget.storyDocs.asMap().entries.map((entry) { 
              return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), 
              child: AnimatedBuilder(animation: _animationController, builder: (context, child) { 
                return LinearProgressIndicator(value: (_currentIndex == entry.key) ? _animationController.value : ((_currentIndex > entry.key) ? 1.0 : 0.0), backgroundColor: Colors.white.withOpacity(0.5), valueColor: const AlwaysStoppedAnimation<Color>(Colors.white)); 
              }))); 
            }).toList()),
            const SizedBox(height: 8),
            _buildStoryHeader(),
            const Spacer(),
            Row(children: [
              if (!isMyStory) Expanded(child: GestureDetector(onTap: _showReplySheet, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 1.5), borderRadius: BorderRadius.circular(30)), child: const Text('Gửi tin nhắn', style: TextStyle(color: Colors.white))))),
              if (isMyStory) const Spacer(),
              if (!isMyStory) IconButton(icon: Icon(_isLikedMap[_currentIndex] ?? false ? Icons.favorite : Icons.favorite_border, color: _isLikedMap[_currentIndex] ?? false ? Colors.red : Colors.white), onPressed: _toggleLike),
              IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _showShareSheet),
            ]),
            const SizedBox(height: 10),
            if (isMyStory)
              GestureDetector(onTap: (likeCount > 0) ? _showLikers : null, child: Text(likeCount > 0 ? '$likeCount lượt thích' : 'Chưa có lượt thích nào', style: TextStyle(color: Colors.white, fontSize: 13, decoration: (likeCount > 0) ? TextDecoration.underline : TextDecoration.none)))
            else 
              const SizedBox(height: 15.5),
          ]),
        ),
      ),
    );
  }
}

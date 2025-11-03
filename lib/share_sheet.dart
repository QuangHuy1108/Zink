import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // <--- Import Auth

// Constants (Giữ nguyên)
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C); // Có thể dùng cho lỗi

class ShareSheetContent extends StatefulWidget {
  final String postId; // ID của Post hoặc Reel
  final String postUserName; // Tên người đăng
  final int initialShares; // Số lượt chia sẻ hiện tại
  final Function(int) onSharesUpdated; // Callback để cập nhật UI cha
  // final String postType; // Tùy chọn: 'post' hoặc 'reel'

  const ShareSheetContent({
    super.key,
    required this.postId,
    required this.postUserName,
    required this.initialShares,
    required this.onSharesUpdated,
    // this.postType = 'post',
  });

  @override
  State<ShareSheetContent> createState() => _ShareSheetContentState();
}

class _ShareSheetContentState extends State<ShareSheetContent> {
  final TextEditingController _thoughtsController = TextEditingController();
  final TextEditingController _friendMessageController = TextEditingController();
  Set<String> _selectedFriendUids = {}; // Lưu UID của bạn bè được chọn

  late int _sharesCount; // State cục bộ

  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  Stream<QuerySnapshot>? _friendsStream;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _sharesCount = widget.initialShares;
    _loadFriends();
  }

  // Hàm tải danh sách bạn bè từ Firestore (Hoàn thiện logic)
  void _loadFriends() {
    if (_currentUser == null) return;
    _firestore.collection('users').doc(_currentUser!.uid).snapshots().listen((userDoc) {
      if (!mounted) return;
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>? ?? {};
        final List<String> friendUids = List<String>.from(userData['friendUids'] ?? []);
        if (friendUids.isNotEmpty) {
          final queryUids = friendUids.length > 30 ? friendUids.sublist(0, 30) : friendUids;
          if (friendUids.length > 30) print("Warning: Share sheet chỉ hiển thị tối đa 30 bạn bè.");
          setState(() {
            // Sử dụng whereIn để lấy chi tiết bạn bè
            _friendsStream = _firestore.collection('users').where(FieldPath.documentId, whereIn: queryUids).snapshots();
          });
        } else {
          setState(() { _friendsStream = Stream.empty(); });
        }
      } else {
        setState(() { _friendsStream = Stream.empty(); });
      }
    }, onError: (error) {
      print("Lỗi tải friendUids: $error");
      if (mounted) setState(() { _friendsStream = Stream.empty(); });
    });
  }


  @override
  void dispose() {
    _thoughtsController.dispose();
    _friendMessageController.dispose();
    super.dispose();
  }

  // Toggle chọn/bỏ chọn bạn bè (Hoàn thiện logic)
  void _toggleFriendSelection(String friendUid) {
    setState(() {
      if (_selectedFriendUids.contains(friendUid)) {
        _selectedFriendUids.remove(friendUid);
      } else {
        _selectedFriendUids.add(friendUid);
      }
    });
  }

  // Hàm tăng share count (Hoàn thiện logic Firestore)
  Future<void> _incrementShares() async {
    try {
      final postRef = _firestore.collection('posts').doc(widget.postId);
      await postRef.update({'sharesCount': FieldValue.increment(1)});

      setState(() {
        _sharesCount++;
      });
      widget.onSharesUpdated(_sharesCount);

    } catch (e) {
      print("Lỗi cập nhật sharesCount: $e");
    }
  }

  // ----------------------------------------------------
  // --- PHẦN 1: CHIA SẺ LÊN TRANG CÁ NHÂN (Hoàn thiện) ---
  // ----------------------------------------------------
  // --- (SỬA) CHIA SẺ LÊN TRANG CÁ NHÂN VÀ GỬI THÔNG BÁO ---
  void _shareToProfile() async {
    final thoughts = _thoughtsController.text.trim();
    final user = _currentUser;
    if (user == null) return;

    // Bắt đầu một batch write để thực hiện nhiều tác vụ
    final WriteBatch batch = _firestore.batch();
    final postRef = _firestore.collection('posts').doc(widget.postId);

    try {
      // 1. Lấy dữ liệu người dùng hiện tại và bài viết gốc
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final originalPostDoc = await postRef.get();

      if (!userDoc.exists || !originalPostDoc.exists) {
        print("Lỗi: Không tìm thấy người dùng hoặc bài viết gốc.");
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final originalPostData = originalPostDoc.data() as Map<String, dynamic>;

      final displayName = userData['displayName'] ?? 'Người dùng Zink';
      final photoURL = userData['photoURL'];
      final postOwnerId = originalPostData['uid'] as String?;

      // 2. Cập nhật lượt chia sẻ trên bài viết gốc
      batch.update(postRef, {'sharesCount': FieldValue.increment(1)});

      // 3. Tạo một bài đăng "chia sẻ" mới
      final newPostRef = _firestore.collection('posts').doc();
      batch.set(newPostRef, {
        'uid': user.uid,
        'displayName': displayName,
        'userAvatarUrl': photoURL,
        'postCaption': thoughts.isNotEmpty ? 'Đã chia sẻ: $thoughts' : 'Đã chia sẻ bài viết của ${widget.postUserName}.',
        'sharedPostId': widget.postId,
        'imageUrl': null,
        'likesCount': 0, 'commentsCount': 0, 'sharesCount': 0,
        'likedBy': [], 'savedBy': [], 'privacy': 'Công khai',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 4. Tạo thông báo cho chủ bài viết (nếu người chia sẻ không phải là chủ)
      if (postOwnerId != null && postOwnerId != user.uid) {
        final notificationRef = _firestore.collection('users').doc(postOwnerId).collection('notifications').doc();
        batch.set(notificationRef, {
          'type': 'share',
          'senderId': user.uid,
          'senderName': displayName,
          'senderAvatarUrl': photoURL,
          'destinationId': widget.postId, // ID của bài viết được chia sẻ
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      // 5. Thực thi tất cả các lệnh
      await batch.commit();

      if (mounted) {
        // Cập nhật UI ở màn hình trước
        setState(() { _sharesCount++; });
        widget.onSharesUpdated(_sharesCount);

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã chia sẻ lên Trang cá nhân!'), backgroundColor: topazColor));
        Navigator.pop(context);
      }

    } catch (e) {
      print("Lỗi khi chia sẻ bài viết: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi khi chia sẻ bài viết.'), backgroundColor: coralRed));
    }
  }  Widget _buildShareToProfileSection() {
    // Lấy avatar user hiện tại (URL hoặc null)
    final String? currentUserAvatarUrl = _currentUser?.photoURL;
    final ImageProvider? avatarProvider = (currentUserAvatarUrl != null && currentUserAvatarUrl.isNotEmpty)
        ? NetworkImage(currentUserAvatarUrl)
        : null; // Không còn fallback AssetImage

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chia sẻ lên Trang cá nhân', style: TextStyle(color: topazColor, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar( // Avatar đã xử lý null
                radius: 20,
                backgroundImage: avatarProvider, // Có thể null
                backgroundColor: darkSurface,
                // Hiển thị Icon nếu không có ảnh
                child: avatarProvider == null ? const Icon(Icons.person, color: sonicSilver, size: 20) : null,
              ),
              const SizedBox(width: 12),
              // ...
              Expanded( // TextField cảm nghĩ
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _thoughtsController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Bạn đang nghĩ gì?',
                      hintStyle: TextStyle(color: sonicSilver.withOpacity(0.7), fontSize: 14),
                      filled: true,
                      fillColor: darkSurface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Nút Đăng (Post)
              SizedBox(
                width: 40,
                height: 40,
                child: ElevatedButton(
                  onPressed: _shareToProfile, // <-- GỌI HÀM SHARE TO PROFILE
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: topazColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Icon(Icons.send_rounded, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // --- PHẦN 2: GỬI CHO BẠN BÈ (Hoàn thiện logic) ---
  // --------------------------------------------------
  void _sendMessageToFriends() async {
    final message = _friendMessageController.text.trim();
    if (_selectedFriendUids.isEmpty || _currentUser == null) return;

    // 1. Tăng share count trên bài post gốc
    await _incrementShares();

    // 2. Lấy dữ liệu người gửi (là bạn) từ Firestore
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
    String senderName = 'Bạn';
    if(userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;
      senderName = userData['displayName'] ?? 'Bạn';
    }

    // 3. Gửi tin nhắn (Placeholder cho logic chat)
    final recipientCount = _selectedFriendUids.length;
    print("Gửi bài viết ${widget.postId} tới $recipientCount bạn bè bởi $senderName.");
    print("Tin nhắn kèm theo: $message");

    // TODO: Triển khai logic tạo đoạn chat/tin nhắn thực tế cho từng người dùng.

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Đã gửi bài viết tới $recipientCount bạn bè.'),
        backgroundColor: topazColor,
      ));
      Navigator.pop(context);
    }
  }
  Widget _buildShareToFriendsSection() {
    final bool hasFriendsSelected = _selectedFriendUids.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16.0, top: 16.0, bottom: 10.0),
          child: Text(
            'Gửi cho Bạn bè',
            style: TextStyle(color: topazColor, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),

        SizedBox(
          height: 90,
          child: StreamBuilder<QuerySnapshot>(
            stream: _friendsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && _friendsStream != Stream.empty()) {
                return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: sonicSilver)));
              }
              if (snapshot.hasError) { return const Center(child: Text('Lỗi tải bạn bè.', style: TextStyle(color: coralRed, fontSize: 12))); }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) { return const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Bạn chưa có bạn bè nào.', style: TextStyle(color: sonicSilver, fontSize: 12)))); }

              final friendDocs = snapshot.data!.docs;
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: friendDocs.length,
                itemBuilder: (context, index) {
                  final doc = friendDocs[index];
                  final friendData = doc.data() as Map<String, dynamic>;
                  final friendUid = doc.id;
                  // SỬA THÀNH ĐOẠN NÀY:
                  final friendName = friendData['displayName'] ?? 'Bạn bè';
                  final avatarUrl = friendData['photoURL'] as String?;
                  final isSelected = _selectedFriendUids.contains(friendUid);

                  final ImageProvider? avatarProvider = (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
                      ? NetworkImage(avatarUrl) : null;

                  return GestureDetector(
                    onTap: () => _toggleFriendSelection(friendUid),
                    child: Container(
                      width: 65, margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              if (isSelected) CircleAvatar(radius: 27, backgroundColor: topazColor),
                              CircleAvatar(
                                radius: 25,
                                backgroundColor: darkSurface,
                                backgroundImage: avatarProvider,
                                child: avatarProvider == null ? const Icon(Icons.person, color: sonicSilver, size: 25) : null,
                              ),
                              if (isSelected)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: topazColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check, size: 12, color: Colors.black),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            friendName.split(' ').first,
                            style: TextStyle(
                              color: isSelected ? Colors.white : sonicSilver,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Friend Message Input
        if (hasFriendsSelected)
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 10.0),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _friendMessageController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Viết tin nhắn...',
                        hintStyle: TextStyle(color: sonicSilver.withOpacity(0.7), fontSize: 14),
                        filled: true,
                        fillColor: darkSurface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _sendMessageToFriends, // <-- GỌI HÀM GỬI TIN NHẮN
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    backgroundColor: topazColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    minimumSize: const Size(0, 40),
                  ),
                  child: const Text('Gửi', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ----------------------------------------------------
  // --- PHẦN 3: TÙY CHỌN KHÁC (Hoàn thiện logic) ---
  // ----------------------------------------------------
  Widget _buildOtherOptionsSection() {
    final List<Map<String, dynamic>> options = [
      {'icon': Icons.copy_rounded, 'label': 'Sao chép liên kết'},
      {'icon': Icons.messenger_outline_rounded, 'label': 'Gửi bằng Messenger'},
      {'icon': Icons.share_rounded, 'label': 'Chia sẻ lên ứng dụng khác'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16.0, top: 10, bottom: 0),
          child: Text('Tùy chọn khác', style: TextStyle(color: topazColor, fontSize: 14, fontWeight: FontWeight.bold)),
        ),
        ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: options.length,
            itemBuilder: (context, index){
              final option = options[index];
              return ListTile(
                leading: Icon(option['icon'], color: Colors.white, size: 24),
                title: Text(option['label'], style: const TextStyle(color: Colors.white, fontSize: 15)),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
                onTap: () {
                  // Mock logic sao chép/chia sẻ
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã sao chép liên kết (Mô phỏng).'))
                  );
                  _incrementShares(); // Tăng count shares khi người dùng chia sẻ ra ngoài
                  Navigator.pop(context);
                },
              );
            }
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: darkSurface, width: 0.5)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5), // Tăng maxHeight
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              decoration: BoxDecoration(
                color: darkSurface,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // Tiêu đề số lượt chia sẻ (Nếu cần)
          // Text('$_sharesCount lượt chia sẻ', style: TextStyle(color: sonicSilver)),
          const Divider(color: darkSurface, height: 1, thickness: 1),

          // Sheet Content (Scrollable)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildShareToProfileSection(), // Hoàn thiện
                  const Divider(color: darkSurface, height: 1, thickness: 1),
                  _buildShareToFriendsSection(), // Hoàn thiện
                  const Divider(color: darkSurface, height: 1, thickness: 1),
                  _buildOtherOptionsSection(), // Hoàn thiện
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

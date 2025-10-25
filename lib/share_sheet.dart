// lib/share_sheet.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // <--- Import Auth

// Constants (Giữ nguyên)
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C); // Có thể dùng cho lỗi

// --- ĐÃ XÓA: class Friend ---

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

  // Hàm tải danh sách bạn bè từ Firestore (Giữ nguyên logic Firestore)
  void _loadFriends() {
    if (_currentUser == null) return;
    _firestore.collection('users').doc(_currentUser!.uid).snapshots().listen((userDoc) {
      if (!mounted) return; // Check if widget is still mounted
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>? ?? {};
        final List<String> friendUids = List<String>.from(userData['friendUids'] ?? []);
        if (friendUids.isNotEmpty) {
          final queryUids = friendUids.length > 30 ? friendUids.sublist(0, 30) : friendUids;
          if (friendUids.length > 30) print("Warning: Share sheet chỉ hiển thị tối đa 30 bạn bè.");
          setState(() {
            _friendsStream = _firestore.collection('users').where(FieldPath.documentId, whereIn: queryUids).snapshots();
          });
        } else {
          setState(() { _friendsStream = null; });
        }
      }
    }, onError: (error) {
      print("Lỗi tải friendUids: $error");
      if (mounted) setState(() { _friendsStream = null; });
    });
  }


  @override
  void dispose() {
    _thoughtsController.dispose();
    _friendMessageController.dispose();
    super.dispose();
  }

  // Toggle chọn/bỏ chọn bạn bè (Giữ nguyên)
  void _toggleFriendSelection(String friendUid) { /* ... */ }

  // Hàm tăng share count (Giữ nguyên logic Firestore)
  void _incrementShares() async { /* ... */ }

  // --- PHẦN 1: CHIA SẺ LÊN TRANG CÁ NHÂN (Cập nhật Avatar) ---
  Widget _buildShareToProfileSection() {
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
                  // Sửa lỗi: Thêm onPressed
                  onPressed: () {
                    // TODO: Logic chia sẻ lên trang cá nhân
                    Navigator.pop(context); // Đóng sheet
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: topazColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  // Sửa lỗi: Thêm child
                  child: const Icon(Icons.send_rounded, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- PHẦN 2: GỬI CHO BẠN BÈ (Cập nhật Avatar) ---
  Widget _buildShareToFriendsSection() {
    final bool hasFriendsSelected = _selectedFriendUids.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // ...
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16.0, top: 16.0, bottom: 10.0), // Sửa lỗi: Thêm padding
          child: Text( // Sửa lỗi: Thêm child
            'Gửi cho Bạn bè',
            style: TextStyle(color: topazColor, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),

        // Horizontal Scrollable Friend List (Sử dụng StreamBuilder - Cập nhật Avatar)
// ...

        // Horizontal Scrollable Friend List (Sử dụng StreamBuilder - Cập nhật Avatar)
        SizedBox(
          height: 90,
          child: StreamBuilder<QuerySnapshot>(
            stream: _friendsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && _friendsStream != null) { /* Loading */ }
              if (snapshot.hasError) { /* Error */ }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) { /* No data */ }

              final friendDocs = snapshot.data!.docs;
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: friendDocs.length,
                itemBuilder: (context, index) {
                  final doc = friendDocs[index];
                  final friendData = doc.data() as Map<String, dynamic>;
                  final friendUid = doc.id;
                  final friendName = friendData['name'] ?? 'Bạn bè';
                  final avatarUrl = friendData['avatarUrl'] as String?; // Lấy URL (có thể null)
                  final isSelected = _selectedFriendUids.contains(friendUid);

                  // Xác định ImageProvider (có thể null)
                  final ImageProvider? avatarProvider = (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
                      ? NetworkImage(avatarUrl)
                      : null; // Không còn fallback AssetImage

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
                              CircleAvatar( // Avatar đã xử lý null
                                radius: 25,
                                backgroundColor: darkSurface,
                                backgroundImage: avatarProvider, // Có thể null
                                // Hiển thị Icon nếu không có ảnh
                                child: avatarProvider == null ? const Icon(Icons.person, color: sonicSilver, size: 25) : null,
                                // ...
                              ),
                              if (isSelected)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  // Sửa lỗi: Thêm child
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
                            // ...
                          ),
                          const SizedBox(height: 5),
                          // Sửa lỗi: Cung cấp String cho Text
                          Text(
                            friendName.split(' ').first, // Hiển thị tên ngắn gọn
                            style: TextStyle(
                              color: isSelected ? Colors.white : sonicSilver,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
// ...
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Friend Message Input (Giữ nguyên)
// ...
        // Friend Message Input
        if (hasFriendsSelected)
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 10.0), // Sửa lỗi: Thêm padding
            // Sửa lỗi: Thêm child (Row)
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
                  onPressed: () {
                    // TODO: Logic gửi tin nhắn cho bạn bè đã chọn
                    Navigator.pop(context); // Đóng sheet
                  },
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
// ...      ],
    );
  }

  // --- PHẦN 3: TÙY CHỌN KHÁC (Giữ nguyên UI và Placeholder logic) ---
  Widget _buildOtherOptionsSection() {
    // ... (Code danh sách options và ListTile giữ nguyên)
    final List<Map<String, dynamic>> options = [
      {'icon': Icons.copy_rounded, 'label': 'Sao chép liên kết'},
      {'icon': Icons.messenger_outline_rounded, 'label': 'Gửi bằng Messenger'},
      {'icon': Icons.share_rounded, 'label': 'Chia sẻ lên ứng dụng khác'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16.0, top: 10, bottom: 0), // Adjust padding
          child: Text('Tùy chọn khác', style: TextStyle(color: topazColor, fontSize: 14, fontWeight: FontWeight.bold)),
        ),
        ListView.builder(
            shrinkWrap: true, // Important inside Column
            physics: const NeverScrollableScrollPhysics(), // Disable scrolling of this inner list
            itemCount: options.length,
            itemBuilder: (context, index){
              final option = options[index];
              return ListTile(
                leading: Icon(option['icon'], color: Colors.white, size: 24),
                title: Text(option['label'], style: const TextStyle(color: Colors.white, fontSize: 15)),
                dense: true, // Make tiles more compact
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
                onTap: () {
                  // TODO: Implement actual sharing logic for each option
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Chức năng "${option['label']}" chưa được triển khai.'))
                  );
                  Navigator.pop(context); // Close sheet after selection
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
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      child: Column(
        // ...
        children: [
          // Drag handle
          Center( // Sửa lỗi: Thêm child (Center -> Container)
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              decoration: BoxDecoration(
                color: darkSurface, // Màu thanh kéo
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // Hiển thị số lượt chia sẻ (Giữ nguyên)
// ...
          const Divider(color: darkSurface, height: 1, thickness: 1),

          // Sheet Content (Scrollable)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildShareToProfileSection(), // Đã cập nhật avatar
                  const Divider(color: darkSurface, height: 1, thickness: 1),
                  _buildShareToFriendsSection(), // Đã cập nhật avatar
                  const Divider(color: darkSurface, height: 1, thickness: 1),
                  _buildOtherOptionsSection(), // Giữ nguyên
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

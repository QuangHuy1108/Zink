// lib/create_group_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Constants (Sử dụng lại từ file app_colors.dart)
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C);
const Color activeGreen = Color(0xFF32CD32);

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  Set<String> _selectedUids = {}; // Danh sách UID đã chọn
  bool _isLoading = false;
  String _friendSearchQuery = '';

  Stream<QuerySnapshot>? _friendsStream;

  @override
  void initState() {
    super.initState();
    _loadFriendsList();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_friendSearchQuery != _searchController.text.trim()) {
      setState(() {
        _friendSearchQuery = _searchController.text.trim();
      });
    }
  }

  void _loadFriendsList() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 1. Lấy danh sách friendUids của người dùng hiện tại
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final friendUids = List<String>.from(userDoc.data()?['friendUids'] ?? []);

    if (friendUids.isNotEmpty) {
      // 2. Tạo Stream để lấy thông tin chi tiết bạn bè
      final queryUids = friendUids.length > 30 ? friendUids.sublist(0, 30) : friendUids; // Giới hạn query
      setState(() {
        _friendsStream = _firestore.collection('users').where(FieldPath.documentId, whereIn: queryUids).snapshots();
      });
    } else {
      setState(() {
        _friendsStream = Stream.empty();
      });
    }
  }

  void _toggleSelection(String uid) {
    setState(() {
      if (_selectedUids.contains(uid)) {
        _selectedUids.remove(uid);
      } else {
        _selectedUids.add(uid);
      }
    });
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();
    final currentUser = _auth.currentUser;

    if (groupName.isEmpty || _selectedUids.isEmpty || currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng đặt tên nhóm và chọn ít nhất một thành viên.'), backgroundColor: coralRed));
      return;
    }

    if (_isLoading) return;
    setState(() => _isLoading = true);

    // Danh sách thành viên: Người tạo + các thành viên được chọn
    final List<String> allParticipants = [currentUser.uid, ..._selectedUids].toSet().toList();

    try {
      // Lấy tên người tạo
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();

      // SỬA LỖI: Ép kiểu tường minh userDoc.data() để Dart biết nó là Map
      String creatorName = (userDoc.data() as Map<String, dynamic>?)?['displayName'] ?? 'Người dùng';

      // Tạo tài liệu chat nhóm
      await _firestore.collection('chats').add({
        'isGroup': true, // <-- Dấu hiệu nhận biết Group Chat
        'groupName': groupName,
        'participants': allParticipants,
        'groupAdminId': currentUser.uid,
        'groupCreatorName': creatorName,
        'lastMessage': '$creatorName đã tạo nhóm "$groupName"',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'unreadCount': { for (var uid in allParticipants) uid : 0 },
        'groupAvatarUrl': null,
        'groupDescription': null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã tạo nhóm "$groupName" thành công!'), backgroundColor: activeGreen));
        Navigator.of(context).pop(); // Đóng màn hình tạo nhóm
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tạo nhóm: $e'), backgroundColor: coralRed));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Tạo Nhóm Mới', style: TextStyle(color: Colors.white)),
        backgroundColor: darkSurface,
        actions: [
          TextButton(
            onPressed: _selectedUids.isNotEmpty && _groupNameController.text.trim().isNotEmpty && !_isLoading ? _createGroup : null,
            child: _isLoading
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: topazColor)))
                : Text('Tạo', style: TextStyle(color: _selectedUids.isNotEmpty && _groupNameController.text.trim().isNotEmpty ? topazColor : sonicSilver.withOpacity(0.5))),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _groupNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Tên nhóm (Bắt buộc)',
                labelStyle: const TextStyle(color: sonicSilver),
                hintText: 'Ví dụ: Cà khịa xuyên lục địa',
                filled: true,
                fillColor: darkSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm bạn bè để thêm...',
                filled: true,
                fillColor: darkSurface,
                prefixIcon: const Icon(Icons.search, color: sonicSilver),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Đã chọn ${_selectedUids.length} thành viên.', style: const TextStyle(color: sonicSilver)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _friendsStream,
              builder: (context, snapshot) {
                if (_friendsStream == null) return const Center(child: Text('Bạn chưa có bạn bè nào.', style: TextStyle(color: sonicSilver)));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: topazColor));
                if (snapshot.hasError) return Center(child: Text('Lỗi tải bạn bè: ${snapshot.error}', style: const TextStyle(color: coralRed)));

                final friendDocs = snapshot.data?.docs ?? [];

                // --- Bắt đầu Logic Lọc và Khắc phục lỗi ---
                final queryLower = _friendSearchQuery.toLowerCase();

                final filteredDocs = friendDocs.where((doc) {
                  // PHẦN KHẮC PHỤC: Cast dữ liệu an toàn để tránh lỗi Object
                  final data = doc.data() as Map<String, dynamic>?;
                  if (data == null) return false;

                  final name = (data['displayName'] as String? ?? '').toLowerCase();
                  final username = (data['username'] as String? ?? '').toLowerCase();

                  return name.contains(queryLower) || username.contains(queryLower);
                }).toList();
                // --- Kết thúc Logic Lọc và Khắc phục lỗi ---

                if (filteredDocs.isEmpty) return Center(child: Text('Không tìm thấy bạn bè nào.', style: TextStyle(color: sonicSilver)));

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];

                    // PHẦN KHẮC PHỤC (Lại) - Đảm bảo data là Map<String, dynamic>
                    final data = doc.data() as Map<String, dynamic>? ?? {};

                    final uid = doc.id;
                    final name = data['displayName'] ?? 'Người dùng';
                    final username = data['username'] ?? '';
                    final avatarUrl = data['photoURL'] as String?;
                    final isSelected = _selectedUids.contains(uid);

                    final ImageProvider? avatarProvider = (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) ? NetworkImage(avatarUrl) : null;

                    return ListTile(
                      onTap: _isLoading ? null : () => _toggleSelection(uid),
                      leading: CircleAvatar(
                        radius: 20, backgroundImage: avatarProvider, backgroundColor: darkSurface,
                        child: avatarProvider == null ? const Icon(Icons.person, color: sonicSilver, size: 20) : null,
                      ),
                      title: Text(name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text('@$username', style: TextStyle(color: sonicSilver)),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: topazColor)
                          : const Icon(Icons.circle_outlined, color: sonicSilver),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
// lib/suggested_friend_card.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // <--- Import Auth
// import 'profile_screen.dart'; // Import ProfileScreen (Giả định tồn tại)

// --- Giả định ProfileScreen tồn tại ---
class ProfileScreen extends StatelessWidget { final String? targetUserId; final VoidCallback onNavigateToHome; final VoidCallback onLogout; const ProfileScreen({super.key, this.targetUserId, required this.onNavigateToHome, required this.onLogout}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text("Profile ${targetUserId ?? 'Me'}")), body: Center(child: Text("Profile Screen")));}
// --- Kết thúc giả định ---


// Constants (Giữ nguyên)
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C); // Dùng cho lỗi

class SuggestedFriendCard extends StatefulWidget {
  final Map<String, dynamic> friendData;
  final VoidCallback onStateChange;

  const SuggestedFriendCard({
    super.key,
    required this.friendData,
    required this.onStateChange,
  });

  @override
  State<SuggestedFriendCard> createState() => _SuggestedFriendCardState();
}

class _SuggestedFriendCardState extends State<SuggestedFriendCard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  bool _isPending = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _checkInitialRequestStatus();
  }

  // --- Logic kiểm tra, gửi/hủy request, điều hướng (Giữ nguyên) ---
  Future<void> _checkInitialRequestStatus() async { /* ... */ }
  void _toggleFriendRequest() async { /* ... */ }
  void _navigateToProfile(BuildContext context) { /* ... */ }

  @override
  Widget build(BuildContext context) {
    final String friendName = widget.friendData['name'] as String? ?? 'Người dùng';
    final int mutualCount = widget.friendData['mutual'] as int? ?? 0;
    final String friendMutualText = mutualCount > 0 ? '$mutualCount bạn chung' : 'Chưa có bạn chung';
    final String? friendAvatarUrl = widget.friendData['avatarUrl'] as String?;

    // Xác định ImageProvider (có thể null)
    final ImageProvider? avatarProvider = (friendAvatarUrl != null && friendAvatarUrl.isNotEmpty && friendAvatarUrl.startsWith('http'))
        ? NetworkImage(friendAvatarUrl)
        : null; // Không còn fallback AssetImage

    Widget userInfoSection = GestureDetector(
      onTap: () => _navigateToProfile(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 15),
          CircleAvatar( // Avatar đã xử lý null
            radius: 35,
            backgroundColor: darkSurface,
            backgroundImage: avatarProvider, // Có thể null
            // Hiển thị Icon nếu không có ảnh
            child: avatarProvider == null ? const Icon(Icons.person, color: sonicSilver, size: 35) : null,
            // ...
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0), // Sửa lỗi: Thêm padding
            child: Text( // Sửa lỗi: Thêm child
              friendName,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
// ...
          // ...
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0), // Sửa lỗi: Thêm padding
            child: Text( // Sửa lỗi: Thêm child
              friendMutualText,
              style: const TextStyle(color: sonicSilver, fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return Container(
      width: 150, margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
          color: darkSurface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10, width: 0.5)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: userInfoSection), // Phần thông tin (đã cập nhật avatar)
          Padding( // Nút hành động (Kết bạn/Hủy) (Giữ nguyên)
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
            child: SizedBox( /* ... Nút ElevatedButton ... */ ),
          ),
        ],
      ),
    );
  }
}

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
  bool _isFollowing = false; // Thêm biến trạng thái mới

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _checkInitialRequestStatus();
  }

  // --- Logic kiểm tra, gửi/hủy request, điều hướng ---
  Future<void> _checkInitialRequestStatus() async {
    if (_currentUser == null) return;
    final myUserDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
    if (!myUserDoc.exists) return;

    final myData = myUserDoc.data() as Map<String, dynamic>;
    final targetUserId = widget.friendData['uid'] as String?;
    if (targetUserId == null) return;

    final outgoingRequests = List<String>.from(myData['outgoingRequests'] ?? []);
    final following = List<String>.from(myData['following'] ?? []);

    if (mounted) {
      setState(() {
        _isPending = outgoingRequests.contains(targetUserId);
        _isFollowing = following.contains(targetUserId);
      });
    }
  }

  void _toggleFriendRequest() async {
    final currentUser = _currentUser;
    final targetUserId = widget.friendData['uid'] as String?;
    final targetUserName = widget.friendData['displayName'] as String? ?? 'Người dùng';

    if (currentUser == null || targetUserId == null || _isLoading) return;
    if (mounted) setState(() => _isLoading = true);

    final userRef = _firestore.collection('users').doc(currentUser.uid);
    final targetNotificationRef = _firestore.collection('users').doc(targetUserId).collection('notifications');

    try {
      if (_isPending) { // Hủy lời mời
        await userRef.update({'outgoingRequests': FieldValue.arrayRemove([targetUserId])});
        final notificationQuery = await targetNotificationRef
            .where('type', isEqualTo: 'friend_request')
            .where('senderId', isEqualTo: currentUser.uid)
            .limit(1)
            .get();
        for (var doc in notificationQuery.docs) {
          await doc.reference.delete();
        }
        if (mounted) setState(() => _isPending = false);
      } else { // Gửi lời mời
        DocumentSnapshot myUserDoc = await userRef.get();
        String senderName = 'Người dùng Zink';
        String? senderAvatarUrl;

        if (myUserDoc.exists) {
          final myData = myUserDoc.data() as Map<String, dynamic>;
          senderName = myData['displayName'] ?? 'Người dùng Zink';
          senderAvatarUrl = myData['photoURL'];
        }

        await userRef.update({'outgoingRequests': FieldValue.arrayUnion([targetUserId])});
        await targetNotificationRef.add({
          'type': 'friend_request',
          'senderId': currentUser.uid,
          'senderName': senderName,
          'senderAvatarUrl': senderAvatarUrl,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'actionTaken': false,
        });

        if (mounted) setState(() => _isPending = true);
      }
    } catch (e) {
      print("Error toggling friend request: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        widget.onStateChange();
      }
    }
  }

  // Hàm mới để xử lý Theo dõi/Hủy theo dõi
  void _toggleFollow() async {
    final currentUser = _currentUser;
    final targetUserId = widget.friendData['uid'] as String?;

    if (currentUser == null || targetUserId == null || _isLoading) return;
    if (mounted) setState(() => _isLoading = true);

    final myDocRef = _firestore.collection('users').doc(currentUser.uid);
    final theirDocRef = _firestore.collection('users').doc(targetUserId);
    final WriteBatch batch = _firestore.batch();

    try {
      if (_isFollowing) { // Hủy theo dõi
        batch.update(myDocRef, {'following': FieldValue.arrayRemove([targetUserId])});
        batch.update(theirDocRef, {'followers': FieldValue.arrayRemove([currentUser.uid])});
      } else { // Theo dõi
        DocumentSnapshot myUserDoc = await myDocRef.get();
        String senderName = 'Một người dùng';
        String? senderAvatarUrl;
        if (myUserDoc.exists) {
          final myData = myUserDoc.data() as Map<String, dynamic>;
          senderName = myData['displayName'] ?? 'Một người dùng';
          senderAvatarUrl = myData['photoURL'];
        }

        batch.update(myDocRef, {'following': FieldValue.arrayUnion([targetUserId])});
        batch.update(theirDocRef, {'followers': FieldValue.arrayUnion([currentUser.uid])});

        // Tạo thông báo theo dõi
        final notificationRef = theirDocRef.collection('notifications').doc();
        batch.set(notificationRef, {
          'type': 'follow',
          'senderId': currentUser.uid,
          'senderName': senderName,
          'senderAvatarUrl': senderAvatarUrl ?? '',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }
      await batch.commit();
      if (mounted) {
        setState(() { _isFollowing = !_isFollowing; });
      }
    } catch(e) {
      print("Error toggling follow: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        widget.onStateChange();
      }
    }
  }

  void _navigateToProfile(BuildContext context) {
    final targetUserId = widget.friendData['uid'] as String?;
    if (targetUserId == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => ProfileScreen(
        targetUserId: targetUserId,
        onNavigateToHome: () {},
        onLogout: () {},
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final String friendName = widget.friendData['displayName'] as String? ?? 'Người dùng';
    final int mutualCount = widget.friendData['mutual'] as int? ?? 0;
    final String friendMutualText = mutualCount > 0 ? '$mutualCount bạn chung' : 'Chưa có bạn chung';
    final String? friendAvatarUrl = widget.friendData['photoURL'] as String?;

    final ImageProvider? avatarProvider = (friendAvatarUrl != null && friendAvatarUrl.isNotEmpty && friendAvatarUrl.startsWith('http'))
        ? NetworkImage(friendAvatarUrl)
        : null;

    Widget userInfoSection = GestureDetector(
      onTap: () => _navigateToProfile(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 15),
          CircleAvatar(
            radius: 35,
            backgroundColor: darkSurface,
            backgroundImage: avatarProvider,
            child: avatarProvider == null ? const Icon(Icons.person, color: sonicSilver, size: 35) : null,
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(friendName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(friendMutualText, style: const TextStyle(color: sonicSilver, fontSize: 12), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );

    // Logic cho nút Kết bạn
    final friendButtonText = _isPending ? 'Hủy lời mời' : 'Kết bạn';
    final friendButtonColor = _isPending ? darkSurface : topazColor;
    final friendTextColor = _isPending ? sonicSilver : Colors.black;
    final friendButtonSide = _isPending ? BorderSide(color: sonicSilver) : BorderSide.none;

    // Logic cho nút Theo dõi
    final followButtonText = _isFollowing ? 'Hủy theo dõi' : 'Theo dõi';
    final followButtonColor = _isFollowing ? darkSurface : Colors.blueAccent;
    final followTextColor = _isFollowing ? sonicSilver : Colors.white;
    final followButtonSide = _isFollowing ? BorderSide(color: sonicSilver) : BorderSide.none;

    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(color: darkSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10, width: 0.5)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: userInfoSection),
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _toggleFriendRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: friendButtonColor,
                      foregroundColor: friendTextColor,
                      side: friendButtonSide,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: _isLoading ? const SizedBox(height: 12, width: 12, child: CircularProgressIndicator(strokeWidth: 2)) : Text(friendButtonText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _toggleFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: followButtonColor,
                      foregroundColor: followTextColor,
                      side: followButtonSide,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: _isLoading ? const SizedBox(height: 12, width: 12, child: CircularProgressIndicator(strokeWidth: 2)) : Text(followButtonText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';

// Model này định nghĩa cấu trúc dữ liệu cho một đối tượng Comment.
// Việc tách riêng model giúp cho việc quản lý, tái sử dụng và kiểm thử code trở nên dễ dàng hơn.

class Comment {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String text;
  final Timestamp timestamp;
  final String? parentId;
  bool isLiked;
  int likesCount;
  final List<String> likedBy;
  final String username; // <-- THÊM DÒNG NÀY

  Comment({
    required this.id,
    required this.userId,
    required this.userName, // Đây là displayName
    this.userAvatarUrl,
    required this.text,
    required this.timestamp,
    this.parentId,
    this.isLiked = false,
    required this.likesCount,
    required this.likedBy,
    required this.username, // <-- THÊM DÒNG NÀY
  });

  factory Comment.fromFirestore(DocumentSnapshot doc, String currentUserId) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    List<String> likedByList = List<String>.from(data['likedBy'] ?? []);

    return Comment(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['displayName'] ?? 'Người dùng ẩn', // SỬA LẠI TỪ LẦN TRƯỚC
      userAvatarUrl: data['userAvatarUrl'],
      text: data['text'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      parentId: data['parentId'],
      likesCount: (data['likesCount'] is num ? (data['likesCount'] as num).toInt() : 0),
      likedBy: likedByList,
      isLiked: currentUserId.isNotEmpty && likedByList.contains(currentUserId),
      username: data['username'] ?? '', // <-- THÊM DÒNG NÀY (Giả sử bạn lưu 'username' khi tạo user)
    );
  }
}
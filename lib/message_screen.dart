// lib/message_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/scheduler.dart';

import 'create_group_screen.dart'; // <--- Import màn hình tạo nhóm

const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C);
const Color whiteColor = Colors.white;
const Color blackColor = Colors.black;

// =======================================================
// MOCK CLASS (Đã sửa lỗi)
// =======================================================
class MockDocumentSnapshot implements DocumentSnapshot {
  @override
  final String id;
  final Map<String, dynamic> _data;

  MockDocumentSnapshot({required this.id, required Map<String, dynamic> data}) : _data = data;

  @override Map<String, dynamic>? data() => _data;
  @override get exists => true;
  @override get reference => throw UnimplementedError();
  @override get metadata => throw UnimplementedError();

  @override
  Object? get(Object field) => _data[field];

  @override operator [] (Object field) => _data[field];
}


// =======================================================
// Main Screen Widget (Router)
// =======================================================
class MessageScreen extends StatefulWidget {
  final String? targetUserId; // Đây có thể là UID của người nhận HOẶC Chat ID (dành cho chat đã tồn tại)
  final String? targetUserName;

  const MessageScreen({super.key, this.targetUserId, this.targetUserName});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  String? _chatId;

  @override
  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _initializeChatLogic(); // Gọi hàm khởi tạo mới
    }
  }

  Future<void> _initializeChatLogic() async {
    final currentUserId = _currentUser!.uid;
    final otherId = widget.targetUserId; // Có thể là UID hoặc Chat ID

    // Case 1: Màn hình chính (Danh sách Chat)
    if (otherId == null || otherId.isEmpty) {
      if (mounted) setState(() => _chatId = 'LIST_VIEW');
      return;
    }

    // Case 2: Chat Nhóm HOẶC Chat đã tồn tại
    final chatDoc = await _firestore.collection('chats').doc(otherId).get();
    if (chatDoc.exists && (chatDoc.data()?['participants'] as List?)?.contains(currentUserId) == true) {
      if (mounted) setState(() => _chatId = otherId);
      return;
    }

    // Case 3: 1-on-1 chat mới (otherId là User ID)
    final participants = [currentUserId, otherId]..sort();

    // Tìm chat 1-on-1 hiện có
    final querySnapshot = await _firestore.collection('chats')
        .where('participants', isEqualTo: participants)
        .where('isGroup', isEqualTo: false)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      _chatId = querySnapshot.docs.first.id;
    } else {
      // Tạo chat 1-on-1 mới
      final newChat = await _firestore.collection('chats').add({
        'participants': participants,
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'unreadCount': {},
        'isGroup': false, // Quan trọng: Đánh dấu là chat 1-on-1
        'isPinned': false, // Cần thiết cho lệnh orderBy
      });
      _chatId = newChat.id;
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_chatId == null || _currentUser == null) {
      return const Center(child: CircularProgressIndicator(color: topazColor));
    }

    final bool isListView = (_chatId == 'LIST_VIEW');
    final String title = isListView
        ? 'Tin nhắn'
    // [ĐÃ SỬA LỖI NULL] targetUserId là nullable, nên phải dùng ?.
        : (widget.targetUserName ?? widget.targetUserId ?? 'Đang tải...');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: isListView ? [
          IconButton(
            icon: const Icon(Icons.group_add_rounded, color: topazColor),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
              );
            },
          ),
        ] : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_chatId == null || _currentUser == null) {
      return const Center(child: CircularProgressIndicator(color: topazColor));
    }

    if (_chatId == 'LIST_VIEW') {
      return _ChatListView(currentUser: _currentUser!);
    }

    // Sử dụng FutureBuilder để đảm bảo thông tin chat là mới nhất
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('chats').doc(_chatId!).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: topazColor));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final isGroup = data?['isGroup'] as bool? ?? false;

        // [ĐÃ SỬA LỖI NULL] targetUserId là nullable, cần kiểm tra
        final String resolvedTargetId = widget.targetUserId ?? '';

        final String resolvedTargetName = widget.targetUserName ?? (
            isGroup
                ? (data?['groupName'] as String? ?? 'Group Chat')
                : 'Người dùng'
        );

        return Material(
          color: Colors.black,
          child: _ConversationView(
            chatId: _chatId!,
            currentUser: _currentUser!,
            targetUserName: resolvedTargetName,
            targetUserId: resolvedTargetId, // Truyền ID đích đã được xử lý null
            isGroup: isGroup,
          ),
        );
      },
    );
  }
}

// =======================================================
// Widget for displaying the list of all chats
// =======================================================
class _ChatListView extends StatelessWidget {
  final User currentUser;
  const _ChatListView({required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .orderBy('isPinned', descending: true)
          .orderBy('lastMessageTimestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: topazColor));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}', style: const TextStyle(color: coralRed)));
        }

        // [SỬA LỖ HỔNG 1: SOFT DELETE] Lọc những chat đã bị người dùng hiện tại ẩn/xóa
        final chatDocs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final isHidden = data['userHidden'] is Map && (data['userHidden'] as Map)[currentUser.uid] == true;
          return !isHidden;
        }).toList();

        if (chatDocs.isEmpty) {
          return const Center(child: Text('Chưa có cuộc trò chuyện nào.', style: TextStyle(color: sonicSilver)));
        }

        return ListView.builder(
          itemCount: chatDocs.length,
          itemBuilder: (context, index) => _ChatListItem(chatDoc: chatDocs[index], currentUser: currentUser),
        );
      },
    );
  }
}
// =======================================================
// Widget for a single conversation
// =======================================================
class _ConversationView extends StatefulWidget {
  final String chatId;
  final User currentUser;
  final String targetUserName;
  final String targetUserId;
  final bool isGroup;

  const _ConversationView({
    required this.chatId,
    required this.currentUser,
    required this.targetUserName,
    required this.targetUserId,
    this.isGroup = false,
  });

  @override
  State<_ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<_ConversationView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _currentUserName = 'Bạn';
  late String _otherUserId;
  List<String> _groupParticipants = [];

  @override
  void initState() {
    super.initState();

    _otherUserId = widget.targetUserId;

    if (widget.isGroup) {
      _fetchChatParticipants();
    }

    _firestore.collection('users').doc(widget.currentUser.uid).get().then((doc) {
      if (mounted && doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _currentUserName = data['displayName'] ?? 'Bạn';
        });
      }
    });
  }

  void _fetchChatParticipants() async {
    final chatDoc = await _firestore.collection('chats').doc(widget.chatId).get();
    final data = chatDoc.data();
    if (mounted && data != null) {
      setState(() {
        _groupParticipants = List<String>.from(data['participants'] ?? []);
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if (!widget.isGroup && widget.targetUserId.isNotEmpty) {
      final otherUserDoc = await _firestore.collection('users').doc(widget.targetUserId).get();
      final blockedUids = otherUserDoc.data()?['blockedUids'] as List<dynamic>? ?? [];

      if (blockedUids.contains(widget.currentUser.uid)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể gửi tin nhắn. Bạn đã bị chặn.'), backgroundColor: coralRed));
        return;
      }

      // KIỂM TRA MÌNH CÓ CHẶN NGƯỜI KIA KHÔNG
      final myDoc = await _firestore.collection('users').doc(widget.currentUser.uid).get();
      final myBlockedUids = myDoc.data()?['blockedUids'] as List<dynamic>? ?? [];
      if (myBlockedUids.contains(widget.targetUserId)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể gửi tin nhắn. Bạn đã chặn người dùng này.'), backgroundColor: coralRed));
        return;
      }
    }

    // --- BẮT ĐẦU THAY ĐỔI: Lấy Avatar URL ---
    String? senderAvatarUrl;
    try {
      final userDoc = await _firestore.collection('users').doc(widget.currentUser.uid).get();
      if (userDoc.exists) {
        senderAvatarUrl = (userDoc.data() as Map<String, dynamic>?)?['photoURL'] as String?;
      }
    } catch (e) {
      print("Lỗi lấy avatar người gửi: $e");
    }
    // --- KẾT THÚC THAY ĐỔI ---

    final messageContent = {
      'senderId': widget.currentUser.uid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'isRead': false,
    };

    try {
      final chatRef = _firestore.collection('chats').doc(widget.chatId);
      final batch = _firestore.batch();

      // 1. Thêm tin nhắn vào subcollection
      batch.set(chatRef.collection('messages').doc(), messageContent);

      // 2. Cập nhật lastMessage VÀ unreadCount
      final updateData = <String, dynamic>{
        'lastMessage': text,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      };

      // ... (Logic cập nhật unreadCount giữ nguyên)
      if (widget.isGroup) {
        final myUid = widget.currentUser.uid;
        final recipients = _groupParticipants.where((uid) => uid != myUid);

        for (final recipientId in recipients) {
          final String unreadField = 'unreadCount.$recipientId';
          updateData[unreadField] = FieldValue.increment(1);
        }
      } else if (_otherUserId.isNotEmpty) {
        final String unreadField = 'unreadCount.$_otherUserId';
        updateData[unreadField] = FieldValue.increment(1);
      }

      batch.update(chatRef, updateData);

      await batch.commit();

      _messageController.clear();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi: Không thể gửi tin nhắn.'), backgroundColor: topazColor));
    }
  }
  void _markMessagesAsRead(List<QueryDocumentSnapshot> docs) {
    final unreadDocs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return (data['senderId'] != widget.currentUser.uid) && (data['isRead'] == false);
    }).toList();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      final batch = _firestore.batch();

      for (var doc in unreadDocs) {
        batch.update(doc.reference, {'isRead': true});
      }

      final String unreadField = 'unreadCount.${widget.currentUser.uid}';

      batch.update(_firestore.collection('chats').doc(widget.chatId), {
        unreadField: 0,
      });

      batch.commit().catchError((_) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('chats')
                .doc(widget.chatId) // <-- PHẢI SỬ DỤNG CHATID TỪ WIDGET
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: topazColor));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Lỗi tải tin nhắn: ${snapshot.error}', style: const TextStyle(color: coralRed)));
              }

              final messages = snapshot.data?.docs ?? [];
              if (messages.isEmpty) {
                return Center(child: Text('Bắt đầu cuộc trò chuyện với ${widget.targetUserName}!', style: const TextStyle(color: sonicSilver)));
              }

              _markMessagesAsRead(messages);

              return ListView.builder(
                reverse: true,
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                itemCount: messages.length,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                itemBuilder: (context, index) {
                  final data = messages[index].data() as Map<String, dynamic>;
                  final currentMsgTimestamp = data['timestamp'] as Timestamp? ?? Timestamp.now();
                  final DateTime currentDate = currentMsgTimestamp.toDate();

                  // --- THAY ĐỔI: Lấy Avatar URL ---
                  final String senderId = data['senderId'] ?? '';                  // --- KẾT THÚC THAY ĐỔI ---

                  bool showDateHeader = false;
                  if (index == messages.length - 1) {
                    showDateHeader = true;
                  } else {
                    final nextData = messages[index + 1].data() as Map<String, dynamic>;
                    final nextMsgTimestamp = nextData['timestamp'] as Timestamp? ?? Timestamp.now();
                    final DateTime nextDate = nextMsgTimestamp.toDate();

                    if (currentDate.day != nextDate.day || currentDate.month != nextDate.month || currentDate.year != nextDate.year) {
                      showDateHeader = true;
                    }
                  }

                  final bubble = _MessageBubble(
                    senderId: data['senderId'] ?? '',
                    text: data['text'] ?? '',
                    timestamp: currentMsgTimestamp,
                    isMe: (data['senderId'] ?? '') == widget.currentUser.uid,
                    isRead: data['isRead'] ?? false,
                  );

                  if (showDateHeader) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _DateHeader(date: currentDate),
                        bubble,
                      ],
                    );
                  }

                  return bubble;
                },
              );
            },
          ),
        ),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.only(left: 12, right: 12, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: darkSurface,
        border: Border(top: BorderSide(color: sonicSilver.withOpacity(0.2))),
      ),
      child: Material(
        color: darkSurface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        hintStyle: TextStyle(color: sonicSilver.withOpacity(0.7)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: topazColor,
                    child: const Icon(Icons.send, color: Colors.black, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =======================================================
// Date Header Widget (Giữ nguyên)
// =======================================================
class _DateHeader extends StatelessWidget {
  final DateTime date;
  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    String text;
    if (dateToCheck == today) {
      text = 'Hôm nay';
    } else if (dateToCheck == yesterday) {
      text = 'Hôm qua';
    } else {
      text = '${date.day} tháng ${date.month}, ${date.year}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[800]?.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

// =======================================================
// Widget for a single message bubble (Giữ nguyên)
// =======================================================
class _MessageBubble extends StatelessWidget {
  final String senderId;
  final String text;
  final Timestamp timestamp;
  final bool isMe;
  final bool isRead;

  const _MessageBubble({
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.isRead = false,
  });

  @override
  @override
  Widget build(BuildContext context) {
    final String timeString = "${timestamp.toDate().hour.toString().padLeft(2, '0')}:${timestamp.toDate().minute.toString().padLeft(2, '0')}";

    if (!isMe) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(senderId).get(),
        builder: (context, snapshot) {
          String? avatarUrl;
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            avatarUrl = data?['photoURL'] as String?;
          }

          final ImageProvider? avatarProvider = (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
              ? NetworkImage(avatarUrl) : null;

          return _buildBubbleLayout(context, timeString, avatarProvider, isMe, isRead, text);
        },
      );
    }

    // Nếu là tin nhắn của mình, không cần tra cứu
    return _buildBubbleLayout(context, timeString, null, isMe, isRead, text);
  }

  // Hàm helper để xây dựng layout bong bóng
  Widget _buildBubbleLayout(BuildContext context, String timeString, ImageProvider? avatarProvider, bool isMe, bool isRead, String text) {
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.70),
      decoration: BoxDecoration(
        color: isMe ? topazColor : darkSurface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(2),
          bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              color: isMe ? Colors.black : Colors.white,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeString,
                  style: TextStyle(
                    color: isMe ? Colors.black54 : Colors.white38,
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.check,
                    size: 12,
                    color: isRead ? Colors.blue[800] : Colors.black54,
                  )
                ]
              ]
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (Chỉ hiển thị nếu KHÔNG phải tin nhắn của mình)
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: darkSurface,
              backgroundImage: avatarProvider,
              child: avatarProvider == null ? const Icon(Icons.person, size: 16, color: sonicSilver) : null,
            ),
            const SizedBox(width: 8),
          ],

          // Bubble
          bubble,

          // Khoảng trống bù trừ (Chỉ hiển thị nếu là tin nhắn của mình)
          if (isMe) const SizedBox(width: 40),
        ],
      ),
    );
  }
}

// ===================================================================
// WIDGET MỚI: ĐỂ HIỂN THỊ MỘT DÒNG TRONG DANH SÁCH CHAT (STATEFUL)
// ===================================================================
class _ChatListItem extends StatefulWidget {
  final DocumentSnapshot chatDoc;
  final User currentUser;
  const _ChatListItem({required this.chatDoc, required this.currentUser});

  @override
  State<_ChatListItem> createState() => _ChatListItemState();
}

class _ChatListItemState extends State<_ChatListItem> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DocumentSnapshot? _otherUserDoc;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOtherUserData(); // Lần tải đầu tiên
  }

  @override
  void didUpdateWidget(covariant _ChatListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Chỉ tải lại nếu ID của tài liệu chat thực sự thay đổi.
    if (widget.chatDoc.id != oldWidget.chatDoc.id) {
      _fetchOtherUserData();
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } else if (dateToCheck == yesterday) {
      return 'Hôm qua';
    } else if (dateToCheck.year == now.year) {
      return '${date.day}/${date.month}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _fetchOtherUserData() async {
    if (!mounted) return;

    final data = widget.chatDoc.data() as Map<String, dynamic>;
    final isGroup = data['isGroup'] as bool? ?? false;

    if (isGroup) {
      final groupName = data['groupName'] as String? ?? 'Group Chat';
      final groupAvatarUrl = data['groupAvatarUrl'] as String?;

      final mockDoc = MockDocumentSnapshot(
          id: widget.chatDoc.id,
          data: {
            'displayName': groupName,
            'photoURL': groupAvatarUrl,
            'isGroup': true,
          }
      );

      if (mounted) {
        setState(() {
          _otherUserDoc = mockDoc;
          _isLoading = false;
        });
      }

    } else {
      final List<dynamic> participants = data['participants'] ?? [];
      final String otherUserId = participants.firstWhere((id) => id != widget.currentUser.uid, orElse: () => '');

      if (otherUserId.isNotEmpty) {
        try {
          final userDoc = await _firestore.collection('users').doc(otherUserId).get();
          if (mounted) {
            setState(() {
              _otherUserDoc = userDoc;
              _isLoading = false;
            });
          }
        } catch (e) {
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _onNavigateBack() {
    _fetchOtherUserData();
  }

  void _unhideChat() async {
    try {
      await _firestore.collection('chats').doc(widget.chatDoc.id).update({
        'userHidden.${widget.currentUser.uid}': FieldValue.delete(), // Xóa trường ẩn
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã khôi phục tin nhắn.'), backgroundColor: topazColor));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi: Không thể khôi phục tin nhắn.'), backgroundColor: coralRed));
    }
  }

  void _showChatContextMenu(String otherUserName, bool isGroup, String otherUserId) {
    final bool isPinned = _isChatPinned();
    final pinActionText = isPinned ? 'Bỏ ghim tin nhắn' : 'Ghim tin nhắn';
    final pinActionIcon = isPinned ? Icons.push_pin : Icons.push_pin_outlined;

    // [SỬA LỖ HỔNG 1: SOFT DELETE] Kiểm tra nếu chat đã bị ẩn
    final chatData = widget.chatDoc.data() as Map<String, dynamic>? ?? {};
    final isHidden = chatData['userHidden'] is Map && (chatData['userHidden'] as Map)[widget.currentUser.uid] == true;


    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: darkSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pin/Unpin
              ListTile(
                leading: Icon(pinActionIcon, color: topazColor),
                title: Text(pinActionText, style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _togglePinChat(isPinned);
                },
              ),
              // Delete (Xóa mềm)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: coralRed),
                title: const Text('Ẩn/Xóa tin nhắn (Chỉ mình tôi)', style: TextStyle(color: coralRed)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _deleteChat(widget.chatDoc.id, otherUserName, isGroup); // Vẫn gọi hàm xóa, nhưng logic đã đổi
                },
              ),
              // [SỬA LỖ HỔNG 1: SOFT DELETE] Tùy chọn Hoàn tác
              if (isHidden)
                ListTile(
                  leading: const Icon(Icons.restore_page, color: activeGreen),
                  title: const Text('Hoàn tác xóa tin nhắn', style: TextStyle(color: activeGreen)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _unhideChat();
                  },
                ),
              // Block (only for 1-on-1 chat)
              if (isGroup)
                ListTile(
                  leading: const Icon(Icons.logout, color: coralRed), // Icon Rời nhóm
                  title: const Text('Rời nhóm', style: TextStyle(color: coralRed)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _leaveGroup(widget.chatDoc.id, otherUserName);
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.block, color: coralRed),
                  title: Text('Chặn $otherUserName', style: const TextStyle(color: coralRed)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _blockUser(otherUserId, otherUserName);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // --- 2. Kiểm tra ghim ---
  bool _isChatPinned() {
    final chatData = widget.chatDoc.data() as Map<String, dynamic>?;
    return chatData?['isPinned'] as bool? ?? false;
  }

  // --- 3. Xử lý ghim/bỏ ghim ---
  void _togglePinChat(bool isCurrentlyPinned) async {
    try {
      await _firestore.collection('chats').doc(widget.chatDoc.id).update({
        'isPinned': !isCurrentlyPinned,
      });
      if (mounted) {
        final message = !isCurrentlyPinned ? 'Đã ghim tin nhắn.' : 'Đã bỏ ghim tin nhắn.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: topazColor));
        // ĐÃ BỎ LỆNH GỌI _fetchOtherUserData() TẠI ĐÂY.
        // StreamBuilder bên ngoài sẽ tự động cập nhật lại widget này với dữ liệu mới.
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi: Không thể ghim/bỏ ghim.'), backgroundColor: coralRed));
    }
  }
  // --- 4. Xử lý xóa tin nhắn (Chỉ xóa chat document cho đơn giản) ---
  void _deleteChat(String chatId, String chatName, bool isGroup) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: darkSurface,
          title: const Text('Ẩn tin nhắn', style: TextStyle(color: Colors.white)),
          content: Text('Bạn có chắc chắn muốn ẩn/xóa tin nhắn này (chỉ mình bạn không thấy)?', style: const TextStyle(color: sonicSilver)),
          actions: [
            TextButton(
              child: const Text('Hủy', style: TextStyle(color: sonicSilver)),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('Ẩn', style: TextStyle(color: coralRed)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        // [THAY THẾ LỆNH DELETE BẰNG LỆNH UPDATE]
        await _firestore.collection('chats').doc(chatId).update({
          'userHidden.${widget.currentUser.uid}': true, // Dùng FieldValue.delete() nếu bạn muốn xóa trường khi unhide
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã ẩn tin nhắn với $chatName.'), backgroundColor: sonicSilver));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi: Không thể ẩn tin nhắn.'), backgroundColor: coralRed));
      }
    }
  }

  // --- 5. Xử lý chặn người dùng ---
  void _blockUser(String targetUserId, String targetUserName) async {
    if (targetUserId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: darkSurface,
          title: const Text('Chặn người dùng', style: TextStyle(color: whiteColor)),
          content: Text('Bạn có chắc chắn muốn chặn $targetUserName không? Bạn sẽ không thể nhận tin nhắn từ người này.', style: const TextStyle(color: sonicSilver)),
          actions: [
            TextButton(
              child: const Text('Hủy', style: TextStyle(color: sonicSilver)),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('Chặn', style: TextStyle(color: coralRed)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await _firestore.collection('users').doc(widget.currentUser.uid).update({
          'blockedUids': FieldValue.arrayUnion([targetUserId])
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã chặn $targetUserName.'), backgroundColor: coralRed));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi: Không thể chặn người dùng.'), backgroundColor: coralRed));
      }
    }
  }

  void _leaveGroup(String chatId, String groupName) async {
    if (widget.currentUser.uid.isEmpty) return;

    final confirm = await showDialog<bool>(
      // ... (AlertDialog giữ nguyên)
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: darkSurface,
          title: const Text('Rời khỏi nhóm', style: TextStyle(color: whiteColor)),
          content: Text('Bạn có chắc chắn muốn rời khỏi nhóm "$groupName" không?', style: const TextStyle(color: sonicSilver)),
          actions: [
            TextButton(
              child: const Text('Hủy', style: TextStyle(color: sonicSilver)),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('Rời nhóm', style: TextStyle(color: coralRed)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        final chatRef = _firestore.collection('chats').doc(chatId);

        // SỬA LỖI TẠI ĐÂY: Truy vấn Firestore để lấy tên người dùng hiện tại
        final myUserDoc = await _firestore.collection('users').doc(widget.currentUser.uid).get();
        // Cần đảm bảo data() là Map<String, dynamic> an toàn
        final myUserData = myUserDoc.data() as Map<String, dynamic>? ?? {};
        final currentUserName = myUserData['displayName'] as String? ?? 'Một thành viên';

        // 1. Xóa người dùng khỏi danh sách participants
        await chatRef.update({
          'participants': FieldValue.arrayRemove([widget.currentUser.uid]),
          'unreadCount.${widget.currentUser.uid}': FieldValue.delete(), // Xóa unread count của họ
          'lastMessage': '$currentUserName đã rời khỏi nhóm.',
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bạn đã rời khỏi nhóm "$groupName".'), backgroundColor: sonicSilver));
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi: Không thể rời nhóm.'), backgroundColor: coralRed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Row(
          children: [
            const CircleAvatar(radius: 25, backgroundColor: darkSurface),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 100, height: 14, color: darkSurface),
                const SizedBox(height: 6),
                Container(width: 150, height: 12, color: darkSurface),
              ],
            )
          ],
        ),
      );
    }

    if (_otherUserDoc == null || !_otherUserDoc!.exists) {
      return const SizedBox.shrink();
    }

    final chatData = widget.chatDoc.data() as Map<String, dynamic>;
    final bool isGroup = chatData['isGroup'] as bool? ?? false;
    final bool isPinned = chatData['isPinned'] as bool? ?? false;

    final userData = _otherUserDoc!.data() as Map<String, dynamic>;
    final String otherUserName = isGroup ? (userData['displayName'] ?? 'Group Chat') : (userData['displayName'] ?? 'Người dùng');
    final String? targetAvatarUrl = userData['photoURL'] as String?;

    final String lastMessage = chatData['lastMessage'] ?? 'Bắt đầu cuộc trò chuyện...';
    final Timestamp? lastMessageTimestamp = chatData['lastMessageTimestamp'];

    final String currentUserId = widget.currentUser.uid;
    final unreadCountMap = chatData['unreadCount'] as Map<String, dynamic>? ?? {};
    final int unreadCount = (unreadCountMap[currentUserId] as num?)?.toInt() ?? 0;
    final bool hasUnread = unreadCount > 0;

    final List<dynamic> participants = chatData['participants'] ?? [];
    final String otherUserId = isGroup
        ? '' // Không chặn group
        : participants.firstWhere((id) => id != currentUserId, orElse: () => '');

    final ImageProvider? avatarProvider = (targetAvatarUrl != null && targetAvatarUrl.isNotEmpty) ? NetworkImage(targetAvatarUrl) : null;
    final IconData defaultIcon = isGroup ? Icons.group_rounded : Icons.person_outline;
    final String defaultAvatarText = isGroup ? otherUserName.substring(0, 1).toUpperCase() : (otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : 'U');

    const Color whiteColor = Colors.white;

    final listTileContent = ListTile(
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: darkSurface,
        backgroundImage: avatarProvider,
        child: avatarProvider == null
            ? (isGroup ? Icon(defaultIcon, color: whiteColor, size: 25) : Text(defaultAvatarText, style: const TextStyle(color: whiteColor, fontWeight: FontWeight.bold)))
            : null,
      ),
      title: Row( // Bọc Title trong Row để thêm biểu tượng Ghim
        children: [
          Text(
              otherUserName,
              style: TextStyle(
                color: whiteColor,
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
              )
          ),
          // HIỂN THỊ BIỂU TƯỢNG GHIM
          if (isPinned)
            Padding(
              padding: const EdgeInsets.only(left: 6.0),
              child: Icon(
                Icons.push_pin_rounded,
                color: sonicSilver,
                size: 16,
              ),
            ),
        ],
      ),
      subtitle: Text(
          lastMessage,
          style: TextStyle(
            color: hasUnread ? whiteColor : sonicSilver,
            fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis
      ),
      trailing: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (lastMessageTimestamp != null)
              Text(
                _formatTimestamp(lastMessageTimestamp),
                style: TextStyle(
                  color: sonicSilver,
                  fontSize: 12,
                  fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            const SizedBox(height: 4),
            if (hasUnread)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: coralRed, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                child: Center(
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(color: whiteColor, fontSize: 12, fontWeight: FontWeight.bold, height: 1.0),
                  ),
                ),
              ),
          ],
        ),
      ),
      // BỎ onTap khỏi ListTile gốc
      onTap: null,
    );

    return GestureDetector(
      // Thêm onTap cho GestureDetector
      onTap: () {
        final String chatId = widget.chatDoc.id;
        final String targetUid = isGroup
            ? chatId
            : otherUserId;

        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (context) => MessageScreen(
                targetUserId: targetUid,
                targetUserName: otherUserName,
              )
          ),
        ).then((_) => _onNavigateBack());
      },
      // --- THÊM onLongPress ---
      onLongPress: () => _showChatContextMenu(otherUserName, isGroup, otherUserId),
      // ------------------------
      child: listTileContent,
    );
  }
}

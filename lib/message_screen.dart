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
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _getOrCreateChatId();
  }

  Future<void> _getOrCreateChatId() async {
    if (_currentUser == null) return;

    // Case 1: Không có target user/ID, hiển thị danh sách chats. (Vào từ Home/Nav Bar)
    if (widget.targetUserId == null || widget.targetUserId!.isEmpty) {
      if (mounted) setState(() => _chatId = 'LIST_VIEW');
      return;
    }

    final currentUserId = _currentUser!.uid;
    final potentialId = widget.targetUserId!; // Đây có thể là Chat ID HOẶC User ID

    // --- LOGIC MỚI: Ưu tiên kiểm tra xem ID này có phải là CHAT ID đã tồn tại không ---
    final chatDoc = await _firestore.collection('chats').doc(potentialId).get();
    if (chatDoc.exists) {
      final data = chatDoc.data();
      if (data != null && (data['participants'] as List?)?.contains(currentUserId) == true) {
        // Nếu tìm thấy và người dùng hiện tại là thành viên, đây là CHAT ID.
        if (mounted) setState(() => _chatId = potentialId);
        return;
      }
    }
    // --- KẾT THÚC LOGIC MỚI ---

    // Case 2: Đây là target USER ID (e.g., bấm 'Message' từ profile của một người khác)
    final targetUserId = potentialId;
    final participants = [currentUserId, targetUserId]..sort();

    // Tìm chat 1-on-1 hiện có
    final querySnapshot = await _firestore.collection('chats').where('participants', isEqualTo: participants).limit(1).get();

    if (querySnapshot.docs.isNotEmpty) {
      if (mounted) setState(() => _chatId = querySnapshot.docs.first.id);
    } else {
      // Tạo chat 1-on-1 mới
      final newChat = await _firestore.collection('chats').add({
        'participants': participants,
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'unreadCount': {},
      });
      if (mounted) setState(() => _chatId = newChat.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isListView = (_chatId == 'LIST_VIEW');
    final String title = isListView
        ? 'Tin nhắn'
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

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('chats').doc(_chatId!).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: topazColor));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final isGroup = data?['isGroup'] as bool? ?? false;

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
            targetUserId: widget.targetUserId!,
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
          .orderBy('lastMessageTimestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: topazColor));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}', style: const TextStyle(color: coralRed)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Chưa có cuộc trò chuyện nào.', style: TextStyle(color: sonicSilver)));
        }

        final chatDocs = snapshot.data!.docs;
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
      'senderName': _currentUserName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'isRead': false,
      'senderAvatarUrl': senderAvatarUrl, // <-- LƯU URL AVATAR
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
            stream: _firestore.collection('chats').doc(widget.chatId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
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
                  final String? senderAvatarUrl = data['senderAvatarUrl'] as String?;
                  // --- KẾT THÚC THAY ĐỔI ---

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
                    // --- THAY ĐỔI: Truyền Avatar URL ---
                    senderAvatarUrl: senderAvatarUrl,
                    // --- KẾT THÚC THAY ĐỔI ---
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
  final String? senderAvatarUrl;

  const _MessageBubble({
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.isRead = false,
    this.senderAvatarUrl,
  });

  @override
  @override
  Widget build(BuildContext context) {
    final String timeString = "${timestamp.toDate().hour.toString().padLeft(2, '0')}:${timestamp.toDate().minute.toString().padLeft(2, '0')}";

    final ImageProvider? avatarProvider = (senderAvatarUrl != null && senderAvatarUrl!.startsWith('http'))
        ? NetworkImage(senderAvatarUrl!)
        : null;

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.70), // Giảm maxWidth để chừa chỗ cho Avatar
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

    // Xây dựng giao diện bao gồm Avatar và Bubble
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
    _fetchOtherUserData();
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

    final userData = _otherUserDoc!.data() as Map<String, dynamic>;
    final String otherUserName = isGroup ? (userData['displayName'] ?? 'Group Chat') : (userData['displayName'] ?? 'Người dùng');
    final String? targetAvatarUrl = userData['photoURL'] as String?;

    final String lastMessage = chatData['lastMessage'] ?? 'Bắt đầu cuộc trò chuyện...';
    final Timestamp? lastMessageTimestamp = chatData['lastMessageTimestamp'];

    final String currentUserId = widget.currentUser.uid;
    final unreadCountMap = chatData['unreadCount'] as Map<String, dynamic>? ?? {};
    final int unreadCount = (unreadCountMap[currentUserId] as num?)?.toInt() ?? 0;
    final bool hasUnread = unreadCount > 0;

    final ImageProvider? avatarProvider = (targetAvatarUrl != null && targetAvatarUrl.isNotEmpty) ? NetworkImage(targetAvatarUrl) : null;
    final IconData defaultIcon = isGroup ? Icons.group_rounded : Icons.person_outline;
    final String defaultAvatarText = isGroup ? otherUserName.substring(0, 1).toUpperCase() : (otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : 'U');

    const Color whiteColor = Colors.white;

    return ListTile(
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: darkSurface,
        backgroundImage: avatarProvider,
        child: avatarProvider == null
            ? (isGroup ? Icon(defaultIcon, color: whiteColor, size: 25) : Text(defaultAvatarText, style: const TextStyle(color: whiteColor, fontWeight: FontWeight.bold)))
            : null,
      ),
      title: Text(
          otherUserName,
          style: TextStyle(
            color: whiteColor,
            fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
          )
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
      onTap: () {
        // --- LOGIC SỬA LỖI: Luôn truyền Chat ID làm targetUserId ---
        final String chatId = widget.chatDoc.id;

        // Nếu là 1-on-1, chúng ta cần UID của người kia để MessageScreen có thể tìm kiếm
        final List<dynamic> participants = chatData['participants'] ?? [];
        final String targetUid = isGroup
            ? chatId // Nếu là nhóm, truyền CHAT ID
            : participants.firstWhere((id) => id != widget.currentUser.uid, orElse: () => ''); // Nếu 1-v-1, truyền UID người nhận

        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (context) => MessageScreen(
                // Nếu là group, targetUserId = CHAT ID. Nếu là 1-v-1, targetUserId = UID của người kia.
                targetUserId: targetUid,
                targetUserName: otherUserName,
              )
          ),
        ).then((_) => _onNavigateBack());
      },
    );
  }
}
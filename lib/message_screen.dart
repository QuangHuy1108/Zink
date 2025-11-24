// lib/message_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/scheduler.dart';

const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C);

// =======================================================
// Main Screen Widget (Router)
// =======================================================
class MessageScreen extends StatefulWidget {
  final String? targetUserId;
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

    // Case 1: No target user, show the list of chats.
    if (widget.targetUserId == null) {
      if (mounted) setState(() => _chatId = 'LIST_VIEW');
      return;
    }

    // Case 2: Target user is provided, find or create the chat.
    final currentUserId = _currentUser!.uid;
    final targetUserId = widget.targetUserId!;
    final participants = [currentUserId, targetUserId]..sort();

    final querySnapshot = await _firestore.collection('chats').where('participants', isEqualTo: participants).limit(1).get();

    if (querySnapshot.docs.isNotEmpty) {
      if (mounted) setState(() => _chatId = querySnapshot.docs.first.id);
    } else {
      final newChat = await _firestore.collection('chats').add({
        'participants': participants,
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
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

    // Otherwise, it's a conversation view
    return _ConversationView(
      chatId: _chatId!,
      currentUser: _currentUser!,
      targetUserName: widget.targetUserName ?? 'Người dùng',
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
          itemBuilder: (context, index) => _ChatListItem(chatDoc: chatDocs[index]),
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

  const _ConversationView({required this.chatId, required this.currentUser, required this.targetUserName});

  @override
  State<_ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<_ConversationView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _currentUserName = 'Bạn';

  @override
  void initState() {
    super.initState();
    // Fetch the current user's display name
    _firestore.collection('users').doc(widget.currentUser.uid).get().then((doc) {
      if (mounted && doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _currentUserName = data['displayName'] ?? 'Bạn';
        });
      }
    });
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

    final messageContent = {
      'senderId': widget.currentUser.uid,
      'senderName': _currentUserName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'isRead': false,
    };

    try {
      await _firestore.collection('chats').doc(widget.chatId).collection('messages').add(messageContent);
      await _firestore.collection('chats').doc(widget.chatId).update({
        'lastMessage': text,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });
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

  // Mark messages as read if they are from the other person and currently unread
  void _markMessagesAsRead(List<QueryDocumentSnapshot> docs) {
    final unreadDocs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return (data['senderId'] != widget.currentUser.uid) && (data['isRead'] == false);
    }).toList();

    if (unreadDocs.isNotEmpty) {
      // Use addPostFrameCallback to avoid calling setState or Firestore updates during build
      SchedulerBinding.instance.addPostFrameCallback((_) {
        final batch = _firestore.batch();
        for (var doc in unreadDocs) {
          batch.update(doc.reference, {'isRead': true});
        }
        batch.commit().catchError((_) {}); // Ignore errors for background update
      });
    }
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

                  bool showDateHeader = false;
                  // Determine if we need a date header.
                  // Since list is reversed (0 is newest), we look at index + 1 (older message)
                  if (index == messages.length - 1) {
                    showDateHeader = true; // Always show date for the very first message (last in reversed list)
                  } else {
                    final nextData = messages[index + 1].data() as Map<String, dynamic>;
                    final nextMsgTimestamp = nextData['timestamp'] as Timestamp? ?? Timestamp.now();
                    final DateTime nextDate = nextMsgTimestamp.toDate();

                    // Check if day, month, or year is different
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
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
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: topazColor,
              child: const Icon(Icons.send, color: Colors.black, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// Date Header Widget
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
// Widget for a single message bubble
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
  Widget build(BuildContext context) {
    final String timeString = "${timestamp.toDate().hour.toString().padLeft(2, '0')}:${timestamp.toDate().minute.toString().padLeft(2, '0')}";

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// WIDGET MỚI: ĐỂ HIỂN THỊ MỘT DÒNG TRONG DANH SÁCH CHAT (STATEFUL)
// ===================================================================
class _ChatListItem extends StatefulWidget {
  final DocumentSnapshot chatDoc;
  const _ChatListItem({required this.chatDoc});

  @override
  State<_ChatListItem> createState() => _ChatListItemState();
}

class _ChatListItemState extends State<_ChatListItem> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  DocumentSnapshot? _otherUserDoc;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _fetchOtherUserData();
  }

  Future<void> _fetchOtherUserData() async {
    if (_currentUser == null) return;
    if (!mounted) return;

    final data = widget.chatDoc.data() as Map<String, dynamic>;
    final List<dynamic> participants = data['participants'];
    final String otherUserId = participants.firstWhere((id) => id != _currentUser!.uid, orElse: () => '');

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
      return const SizedBox.shrink(); // Or a placeholder for a deleted user
    }

    final userData = _otherUserDoc!.data() as Map<String, dynamic>;
    final String targetUserName = userData['displayName'] ?? 'Người dùng';
    final String? targetAvatarUrl = userData['photoURL'] as String?;
    final chatData = widget.chatDoc.data() as Map<String, dynamic>;
    final String lastMessage = chatData['lastMessage'] ?? '';

    // TÍNH TOÁN SỐ TIN NHẮN CHƯA ĐỌC
    final int unreadCount = chatData['unreadCount'] is Map ? (chatData['unreadCount'][_currentUser!.uid] as int? ?? 0) : 0;
    final bool hasUnread = unreadCount > 0;

    return ListTile(
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: darkSurface,
        backgroundImage: (targetAvatarUrl != null && targetAvatarUrl.isNotEmpty) ? NetworkImage(targetAvatarUrl) : null,
        child: (targetAvatarUrl == null || targetAvatarUrl.isEmpty)
            ? Text(targetUserName.isNotEmpty ? targetUserName[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            : null,
      ),
      title: Text(
          targetUserName,
          style: TextStyle(
              color: Colors.white,
              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal // BOLD TÊN NẾU CÓ TIN CHƯA ĐỌC
          )
      ),
      subtitle: Text(
          lastMessage,
          style: TextStyle(
              color: hasUnread ? Colors.white : sonicSilver, // MÀU TRẮNG NẾU CHƯA ĐỌC
              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis
      ),
      trailing: hasUnread
          ? Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(color: topazColor, shape: BoxShape.circle),
        child: Text(
          unreadCount > 9 ? '9+' : unreadCount.toString(),
          style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900),
        ),
      )
          : null, // Không hiển thị gì nếu đã đọc
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => MessageScreen(targetUserId: _otherUserDoc!.id, targetUserName: targetUserName)),
        ).then((_) => _onNavigateBack()); // Refresh on return
      },
    );
  }
}

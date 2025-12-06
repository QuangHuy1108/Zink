// lib/message_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/scheduler.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'create_group_screen.dart' hide topazColor, sonicSilver, darkSurface, coralRed, activeGreen;
import 'profile_screen.dart' hide topazColor, sonicSilver, darkSurface, coralRed, activeGreen, PostDetailScreen, Comment, PlaceholderScreen, FeedScreen, FollowersScreen, MessageScreen;
import 'post_detail_screen.dart'; // <<< KHẮC PHỤC LỖI: IMPORT ĐỂ SỬ DỤNG PostDetailScreen

const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C);
const Color whiteColor = Colors.white;
const Color blackColor = Colors.black;
const Color activeGreen = Color(0xFF32CD32);
const Color lightGrey = Color(0xFFD3D3D3);

// =======================================================
// MOCK CLASS (Giữ nguyên)
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
// Main Screen Widget (Router) (Giữ nguyên)
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final FocusNode _searchFocusNode = FocusNode();
  bool _showSearchField = false;
  Future<DocumentSnapshot>? _chatInitFuture;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _initializeChatLogic();
    }
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildCustomTitle(String defaultTitle, bool isListView) {
    // Nếu KHÔNG phải ListView hoặc đang ở ListView nhưng không bật tìm kiếm, trả về tiêu đề tĩnh
    if (!isListView || !_showSearchField) {
      return Text(defaultTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
    }

    // Chỉ khi là ListView VÀ bật tìm kiếm
    return TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm tin nhắn, nhóm...',
          hintStyle: TextStyle(color: sonicSilver.withOpacity(0.8)),
          filled: true,
          fillColor: darkSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          isDense: true,
          suffixIcon: _searchQuery.isNotEmpty ?
          IconButton(
            icon: const Icon(Icons.clear, color: sonicSilver),
            onPressed: () => _searchController.clear(),
            splashRadius: 20,
          ) : null,
        ),
        onChanged: (text) {
          if (text.isEmpty && _searchQuery.isNotEmpty) {
            if (mounted) setState(() { _searchQuery = ''; });
          }
        }
    );
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (_searchQuery != query) {
      if (mounted) {
        setState(() {
          _searchQuery = query;
        });
      }
    }
  }

  Future<void> _initializeChatLogic() async {
    final currentUserId = _currentUser!.uid;
    final otherId = widget.targetUserId;

    if (otherId == null || otherId.isEmpty) {
      if (mounted) setState(() => _chatId = 'LIST_VIEW');
      return;
    }

    // Kiểm tra xem otherId có phải là Chat ID không
    final chatDoc = await _firestore.collection('chats').doc(otherId).get();
    if (chatDoc.exists && (chatDoc.data()?['participants'] as List?)?.contains(currentUserId) == true) {
      if (mounted) {
        setState(() {
          _chatId = otherId;
          // THÊM: Lưu Future vào biến
          _chatInitFuture = _firestore.collection('chats').doc(_chatId).get();
        });
      }
      return;
    }

    // Logic tìm hoặc tạo chat 1-1
    final participants = [currentUserId, otherId]..sort();
    final querySnapshot = await _firestore.collection('chats')
        .where('participants', isEqualTo: participants)
        .where('isGroup', isEqualTo: false)
        .limit(1)
        .get();

    String resolvedChatId;
    if (querySnapshot.docs.isNotEmpty) {
      resolvedChatId = querySnapshot.docs.first.id;
    } else {
      final newChat = await _firestore.collection('chats').add({
        'participants': participants,
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'unreadCount': {},
        'isGroup': false,
        'isPinned': false,
      });
      resolvedChatId = newChat.id;
    }

    if (mounted) {
      setState(() {
        _chatId = resolvedChatId;
        // THÊM: Lưu Future vào biến
        _chatInitFuture = _firestore.collection('chats').doc(_chatId).get();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chatId == null || _currentUser == null) {
      return const Center(child: CircularProgressIndicator(color: topazColor));
    }

    final bool isListView = (_chatId == 'LIST_VIEW');
    final String title = isListView
        ? 'Tin nhắn'
        : (widget.targetUserName ?? widget.targetUserId ?? 'Đang tải...');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        // SỬA: Điều chỉnh leading
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // SỬA: Nếu đang tìm kiếm VÀ ở ListView, tắt chế độ tìm kiếm
            if (isListView && _showSearchField) {
              setState(() {
                _showSearchField = false;
                _searchController.clear();
                _searchFocusNode.unfocus();
              });
            } else {
              Navigator.of(context).pop(); // Nếu không, pop màn hình
            }
          },
        ),

        // SỬA CÁCH HIỂN THỊ TITLE: (Sử dụng hàm mới)
        title: _buildCustomTitle(title, isListView),

        backgroundColor: Colors.black,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: isListView ? [
          // Nút tạo nhóm
          IconButton(
            icon: const Icon(Icons.group_add_rounded, color: topazColor),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
              );
            },
          ),

          // Nút Tìm kiếm/Clear (Chỉ hiển thị khi ở ListView)
          if (!_showSearchField)
            IconButton(
              icon: const Icon(Icons.search, color: sonicSilver),
              onPressed: () {
                setState(() => _showSearchField = true);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  FocusScope.of(context).requestFocus(_searchFocusNode);
                });
              },
            ),
        ] : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildSearchField() {
    return TextField(
        controller: _searchController,
        focusNode: _searchFocusNode, // <--- GÁN FOCUS NODE
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm tin nhắn, nhóm...',
          hintStyle: TextStyle(color: sonicSilver.withOpacity(0.8)),
          filled: true,
          fillColor: darkSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          isDense: true,
        ),
        onChanged: (text) {
          // Tùy chọn: Nếu người dùng xóa hết text, tự động thoát chế độ tìm kiếm
          if (text.isEmpty && _searchQuery.isNotEmpty) {
            if (mounted) setState(() { _searchQuery = ''; });
          }
        }
    );
  }

  Widget _buildBody() {
    if (_chatId == null || _currentUser == null) {
      return const Center(child: CircularProgressIndicator(color: topazColor));
    }

    if (_chatId == 'LIST_VIEW') {
      return _ChatListView(currentUser: _currentUser!, searchQuery: _searchQuery);
    }

    // SỬA ĐOẠN NÀY: Dùng _chatInitFuture
    return FutureBuilder<DocumentSnapshot>(
      future: _chatInitFuture, // <-- Dùng biến đã lưu, không tạo mới
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: topazColor));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final isGroup = data?['isGroup'] as bool? ?? false;

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
            targetUserId: resolvedTargetId,
            isGroup: isGroup,
          ),
        );
      },
    );
  }
}

// =======================================================
// Widget for displaying the list of all chats (Giữ nguyên)
// =======================================================
class _ChatListView extends StatelessWidget {
  final User currentUser;
  final String searchQuery;
  const _ChatListView({required this.currentUser, required this.searchQuery});

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

        final chatDocs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final isHidden = data['userHidden'] is Map && (data['userHidden'] as Map)[currentUser.uid] == true;

          // SỬA LỖI: CHỈ LỌC CÁC TIN NHẮN BỊ ẨN, KHÔNG LỌC THEO TÊN
          // Việc lọc theo tên sẽ được xử lý ở cấp _ChatListItem
          return !isHidden;
        }).toList();

        if (chatDocs.isEmpty) {
          // SỬA: Hiển thị thông báo khi không tìm thấy
          if (searchQuery.isNotEmpty) {
            return Center(child: Text('Không tìm thấy kết quả nào cho "$searchQuery"', style: const TextStyle(color: sonicSilver)));
          }
          return const Center(child: Text('Chưa có cuộc trò chuyện nào.', style: TextStyle(color: sonicSilver)));
        }

        // SỬA: Truyền searchQuery vào _ChatListItem
        return ListView.builder(
          itemCount: chatDocs.length,
          itemBuilder: (context, index) => _ChatListItem(
            chatDoc: chatDocs[index],
            currentUser: currentUser,
            searchQuery: searchQuery, // TRUYỀN QUERY XUỐNG
          ),
        );
      },
    );
  }
}

// BỔ SUNG: Widget hiển thị Tin nhắn được Ghim
class _PinnedMessageView extends StatelessWidget {
  final String text;
  final VoidCallback onDismiss;

  const _PinnedMessageView({required this.text, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: darkSurface,
      child: Row(
        children: [
          const Icon(Icons.push_pin, color: topazColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: whiteColor, fontSize: 13),
            ),
          ),
          InkWell(
            onTap: onDismiss,
            child: const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Icon(Icons.close, color: sonicSilver, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}


// BỔ SUNG: Widget hiển thị trạng thái đang trả lời
class _ReplyPreview extends StatelessWidget {
  final String senderName;
  final String text;
  final VoidCallback onCancel;

  const _ReplyPreview({
    required this.senderName,
    required this.text,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: lightGrey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: topazColor, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trả lời $senderName', style: const TextStyle(color: topazColor, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: sonicSilver, fontSize: 12),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onCancel,
            child: const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Icon(Icons.close, color: sonicSilver, size: 18),
            ),
          ),
        ],
      ),
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
  final FocusNode _messageFocusNode = FocusNode(); // <--- FIX LỖI 2: Thêm FocusNode
  String _currentUserName = 'Bạn';
  late String _otherUserId;
  List<String> _groupParticipants = [];

  // BỔ SUNG: State cho tính năng mới
  Map<String, dynamic>? _replyingToMessage; // {id, senderName, text}
  String? _pinnedMessageId;
  Map<String, dynamic>? _pinnedMessageData;

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

    // Bổ sung: Lắng nghe trạng thái ghim
    _fetchPinnedMessage();
  }

  // BỔ SUNG: Logic Lấy tin nhắn được ghim
  void _fetchPinnedMessage() {
    _firestore.collection('chats').doc(widget.chatId).snapshots().listen((snapshot) {
      if (mounted && snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          setState(() {
            _pinnedMessageId = data['pinnedMessageId'] as String?;
            _pinnedMessageData = {
              'text': data['pinnedMessageText'] ?? 'Đã ghim một tin nhắn',
            };
          });
        }
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
    _messageFocusNode.dispose(); // <--- FIX LỖI 2: Dispose FocusNode
    super.dispose();
  }

  // BỔ SUNG: Logic Trả lời
  void _setReply(Map<String, dynamic> messageData) {
    setState(() {
      _replyingToMessage = {
        'id': messageData['messageId'],
        'senderName': messageData['senderName'],
        'text': messageData['text']
      };
    });
    // Request focus for better UX
    SchedulerBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_messageFocusNode);
    });
  }

  void _clearReply() {
    // SỬA: Đảm bảo việc xóa context trả lời gọi setState an toàn
    setState(() {
      _replyingToMessage = null;
    });
  }

  // SỬA: Cập nhật _sendMessage
  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final replyContext = _replyingToMessage;
    _clearReply();

    DocumentSnapshot myUserDoc = await _firestore.collection('users').doc(widget.currentUser.uid).get();
    final myData = myUserDoc.data() as Map<String, dynamic>? ?? {};
    final String senderName = myData['displayName'] ?? 'Người dùng Zink';
    final String? senderAvatarUrl = myData['photoURL'];

    // ... (logic kiểm tra chặn/block giữ nguyên)

    if (!widget.isGroup && widget.targetUserId.isNotEmpty) {
      final otherUserDoc = await _firestore.collection('users').doc(widget.targetUserId).get();
      final blockedUids = otherUserDoc.data()?['blockedUids'] as List<dynamic>? ?? [];

      if (blockedUids.contains(widget.currentUser.uid)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể gửi tin nhắn. Bạn đã bị chặn.'), backgroundColor: coralRed));
        return;
      }

      final myDoc = await _firestore.collection('users').doc(widget.currentUser.uid).get();
      final myBlockedUids = myDoc.data()?['blockedUids'] as List<dynamic>? ?? [];
      if (myBlockedUids.contains(widget.targetUserId)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể gửi tin nhắn. Bạn đã chặn người dùng này.'), backgroundColor: coralRed));
        return;
      }
    }

    // ... (logic lấy senderAvatarUrl giữ nguyên)

    final messageContent = {
      'senderId': widget.currentUser.uid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'isRead': false,
      'isRecalled': false,
      'deletedFor': [],
      'replyTo': replyContext,
    };

    try {
      final chatRef = _firestore.collection('chats').doc(widget.chatId);
      final batch = _firestore.batch();

      final newMessageRef = chatRef.collection('messages').doc();
      batch.set(newMessageRef, messageContent);

      final updateData = <String, dynamic>{
        'lastMessage': text,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      };

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

      // BỔ SUNG LOGIC GỬI THÔNG BÁO KHI TRẢ LỜI
      if (replyContext != null) {
        final repliedToSenderId = replyContext['senderId'] as String?;

        // Gửi thông báo đến người được trả lời nếu không phải chính mình
        if (repliedToSenderId != null && repliedToSenderId != widget.currentUser.uid) {
          final notificationRef = _firestore
              .collection('users')
              .doc(repliedToSenderId)
              .collection('notifications')
              .doc();

          batch.set(notificationRef, {
            'type': 'reply_message', // <-- Loại thông báo mới
            'senderId': widget.currentUser.uid,
            'senderName': senderName,
            'senderAvatarUrl': senderAvatarUrl,
            'destinationId': widget.chatId, // ID của chat
            'contentPreview': 'đã trả lời tin nhắn của bạn trong chat "${widget.targetUserName}".',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
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

      // QUAN TRỌNG: DÒNG NÀY PHẢI ĐẢM BẢO unreadCount được reset về 0
      batch.update(_firestore.collection('chats').doc(widget.chatId), {
        unreadField: 0,
      }); // <--- Đã được code đúng

      batch.commit().catchError((_) {});
    });
  }

  // BỔ SUNG: Logic Thu hồi/Xóa tin nhắn (Firestore)
  void _recallMessage(String messageId) async {
    // Thu hồi (Xóa đối với mọi người)
    await _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'text': 'Tin nhắn đã được thu hồi',
      'isRecalled': true,
      'replyTo': null,
    });
  }

  void _deleteMessageForMe(String messageId) async {
    // Xóa đối với bạn (Thêm UID vào danh sách deletedFor)
    await _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'deletedFor': FieldValue.arrayUnion([widget.currentUser.uid])
    });
  }

  // BỔ SUNG: Logic Ghim tin nhắn (Firestore)
  void _pinMessage(String messageId, String messageText) async {
    final currentUserId = widget.currentUser.uid;

    // 1. Lấy thông tin người ghim
    final myUserDoc = await _firestore.collection('users').doc(currentUserId).get();
    final myData = myUserDoc.data() as Map<String, dynamic>? ?? {};
    final senderName = myData['displayName'] ?? 'Người dùng Zink';
    final senderAvatarUrl = myData['photoURL'];
    final chatName = widget.targetUserName;

    // 2. Cập nhật chat document (trong batch)
    final chatRef = _firestore.collection('chats').doc(widget.chatId);
    final batch = _firestore.batch();

    batch.update(chatRef, {
      'pinnedMessageId': messageId,
      'pinnedMessageText': messageText,
    });

    // 3. Gửi thông báo đến TẤT CẢ thành viên (trừ người ghim)
    final recipients = widget.isGroup
        ? _groupParticipants.where((uid) => uid != currentUserId).toList()
        : [widget.targetUserId].where((uid) => uid != currentUserId).toList();

    for (final recipientId in recipients) {
      if (recipientId.isNotEmpty) {
        final notificationRef = _firestore
            .collection('users')
            .doc(recipientId)
            .collection('notifications')
            .doc();

        batch.set(notificationRef, {
          'type': 'pin_message', // <-- Loại thông báo mới
          'senderId': currentUserId,
          'senderName': senderName,
          'senderAvatarUrl': senderAvatarUrl,
          'destinationId': widget.chatId, // ID của chat
          'contentPreview': 'đã ghim một tin nhắn trong chat "$chatName".',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }
    }

    await batch.commit();
  }

  // BỔ SUNG: Hàm xử lý Long Press (Menu tương tác)
  void _handleMessageLongPress(Map<String, dynamic> messageData) async {
    final bool isMyMessage = messageData['senderId'] == widget.currentUser.uid;
    final String messageId = messageData['messageId'];
    final String messageText = messageData['text'];
    final bool isRecalled = messageData['isRecalled'] ?? false;

    String senderName = 'Người dùng';
    if (!isMyMessage) {
      final senderDoc = await _firestore.collection('users').doc(messageData['senderId']).get();
      senderName = (senderDoc.data() as Map<String, dynamic>?)?['displayName'] ?? 'Người dùng';
    } else {
      senderName = _currentUserName;
    }
    messageData['senderName'] = senderName;

    showModalBottomSheet(
      context: context,
      backgroundColor: darkSurface,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Trả lời (Chỉ khi tin nhắn chưa bị thu hồi)
              if (!isRecalled)
                ListTile(
                  leading: const Icon(Icons.reply, color: whiteColor),
                  title: const Text('Trả lời', style: TextStyle(color: whiteColor)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _setReply(messageData);
                  },
                ),
              // Ghim / Bỏ ghim
              if (!isRecalled)
                ListTile(
                  leading: Icon(_pinnedMessageId == messageId ? Icons.push_pin : Icons.push_pin_outlined, color: whiteColor),
                  title: Text(_pinnedMessageId == messageId ? 'Bỏ ghim' : 'Ghim tin nhắn', style: const TextStyle(color: whiteColor)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    if (_pinnedMessageId == messageId) {
                      _firestore.collection('chats').doc(widget.chatId).update({
                        'pinnedMessageId': FieldValue.delete(),
                        'pinnedMessageText': FieldValue.delete(),
                      });
                    } else {
                      _pinMessage(messageId, messageText);
                    }
                  },
                ),
              // Xóa tin nhắn (Mở Dialog cho tin nhắn của mình, nếu chưa thu hồi)
              if (isMyMessage && !isRecalled)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: coralRed),
                  title: const Text('Xóa tin nhắn', style: TextStyle(color: coralRed)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showDeleteConfirmationDialog(messageId);
                  },
                )
              // Xóa đối với bạn (Nếu không phải tin nhắn của mình)
              else if (!isMyMessage)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: coralRed),
                  title: const Text('Xóa đối với bạn', style: TextStyle(color: coralRed)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _deleteMessageForMe(messageId);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // BỔ SUNG: Dialog xác nhận xóa
  void _showDeleteConfirmationDialog(String messageId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: darkSurface,
          title: const Text('Xóa tin nhắn', style: TextStyle(color: whiteColor)),
          content: const Text('Bạn muốn xóa tin nhắn này?', style: TextStyle(color: whiteColor)),
          actions: [
            TextButton(
              child: const Text('Xóa đối với bạn', style: TextStyle(color: whiteColor)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteMessageForMe(messageId);
              },
            ),
            TextButton(
              child: const Text('Thu hồi (Mọi người)', style: TextStyle(color: coralRed)),
              onPressed: () {
                Navigator.of(context).pop();
                _recallMessage(messageId);
              },
            ),
          ],
        );
      },
    );
  }


  // BỔ SUNG: Hàm xử lý Avatar Tap (Fix lỗi 3)
  void _handleAvatarTap(String senderId) async {
    if (widget.currentUser.uid == senderId) return;

    if (widget.isGroup) {
      final senderDoc = await _firestore.collection('users').doc(senderId).get();
      final senderName = (senderDoc.data() as Map<String, dynamic>?)?['displayName'] ?? 'Người dùng';

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: darkSurface,
        builder: (BuildContext sheetContext) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline, color: whiteColor),
                  title: Text('Xem trang cá nhân của $senderName', style: const TextStyle(color: whiteColor)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(
                          targetUserId: senderId,
                          onNavigateToHome: () {},
                          onLogout: () {},
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.message_outlined, color: topazColor),
                  title: Text('Nhắn tin riêng với $senderName', style: const TextStyle(color: whiteColor)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MessageScreen(
                          targetUserId: senderId,
                          targetUserName: senderName,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ProfileScreen(
            targetUserId: senderId,
            onNavigateToHome: () {},
            onLogout: () {},
          ),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BỔ SUNG: Hiển thị tin nhắn được ghim
        if (_pinnedMessageId != null && _pinnedMessageData != null)
          _PinnedMessageView(
            text: _pinnedMessageData!['text'] ?? 'Đã ghim một tin nhắn',
            onDismiss: () {
              _firestore.collection('chats').doc(widget.chatId).update({
                'pinnedMessageId': FieldValue.delete(),
                'pinnedMessageText': FieldValue.delete(),
              });
            },
          ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('chats')
                .doc(widget.chatId)
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

              final allMessages = snapshot.data?.docs ?? [];
              final messages = allMessages.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final deletedFor = data['deletedFor'] as List<dynamic>? ?? [];
                return !deletedFor.contains(widget.currentUser.uid);
              }).toList();

              if (messages.isEmpty) {
                return Center(child: Text('Bắt đầu cuộc trò chuyện với ${widget.targetUserName}!', style: const TextStyle(color: sonicSilver)));
              }
              _markMessagesAsRead(allMessages);

              return ListView.builder(
                reverse: true,
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                itemCount: messages.length,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                itemBuilder: (context, index) {
                  final messageDoc = messages[index];
                  final data = messageDoc.data() as Map<String, dynamic>;
                  final messageId = messageDoc.id;

                  final replyTo = data['replyTo'] as Map<String, dynamic>?;
                  final isRecalled = data['isRecalled'] as bool? ?? false;

                  final currentMsgTimestamp = data['timestamp'] as Timestamp? ?? Timestamp.now();
                  final DateTime currentDate = currentMsgTimestamp.toDate();
                  final String senderId = data['senderId'] ?? '';

                  // ... (logic date header)

                  final bubble = _MessageBubble(
                    messageId: messageId,
                    senderId: senderId,
                    text: data['text'] ?? '',
                    timestamp: currentMsgTimestamp,
                    isMe: (data['senderId'] ?? '') == widget.currentUser.uid,
                    isRead: data['isRead'] ?? false,
                    isGroup: widget.isGroup,
                    onAvatarTap: _handleAvatarTap, // <--- Đã sửa lỗi 3
                    onLongPress: _handleMessageLongPress,
                    replyTo: replyTo,
                    isRecalled: isRecalled,
                    isPinned: _pinnedMessageId == messageId,
                    data: data, // <<< KHẮC PHỤC LỖI: TRUYỀN TOÀN BỘ DATA
                  );

                  // ... (logic date header)

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

  // SỬA: Cập nhật _buildMessageInput để hiển thị trạng thái đang trả lời (Fix lỗi 2)
  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.only(left: 12, right: 12, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: darkSurface,
        border: Border(top: BorderSide(color: sonicSilver.withOpacity(0.2))),
      ),
      child: Material(
        color: darkSurface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_replyingToMessage != null)
              _ReplyPreview(
                senderName: _replyingToMessage!['senderName'] ?? 'Người dùng',
                text: _replyingToMessage!['text'] ?? 'Tin nhắn',
                onCancel: _clearReply,
              ),

            Row(
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
                        focusNode: _messageFocusNode, // <--- FIX LỖI 2: Sử dụng FocusNode
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
          ],
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
// Widget for a single message bubble (Đã cập nhật)
// =======================================================
class _MessageBubble extends StatelessWidget {
  final String messageId;
  final String senderId;
  final String text;
  final Timestamp timestamp;
  final bool isMe;
  final bool isRead;
  final bool isGroup;
  final Function(String senderId) onAvatarTap;
  final Map<String, dynamic> data; // <<< KHẮC PHỤC LỖI: TRƯỜNG DỮ LIỆU ĐƯỢC THÊM

  final Function(Map<String, dynamic> messageData) onLongPress;
  final Map<String, dynamic>? replyTo;
  final bool isRecalled;
  final bool isPinned;

  const _MessageBubble({
    required this.messageId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.isRead = false,
    required this.isGroup,
    required this.onAvatarTap,
    required this.onLongPress,
    this.replyTo,
    required this.isRecalled,
    required this.isPinned,
    required this.data, // <<< KHẮC PHỤC LỖI: TRUYỀN DỮ LIỆU VÀO
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

    return _buildBubbleLayout(context, timeString, null, isMe, isRead, text);
  }

  // Hàm helper để xây dựng layout bong bóng
  Widget _buildBubbleLayout(BuildContext context, String timeString, ImageProvider? avatarProvider, bool isMe, bool isRead, String text) {

    // KHẮC PHỤC LỖI: Sử dụng this.data
    final bool isSharedPost = this.data['type'] == 'shared_post' && this.data['postId'] != null;
    final String? sharedPostId = isSharedPost ? this.data['postId'] as String : null;

    final String displayText = isRecalled ? '🚫 Tin nhắn đã được thu hồi' : text;
    final Color bubbleColor = isMe ? topazColor : darkSurface;
    final Color textColor = isMe ? Colors.black : Colors.white;
    final Color timeColor = isMe ? Colors.black54 : Colors.white38;

    // 1. Định nghĩa nội dung của bong bóng tin nhắn (Container)
    final messageBubbleContent = Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.70),
        decoration: BoxDecoration(
          color: isRecalled ? lightGrey.withOpacity(0.1) : bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(2),
            bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // HIỂN THỊ POST ĐƯỢC CHIA SẺ
            if (isSharedPost && sharedPostId != null)
              _buildSharedPostCard(context, sharedPostId), // <<< WIDGET MỚI

            // ... (Phần hiển thị Reply Context và Icon Ghim giữ nguyên)
            if (replyTo != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: lightGrey.withOpacity(isMe ? 0.4 : 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border(left: BorderSide(color: isMe ? Colors.black54 : topazColor, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(replyTo!['senderName'] ?? 'Người dùng', style: TextStyle(color: isMe ? Colors.black54 : topazColor, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      replyTo!['text'] ?? '...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: isMe ? Colors.black54 : sonicSilver, fontSize: 11),
                    ),
                  ],
                ),
              ),

            // Icon Ghim
            if (isPinned)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.push_pin, size: 12, color: isMe ? Colors.black54 : sonicSilver),
                    const SizedBox(width: 4),
                    Text('Đã ghim', style: TextStyle(color: isMe ? Colors.black54 : sonicSilver, fontSize: 11)),
                  ],
                ),
              ),

            // Nội dung tin nhắn văn bản
            if (!isSharedPost || text.isNotEmpty)
              Padding(
                padding: isSharedPost ? const EdgeInsets.only(top: 8.0) : EdgeInsets.zero,
                child: Text(
                  displayText,
                  style: TextStyle(
                    color: isRecalled ? sonicSilver : textColor,
                    fontSize: 15,
                    fontStyle: isRecalled ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),

            // ... (Phần hiển thị Timestamp và Read Status giữ nguyên)
            const SizedBox(height: 4),
            Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeString,
                    style: TextStyle(
                      color: timeColor,
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
        )
    );

    // 2. Bọc nội dung bằng GestureDetector chỉ để xử lý LongPress
    final tappableBubble = isRecalled ? messageBubbleContent : GestureDetector(
      onLongPress: () {
        onLongPress({
          'messageId': messageId,
          'senderId': senderId,
          'text': this.text,
          'isRecalled': isRecalled,
        });
      },
      child: messageBubbleContent,
    );

    // 3. Trả về Row chứa Avatar (nếu có) và Bong bóng tin nhắn
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (Chỉ có GestureDetector cho onTap)
          if (!isMe) ...[
            GestureDetector(
              onTap: () => onAvatarTap(senderId),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: darkSurface,
                backgroundImage: avatarProvider,
                child: avatarProvider == null ? const Icon(Icons.person, size: 16, color: sonicSilver) : null,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Bong bóng tin nhắn đã được bọc LongPress
          tappableBubble,

          if (isMe) const SizedBox(width: 40),
        ],
      ),
    );
  }

  // KHẮC PHỤC LỖI: THÊM WIDGET _buildSharedPostCard VÀO ĐÂY
  Widget _buildSharedPostCard(BuildContext context, String postId) {
    // 1. Truy vấn Post Data
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('posts').doc(postId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: topazColor)));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: coralRed.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: const Text('Bài viết đã bị xóa hoặc không còn tồn tại.', style: TextStyle(color: coralRed, fontSize: 13)),
          );
        }

        final postData = snapshot.data!.data() as Map<String, dynamic>;
        final String authorName = postData['displayName'] ?? 'Người dùng';
        final String caption = postData['postCaption'] ?? 'Không có chú thích.';
        final String? imageUrl = postData['imageUrl'] as String?;
        final ImageProvider? imageProvider = (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null;

        // 2. Hiển thị Post Card mini
        return GestureDetector(
          onTap: () {
            // Điều hướng đến chi tiết bài viết khi nhấn vào
            Navigator.of(context).push(MaterialPageRoute(
              builder: (ctx) => PostDetailScreen(postData: {...postData, 'id': postId}), // <<< KHẮC PHỤC LỖI CLASS
            ));
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: sonicSilver.withOpacity(0.3))
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, color: sonicSilver, size: 16),
                    const SizedBox(width: 4),
                    Text(authorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                // Hiển thị ảnh (nếu có)
                if (imageProvider != null)
                  Container(
                    height: 100,
                    margin: const EdgeInsets.only(top: 4, bottom: 4),
                    decoration: BoxDecoration(
                        image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                        borderRadius: BorderRadius.circular(6)
                    ),
                  ),
                // Hiển thị caption (preview)
                Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: sonicSilver, fontSize: 12)),
                const SizedBox(height: 4),
                const Text('Xem bài viết >', style: TextStyle(color: topazColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =======================================================
// Chat List Item (Giữ nguyên)
// =======================================================
class _ChatListItem extends StatefulWidget {
  final DocumentSnapshot chatDoc;
  final User currentUser;
  final String searchQuery;
  const _ChatListItem({required this.chatDoc, required this.currentUser, required this.searchQuery});
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

  @override
  void didUpdateWidget(covariant _ChatListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    final bool isGroup = data['isGroup'] as bool? ?? false;

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
        'userHidden.${widget.currentUser.uid}': FieldValue.delete(),
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
              ListTile(
                leading: Icon(pinActionIcon, color: topazColor),
                title: Text(pinActionText, style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _togglePinChat(isPinned);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: coralRed),
                title: const Text('Ẩn/Xóa tin nhắn (Chỉ mình tôi)', style: TextStyle(color: coralRed)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _deleteChat(widget.chatDoc.id, otherUserName, isGroup);
                },
              ),
              if (isHidden)
                ListTile(
                  leading: const Icon(Icons.restore_page, color: activeGreen),
                  title: const Text('Hoàn tác xóa tin nhắn', style: TextStyle(color: activeGreen)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _unhideChat();
                  },
                ),
              if (isGroup)
                ListTile(
                  leading: const Icon(Icons.logout, color: coralRed),
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

  bool _isChatPinned() {
    final chatData = widget.chatDoc.data() as Map<String, dynamic>?;
    return chatData?['isPinned'] as bool? ?? false;
  }

  void _togglePinChat(bool isCurrentlyPinned) async {
    try {
      await _firestore.collection('chats').doc(widget.chatDoc.id).update({
        'isPinned': !isCurrentlyPinned,
      });
      if (mounted) {
        final message = !isCurrentlyPinned ? 'Đã ghim tin nhắn.' : 'Đã bỏ ghim tin nhắn.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: topazColor));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi: Không thể ghim/bỏ ghim.'), backgroundColor: coralRed));
    }
  }
  void _deleteChat(String chatId, String chatName, bool isGroup) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: darkSurface,
          title: const Text('Ẩn tin nhắn', style: TextStyle(color: Colors.white)),
          content: const Text('Bạn có chắc chắn muốn ẩn/xóa tin nhắn này (chỉ mình bạn không thấy)?', style: TextStyle(color: sonicSilver)),
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
        await _firestore.collection('chats').doc(chatId).update({
          'userHidden.${widget.currentUser.uid}': true,
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã ẩn tin nhắn với $chatName.'), backgroundColor: sonicSilver));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi: Không thể ẩn tin nhắn.'), backgroundColor: coralRed));
      }
    }
  }

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

        final myUserDoc = await _firestore.collection('users').doc(widget.currentUser.uid).get();
        final myUserData = myUserDoc.data() as Map<String, dynamic>? ?? {};
        final currentUserName = myUserData['displayName'] as String? ?? 'Một thành viên';

        await chatRef.update({
          'participants': FieldValue.arrayRemove([widget.currentUser.uid]),
          'unreadCount.${widget.currentUser.uid}': FieldValue.delete(),
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

    if (widget.searchQuery.isNotEmpty) {
      final queryLower = widget.searchQuery.toLowerCase();
      final nameLower = otherUserName.toLowerCase();

      // Kiểm tra khớp với tên người dùng/tên nhóm
      final nameMatch = nameLower.contains(queryLower);

      if (!nameMatch) {
        return const SizedBox.shrink(); // Ẩn nếu không khớp tên/nhóm
      }
    }

    final String lastMessage = chatData['lastMessage'] ?? 'Bắt đầu cuộc trò chuyện...';
    final Timestamp? lastMessageTimestamp = chatData['lastMessageTimestamp'];

    final String currentUserId = widget.currentUser.uid;
    final unreadCountMap = chatData['unreadCount'] as Map<String, dynamic>? ?? {};
    final int unreadCount = (unreadCountMap[currentUserId] as num?)?.toInt() ?? 0;
    final bool hasUnread = unreadCount > 0;

    final List<dynamic> participants = chatData['participants'] ?? [];
    final String otherUserId = isGroup
        ? ''
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
      title: Row(
        children: [
          Text(
              otherUserName,
              style: TextStyle(
                color: whiteColor,
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
              )
          ),
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
      onTap: null,
    );

    return GestureDetector(
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
      onLongPress: () => _showChatContextMenu(otherUserName, isGroup, otherUserId),
      child: listTileContent,
    );
  }
}
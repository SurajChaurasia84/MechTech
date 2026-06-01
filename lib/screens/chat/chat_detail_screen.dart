import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';

class ChatDetailScreen extends StatefulWidget {
  final String roomId;
  final String recipientId;
  final String recipientName;
  final String recipientPhotoUrl;
  final String recipientRole;

  const ChatDetailScreen({
    super.key,
    required this.roomId,
    required this.recipientId,
    required this.recipientName,
    required this.recipientPhotoUrl,
    required this.recipientRole,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  DateTime? _lastMessageSentAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      _markChatAsRead(appState.userRole ?? 'customer');
    });
  }

  void _markChatAsRead(String role) {
    final updateField = role == 'customer' ? 'unreadByCustomer' : 'unreadByMechanic';
    FirebaseFirestore.instance.collection('chats').doc(widget.roomId).update({
      updateField: false,
    }).catchError((e) {
      debugPrint("Error marking chat as read: $e");
    });
  }

  String _filterAbusiveContent(String text) {
    final List<String> blacklistedWords = [
      'abuse', 'bastard', 'scam', 'fraud', 'cheat', 'bitch', 'asshole', 'fuck', 'shit', 'idiot', 'stupid', 'harass'
    ];
    String filtered = text;
    for (final word in blacklistedWords) {
      final regExp = RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false);
      filtered = filtered.replaceAllMapped(regExp, (match) => '*' * match.group(0)!.length);
    }
    return filtered;
  }

  void _sendMessage(AppState appState) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Abuse Prevention: Rate Limiter (1.5 seconds cool-down)
    final now = DateTime.now();
    if (_lastMessageSentAt != null && now.difference(_lastMessageSentAt!) < const Duration(milliseconds: 1500)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait a moment before sending another message.'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _lastMessageSentAt = now;

    // Abuse Prevention: Filter profanity and sensitive words
    final filteredText = _filterAbusiveContent(text);
    _messageController.clear();

    final currentUserId = appState.user?.uid;
    final currentUserName = appState.currentCustomerName ?? 'User';
    final role = appState.userRole ?? 'customer';

    if (currentUserId == null) return;

    final batch = FirebaseFirestore.instance.batch();

    // 1. Add Message to Subcollection
    final messageRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.roomId)
        .collection('messages')
        .doc();

    batch.set(messageRef, {
      'senderId': currentUserId,
      'senderName': currentUserName,
      'text': filteredText,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. Update Chat Room metadata
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.roomId);
    batch.update(chatRef, {
      'lastMessage': filteredText,
      'lastSenderId': currentUserId,
      'timestamp': FieldValue.serverTimestamp(),
      'unreadByCustomer': role == 'mechanic',
      'unreadByMechanic': role == 'customer',
    });

    try {
      await batch.commit();
      _scrollToBottom();
      
      // Trigger push notification to message recipient
      appState.sendNotification(
        recipientUid: widget.recipientId,
        title: 'New Message from $currentUserName',
        body: filteredText,
      );
    } catch (e) {
      debugPrint("Error sending message: $e");
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  String _formatMessageTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final date = timestamp.toDate();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Today';
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildDateChip(String label) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF8B88A5),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currentUserId = appState.user?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161426),
        elevation: 0,
        titleSpacing: 0,
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.recipientId).snapshots(),
          builder: (context, snapshot) {
            String name = widget.recipientName;
            String photoUrl = widget.recipientPhotoUrl;

            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              if (data != null) {
                name = data['name'] as String? ?? name;
                photoUrl = data['photoUrl'] as String? ?? photoUrl;
              }
            }

            return Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF302B53),
                  backgroundImage: photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl.isEmpty
                      ? const Icon(Icons.person, color: Colors.white, size: 18)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                      Text(
                        widget.recipientRole,
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8B88A5)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.roomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading messages.', style: GoogleFonts.inter(color: Colors.redAccent)),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)));
                }

                final docs = snapshot.data?.docs ?? [];
                
                // Trigger auto-scroll on new message load
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF302B53), size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet.\nStart the conversation below.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final msg = docs[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == currentUserId;
                    final time = _formatMessageTime(msg['timestamp'] as Timestamp?);
                    final ts = msg['timestamp'] as Timestamp?;
                    final msgDate = ts?.toDate();

                    // Show date separator if this is first msg OR date changed
                    bool showDateSep = false;
                    if (msgDate != null) {
                      if (index == 0) {
                        showDateSep = true;
                      } else {
                        final prevMsg = docs[index - 1].data() as Map<String, dynamic>;
                        final prevTs = prevMsg['timestamp'] as Timestamp?;
                        final prevDate = prevTs?.toDate();
                        if (prevDate != null && !_isSameDay(msgDate, prevDate)) {
                          showDateSep = true;
                        }
                      }
                    }

                    return Column(
                      children: [
                        if (showDateSep && msgDate != null)
                          _buildDateChip(_formatDateLabel(msgDate)),
                        Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe ? const Color(0xFF08693F) : const Color(0xFF161426),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(isMe ? 16 : 0),
                                      bottomRight: Radius.circular(isMe ? 0 : 16),
                                    ),
                                    border: Border.all(
                                      color: isMe ? Colors.transparent : const Color(0xFF302B53),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Text(
                                    msg['text'] ?? '',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 14,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  time,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF8B88A5),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // Input bar with character limit
          Container(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 28, top: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF161426),
              border: Border(
                top: BorderSide(
                  color: const Color(0xFF302B53).withValues(alpha: 0.5),
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0B18),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF302B53)),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                      maxLength: 300,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null, // Hide counter text to keep input bar compact
                      decoration: InputDecoration(
                        hintText: 'Type message... (Max 300)',
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF8B88A5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: InputBorder.none,
                        counterText: '',
                      ),
                      onSubmitted: (_) => _sendMessage(appState),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF00E676),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF0D0B18), size: 20),
                    onPressed: () => _sendMessage(appState),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

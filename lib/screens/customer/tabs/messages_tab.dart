import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  final List<Map<String, dynamic>> _chats = [
    {
      'name': 'Arjun Mehta',
      'role': 'Engine Specialist',
      'avatarLetter': 'A',
      'lastMessage': 'I am on my way to your location, should be there in 15 mins.',
      'time': '10:35 AM',
      'unread': true,
      'isOnline': true,
    },
    {
      'name': 'Priya Nair',
      'role': 'Electrical & AC Expert',
      'avatarLetter': 'P',
      'lastMessage': 'The wiring issue is resolved. You can test the AC now.',
      'time': 'Yesterday',
      'unread': false,
      'isOnline': false,
    },
    {
      'name': 'MechTech Support',
      'role': 'Help desk',
      'avatarLetter': 'M',
      'lastMessage': 'Your refund request has been processed successfully.',
      'time': '25 May',
      'unread': false,
      'isOnline': true,
    }
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
      itemCount: _chats.length,
      itemBuilder: (context, index) {
        final chat = _chats[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161426),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: chat['unread']
                    ? const Color(0xFF00E676).withOpacity(0.5)
                    : const Color(0xFF302B53).withOpacity(0.6),
                width: chat['unread'] ? 1.5 : 1.0,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() {
                    chat['unread'] = false;
                  });
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatDetailScreen(
                        name: chat['name'],
                        role: chat['role'],
                        isOnline: chat['isOnline'],
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Avatar with online badge
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: const Color(0xFF0D0B18),
                            child: Text(
                              chat['avatarLetter'],
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF00E676),
                              ),
                            ),
                          ),
                          if (chat['isOnline'])
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E676),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF161426),
                                    width: 2.0,
                                  ),
                                ),
                              ),
                            )
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Text info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  chat['name'],
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  chat['time'],
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF8B88A5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              chat['role'],
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF00B0FF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              chat['lastMessage'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: chat['unread'] ? Colors.white : const Color(0xFF8B88A5),
                                fontWeight: chat['unread'] ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ChatDetailScreen extends StatefulWidget {
  final String name;
  final String role;
  final bool isOnline;

  const ChatDetailScreen({
    super.key,
    required this.name,
    required this.role,
    required this.isOnline,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {
      'text': 'Hi, I booked a periodic full service. When can I expect you?',
      'isMe': true,
      'time': '10:30 AM',
    },
    {
      'text': 'Hello! Thanks for booking. I am loading my tools now and heading out.',
      'isMe': false,
      'time': '10:32 AM',
    },
    {
      'text': 'I am on my way to your location, should be there in 15 mins.',
      'isMe': false,
      'time': '10:35 AM',
    }
  ];

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        'text': text,
        'isMe': true,
        'time': 'Just now',
      });
      _messageController.clear();
    });

    // Auto mock response
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _messages.add({
            'text': 'Understood. I will call you when I arrive at your location.',
            'isMe': false,
            'time': 'Just now',
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161426),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.name,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.isOnline ? const Color(0xFF00E676) : const Color(0xFF8B88A5),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.isOnline ? 'Online' : 'Offline',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8B88A5)),
                ),
              ],
            )
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['isMe'] == true;

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Column(
                      crossAxisAlignment:
                          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                            msg['text'],
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          msg['time'],
                          style: GoogleFonts.inter(
                            color: const Color(0xFF8B88A5),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Input bar
          Container(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 28, top: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF161426),
              border: Border(
                top: BorderSide(
                  color: const Color(0xFF302B53).withOpacity(0.5),
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
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF8B88A5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF00E676),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF0D0B18), size: 20),
                    onPressed: _sendMessage,
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

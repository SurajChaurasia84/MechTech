import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../customer/tabs/messages_tab.dart';

class MechanicMessagesTab extends StatefulWidget {
  const MechanicMessagesTab({super.key});

  @override
  State<MechanicMessagesTab> createState() => _MechanicMessagesTabState();
}

class _MechanicMessagesTabState extends State<MechanicMessagesTab> {
  final List<Map<String, dynamic>> _chats = [
    {
      'name': 'Amit Verma',
      'vehicle': 'Tata Nexon EV',
      'avatarLetter': 'A',
      'lastMessage': 'Hi, are you bringing the diagnostic scanner tool?',
      'time': '11:15 AM',
      'unread': true,
      'isOnline': true,
    },
    {
      'name': 'Sunita Rao',
      'vehicle': 'Activa 6G',
      'avatarLetter': 'S',
      'lastMessage': 'Yes, please replace the engine oil and clean spark plugs.',
      'time': 'Yesterday',
      'unread': false,
      'isOnline': false,
    },
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
                        role: chat['vehicle'],
                        isOnline: chat['isOnline'],
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Avatar
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
                      // Text Info
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
                              chat['vehicle'],
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

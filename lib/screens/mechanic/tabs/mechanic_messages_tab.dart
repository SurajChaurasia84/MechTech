import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../services/app_state.dart';
import '../../chat/chat_detail_screen.dart';

class MechanicMessagesTab extends StatefulWidget {
  const MechanicMessagesTab({super.key});

  @override
  State<MechanicMessagesTab> createState() => _MechanicMessagesTabState();
}

class _MechanicMessagesTabState extends State<MechanicMessagesTab> {
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${date.day} ${months[date.month - 1]}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currentUserId = appState.user?.uid;

    if (currentUserId == null) {
      return Center(
        child: Text(
          'Please sign in to view messages.',
          style: GoogleFonts.inter(color: const Color(0xFF8B88A5)),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('mechanicId', isEqualTo: currentUserId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading messages.',
              style: GoogleFonts.inter(color: Colors.redAccent),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.forum_outlined, color: Color(0xFF302B53), size: 48),
                const SizedBox(height: 12),
                Text(
                  'No messages yet.\nYour inbox will fill up when clients message you.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final chatDoc = docs[index];
            final chat = chatDoc.data() as Map<String, dynamic>;
            final roomId = chatDoc.id;

            final name = chat['customerName'] as String? ?? 'Client';
            final lastMessage = chat['lastMessage'] as String? ?? 'No messages yet';
            final unread = chat['unreadByMechanic'] == true;
            final photoUrl = chat['customerPhotoUrl'] as String?;
            final timeStr = _formatTimestamp(chat['timestamp'] as Timestamp?);
            final avatarLetter = name.isNotEmpty ? name[0].toUpperCase() : 'C';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161426),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: unread
                        ? const Color(0xFF00E676).withOpacity(0.5)
                        : const Color(0xFF302B53).withOpacity(0.6),
                    width: unread ? 1.5 : 1.0,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatDetailScreen(
                            roomId: roomId,
                            recipientId: chat['customerId'] ?? '',
                            recipientName: name,
                            recipientPhotoUrl: photoUrl ?? '',
                            recipientRole: 'Client',
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: const Color(0xFF0D0B18),
                            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl == null || photoUrl.isEmpty
                                ? Text(
                                    avatarLetter,
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF00E676),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      timeStr,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: const Color(0xFF8B88A5),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Client',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF00B0FF),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: unread ? Colors.white : const Color(0xFF8B88A5),
                                    fontWeight: unread ? FontWeight.bold : FontWeight.normal,
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
      },
    );
  }
}

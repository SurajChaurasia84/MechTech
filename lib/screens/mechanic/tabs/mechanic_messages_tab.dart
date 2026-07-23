import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../services/app_state.dart';
import '../../chat/chat_detail_screen.dart';

class MechanicMessagesTab extends StatefulWidget {
  final Function(
    Set<String> selectedRoomIds,
    VoidCallback clearSelection,
    Function(BuildContext context) confirmDelete,
  )? onSelectionChanged;

  const MechanicMessagesTab({super.key, this.onSelectionChanged});

  @override
  State<MechanicMessagesTab> createState() => _MechanicMessagesTabState();
}

class _MechanicMessagesTabState extends State<MechanicMessagesTab> {
  final Set<String> _selectedRoomIds = {};

  void _toggleSelection(String roomId) {
    setState(() {
      if (_selectedRoomIds.contains(roomId)) {
        _selectedRoomIds.remove(roomId);
      } else {
        _selectedRoomIds.add(roomId);
      }
    });
    _notifyParentSelection();
  }

  void _notifyParentSelection() {
    widget.onSelectionChanged?.call(
      _selectedRoomIds,
      () {
        if (mounted) {
          setState(() {
            _selectedRoomIds.clear();
          });
        }
      },
      _confirmDeleteSelectedChats,
    );
  }

  void _confirmDeleteSelectedChats(BuildContext context) {
    if (_selectedRoomIds.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161426),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _selectedRoomIds.length == 1 ? 'Delete Chat?' : 'Delete ${_selectedRoomIds.length} Chats?',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This chat will be deleted from your side. The other user will still keep their copy.',
          style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF8B88A5))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteSelectedChats();
            },
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSelectedChats() async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final currentUserId = appState.user?.uid;
      if (currentUserId == null) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final roomId in _selectedRoomIds) {
        final docRef = FirebaseFirestore.instance.collection('chats').doc(roomId);
        final docSnap = await docRef.get();
        if (docSnap.exists) {
          final data = docSnap.data()!;
          final updates = <String, dynamic>{
            'deletedBy_$currentUserId': true,
            'deletedBy': FieldValue.arrayUnion([currentUserId]),
          };
          if (data['customerId'] == currentUserId) {
            updates['deletedByCustomer'] = true;
          }
          if (data['mechanicId'] == currentUserId) {
            updates['deletedByMechanic'] = true;
          }
          batch.update(docRef, updates);
        }
      }
      await batch.commit();

      if (mounted) {
        setState(() {
          _selectedRoomIds.clear();
        });
        _notifyParentSelection();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected chat(s) deleted from your list.'),
            backgroundColor: Color(0xFF161426),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete chats: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

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
          .where(Filter.or(
            Filter('customerId', isEqualTo: currentUserId),
            Filter('mechanicId', isEqualTo: currentUserId),
            Filter('participants', arrayContains: currentUserId),
          ))
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

        final allDocs = snapshot.data?.docs ?? [];
        final docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final isCustomer = data['customerId'] == currentUserId;
          final isMechanic = data['mechanicId'] == currentUserId;
          final isParticipant = (data['participants'] as List?)?.contains(currentUserId) == true;

          if (!isCustomer && !isMechanic && !isParticipant) return false;

          // Check deletion status for current user
          if (data['deletedBy_$currentUserId'] == true) return false;
          if ((data['deletedBy'] as List?)?.contains(currentUserId) == true) return false;
          if (isCustomer && data['deletedByCustomer'] == true) return false;
          if (isMechanic && data['deletedByMechanic'] == true) return false;

          return true;
        }).toList();

        // Sort docs descending by timestamp
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = (aData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = (bData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.forum_outlined, color: Color(0xFF302B53), size: 48),
                const SizedBox(height: 12),
                Text(
                  'Your inbox is empty.',
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
            final isSelected = _selectedRoomIds.contains(roomId);

            final isCustomerRole = chat['customerId'] == currentUserId;

            final recipientId = isCustomerRole
                ? (chat['mechanicId'] as String? ?? '')
                : (chat['customerId'] as String? ?? '');

            final name = isCustomerRole
                ? (chat['mechanicName'] as String? ?? 'Mechanic')
                : (chat['customerName'] as String? ?? 'Customer');

            final photoUrl = isCustomerRole
                ? (chat['mechanicPhotoUrl'] as String?)
                : (chat['customerPhotoUrl'] as String?);

            final roleStr = isCustomerRole ? 'Mechanic Specialist' : 'Customer';

            final unread = isCustomerRole
                ? (chat['unreadByCustomer'] == true)
                : (chat['unreadByMechanic'] == true);

            final lastMessage = chat['lastMessage'] as String? ?? 'No messages yet';
            final timeStr = _formatTimestamp(chat['timestamp'] as Timestamp?);
            final avatarLetter = name.isNotEmpty ? name[0].toUpperCase() : 'U';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2A2040) : const Color(0xFF161426),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF00E676)
                        : unread
                            ? const Color(0xFF00E676).withValues(alpha: 0.5)
                            : const Color(0xFF302B53).withValues(alpha: 0.6),
                    width: isSelected || unread ? 1.5 : 1.0,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onLongPress: () => _toggleSelection(roomId),
                    onTap: () {
                      if (_selectedRoomIds.isNotEmpty) {
                        _toggleSelection(roomId);
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatDetailScreen(
                              roomId: roomId,
                              recipientId: recipientId,
                              recipientName: name,
                              recipientPhotoUrl: photoUrl ?? '',
                              recipientRole: roleStr,
                            ),
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Stack(
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
                              if (isSelected)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF00E676),
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                            ],
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
                                  roleStr,
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

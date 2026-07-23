import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/app_state.dart';
import '../../services/chat_image_cache_service.dart';
import '../customer/mechanic_profile_details_screen.dart';

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
  bool _isRetrievingLocation = false;
  String? _selectedImagePath;
  int _lastDocCount = 0;
  List<Map<String, dynamic>> _cachedMessages = [];

  @override
  void initState() {
    super.initState();
    _loadLocalCachedMessages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      _markChatAsRead(appState.userRole ?? 'customer');
    });
  }

  Future<void> _loadLocalCachedMessages() async {
    final loaded = await ChatMessageCacheService.loadMessages(widget.roomId);
    if (loaded.isNotEmpty && mounted && _cachedMessages.isEmpty) {
      setState(() {
        _cachedMessages = loaded;
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image == null) return;

      setState(() {
        _selectedImagePath = image.path;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _uploadImageInBackground(String msgId, String imagePath, String currentUserId, String currentUserName, String role) async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final imageUrl = await appState.uploadToCloudinary(imagePath);

      if (imageUrl != null) {
        // Cache mapping in SharedPreferences & local disk so sender displays instantly without downloading
        await ChatImageCacheService.cacheLocalFile(imageUrl, imagePath);

        final batch = FirebaseFirestore.instance.batch();
        final messageRef = FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.roomId)
            .collection('messages')
            .doc(msgId);
        
        batch.update(messageRef, {'text': imageUrl});

        final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.roomId);
        batch.update(chatRef, {
          'lastMessage': '📷 Photo',
          'lastSenderId': currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
          'unreadByCustomer': role == 'mechanic',
          'unreadByMechanic': role == 'customer',
        });

        await batch.commit();

        appState.sendNotification(
          recipientUid: widget.recipientId,
          title: 'New Photo from $currentUserName',
          body: '📷 Sent a photo',
        );
      } else {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.roomId)
            .collection('messages')
            .doc(msgId)
            .update({'text': 'local_image_failed:$imagePath'});
      }
    } catch (e) {
      debugPrint('Error uploading image in background: $e');
      try {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.roomId)
            .collection('messages')
            .doc(msgId)
            .update({'text': 'local_image_failed:$imagePath'});
      } catch (_) {}
    }
  }

  Future<void> _sendLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      setState(() {
        _isRetrievingLocation = true;
      });

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

      if (mounted) {
        setState(() {
          _messageController.text = mapsUrl;
          _isRetrievingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRetrievingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error retrieving location: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _sendMessage(AppState appState) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedImagePath == null) return;

    final currentUserId = appState.user?.uid;
    final currentUserName = appState.currentCustomerName ?? 'User';
    final role = appState.userRole ?? 'customer';

    if (currentUserId == null) return;

    // Handle Image Send
    if (_selectedImagePath != null) {
      final imagePath = _selectedImagePath!;
      setState(() {
        _selectedImagePath = null;
      });
      _messageController.clear();
      _scrollToBottom();

      final messageRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.roomId)
          .collection('messages')
          .doc();

      final batch = FirebaseFirestore.instance.batch();
      batch.set(messageRef, {
        'senderId': currentUserId,
        'senderName': currentUserName,
        'text': 'local_image:$imagePath',
        'timestamp': FieldValue.serverTimestamp(),
      });

      final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.roomId);
      batch.update(chatRef, {
        'lastMessage': '📷 Photo',
        'lastSenderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'unreadByCustomer': role == 'mechanic',
        'unreadByMechanic': role == 'customer',
      });

      await batch.commit();
      _uploadImageInBackground(messageRef.id, imagePath, currentUserId, currentUserName, role);
      return;
    }

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
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
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

  bool _isMediaMessage(String text) {
    return text.startsWith('local_image:') ||
        text.startsWith('local_image_failed:') ||
        _isImageUrl(text);
  }

  bool _isImageUrl(String text) {
    if (!text.startsWith('http://') && !text.startsWith('https://')) return false;
    final lower = text.toLowerCase();
    return lower.contains('cloudinary') ||
        lower.contains('firebase') ||
        lower.contains('images') ||
        lower.contains('photo') ||
        lower.contains('res.') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.contains('.jpg?') ||
        lower.contains('.png?') ||
        lower.contains('.jpeg?') ||
        lower.contains('.webp?') ||
        lower.contains('.gif?');
  }

  Widget _buildMessageContent(Map<String, dynamic> msg, bool isMe) {
    final text = msg['text'] as String? ?? '';
    final msgId = msg['id'] ?? text.hashCode.toString();
    final heroTag = 'hero_${msgId}_${text.hashCode}';

    final maxW = MediaQuery.of(context).size.width * 0.70;
    const maxH = 340.0;

    if (text.startsWith('local_image:')) {
      final path = text.substring('local_image:'.length);
      if (isMe) {
        return GestureDetector(
          onTap: () => _openImagePreview(context, path, heroTag: heroTag, isLocal: true),
          child: Hero(
            tag: heroTag,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxW,
                  maxHeight: maxH,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 200,
                          height: 150,
                          color: const Color(0xFF161426),
                          child: const Icon(Icons.broken_image, color: Color(0xFF8B88A5)),
                        );
                      },
                    ),
                    Positioned.fill(
                      child: Container(color: Colors.black38),
                    ),
                    const CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
        return Container(
          width: 200,
          height: 150,
          decoration: BoxDecoration(
            color: const Color(0xFF161426),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E676)),
                SizedBox(height: 10),
                Text(
                  'Receiving photo...',
                  style: TextStyle(color: Color(0xFF8B88A5), fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        );
      }
    } else if (text.startsWith('local_image_failed:')) {
      final path = text.substring('local_image_failed:'.length);
      if (isMe) {
        return GestureDetector(
          onTap: () => _openImagePreview(context, path, heroTag: heroTag, isLocal: true),
          child: Hero(
            tag: heroTag,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxW,
                  maxHeight: maxH,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 200,
                          height: 150,
                          color: const Color(0xFF161426),
                          child: const Icon(Icons.broken_image, color: Color(0xFF8B88A5)),
                        );
                      },
                    ),
                    Positioned.fill(
                      child: Container(color: Colors.black54),
                    ),
                    const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 28),
                        SizedBox(height: 6),
                        Text(
                          'Failed to upload',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
        return Container(
          width: 200,
          height: 150,
          decoration: BoxDecoration(
            color: const Color(0xFF161426),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_outlined, color: Color(0xFF8B88A5), size: 28),
                SizedBox(height: 6),
                Text(
                  'Failed to receive photo',
                  style: TextStyle(color: Color(0xFF8B88A5), fontSize: 11),
                ),
              ],
            ),
          ),
        );
      }
    }
 else if (_isImageUrl(text)) {
      return _CachedChatImageBubble(
        imageUrl: text,
        heroTag: heroTag,
        onTap: () => _openImagePreview(context, text, heroTag: heroTag, isLocal: false),
      );
    } else if (text.startsWith('https://www.google.com/maps/search/?api=1&query=')) {
      return GestureDetector(
        onTap: () async {
          final uri = Uri.parse(text);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: _LocationBubbleContent(mapsUrl: text, isMe: isMe),
      );
    } else {
      return Text(
        text,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 14,
          height: 1.3,
        ),
      );
    }
  }

  void _openImagePreview(BuildContext context, String url, {required String heroTag, bool isLocal = false}) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) => _FullScreenImagePreview(
          imageUrl: url,
          heroTag: heroTag,
          isLocal: isLocal,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
              reverseCurve: Curves.easeIn,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
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

            Map<String, dynamic> userMap = {};

            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              if (data != null) {
                userMap = data;
                name = data['name'] as String? ?? name;
                photoUrl = data['photoUrl'] as String? ?? photoUrl;
              }
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final mechData = <String, dynamic>{
                  ...userMap,
                  'mechanicId': widget.recipientId,
                  'uid': widget.recipientId,
                  'id': widget.recipientId,
                  'name': name,
                  'photoUrl': photoUrl,
                  'role': widget.recipientRole,
                };

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MechanicProfileDetailsScreen(
                      mechanic: mechData,
                    ),
                  ),
                );
              },
              child: Row(
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
              ),
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
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError && _cachedMessages.isEmpty) {
                  return Center(
                    child: Text('Error loading messages.', style: GoogleFonts.inter(color: Colors.redAccent)),
                  );
                }

                if (snapshot.hasData) {
                  final newDocs = snapshot.data!.docs;
                  final List<Map<String, dynamic>> newMsgList = [];
                  for (final doc in newDocs) {
                    final m = doc.data() as Map<String, dynamic>;
                    m['id'] = doc.id;
                    newMsgList.add(m);
                  }

                  _cachedMessages = newMsgList;
                  ChatMessageCacheService.saveMessages(widget.roomId, newMsgList);

                  if (newMsgList.length != _lastDocCount) {
                    _lastDocCount = newMsgList.length;
                    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                  }
                }

                final messagesToDisplay = _cachedMessages;

                if (messagesToDisplay.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)));
                }

                if (messagesToDisplay.isEmpty) {
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
                  reverse: true,
                  padding: const EdgeInsets.all(20),
                  itemCount: messagesToDisplay.length,
                  itemBuilder: (context, index) {
                    final msg = messagesToDisplay[index];
                    final isMe = msg['senderId'] == currentUserId;
                    final time = _formatMessageTime(msg['timestamp'] as Timestamp?);
                    final ts = msg['timestamp'] as Timestamp?;
                    final msgDate = ts?.toDate();

                    // Show date separator above first chronological message of a day
                    bool showDateSep = false;
                    if (msgDate != null) {
                      if (index == messagesToDisplay.length - 1) {
                        showDateSep = true;
                      } else {
                        final olderMsg = messagesToDisplay[index + 1];
                        final olderTs = olderMsg['timestamp'] as Timestamp?;
                        final olderDate = olderTs?.toDate();
                        if (olderDate != null && !_isSameDay(msgDate, olderDate)) {
                          showDateSep = true;
                        }
                      }
                    }

                    final msgText = msg['text'] as String? ?? '';
                    final isMedia = _isMediaMessage(msgText);

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
                                  padding: isMedia
                                      ? const EdgeInsets.all(3.0)
                                      : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                  child: _buildMessageContent(msg, isMe),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedImagePath != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(_selectedImagePath!),
                                height: 70,
                                width: 70,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedImagePath = null;
                                  });
                                },
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Image selected. Tap send to share.',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF8B88A5),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Row(
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
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          decoration: InputDecoration(
                            hintText: 'Message... (Max 300)',
                            hintStyle: GoogleFonts.inter(color: const Color(0xFF8B88A5)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            border: InputBorder.none,
                            counterText: '',
                            suffixIcon: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _messageController,
                              builder: (context, value, child) {
                                if (value.text.isNotEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _isRetrievingLocation
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.0,
                                              color: Color(0xFF00E676),
                                            ),
                                          )
                                        : IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.location_on_outlined, color: Color(0xFF8B88A5), size: 20),
                                            onPressed: _sendLocation,
                                          ),
                                    // const SizedBox(width: 10),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.image_outlined, color: Color(0xFF8B88A5), size: 20),
                                      onPressed: _pickImage,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                );
                              },
                            ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationBubbleContent extends StatefulWidget {
  final String mapsUrl;
  final bool isMe;

  const _LocationBubbleContent({
    required this.mapsUrl,
    required this.isMe,
  });

  @override
  State<_LocationBubbleContent> createState() => _LocationBubbleContentState();
}

class _LocationBubbleContentState extends State<_LocationBubbleContent> {
  static final Map<String, String> _addressCache = {};
  String _address = 'Loading location...';

  @override
  void initState() {
    super.initState();
    _resolveAddress();
  }

  Future<void> _resolveAddress() async {
    if (_addressCache.containsKey(widget.mapsUrl)) {
      if (mounted) {
        setState(() {
          _address = _addressCache[widget.mapsUrl]!;
        });
      }
      return;
    }

    try {
      final uri = Uri.tryParse(widget.mapsUrl);
      if (uri != null) {
        final query = uri.queryParameters['query'];
        if (query != null) {
          final parts = query.split(',');
          if (parts.length == 2) {
            final lat = double.tryParse(parts[0]);
            final lng = double.tryParse(parts[1]);
            if (lat != null && lng != null) {
              final placemarks = await placemarkFromCoordinates(lat, lng);
              if (placemarks.isNotEmpty) {
                final place = placemarks.first;
                final partsList = <String>[];
                if (place.subLocality != null && place.subLocality!.isNotEmpty) {
                  partsList.add(place.subLocality!);
                }
                if (place.locality != null && place.locality!.isNotEmpty) {
                  partsList.add(place.locality!);
                }
                if (partsList.isEmpty) {
                  if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
                    partsList.add(place.administrativeArea!);
                  } else if (place.country != null && place.country!.isNotEmpty) {
                    partsList.add(place.country!);
                  }
                }
                
                final addressStr = partsList.isNotEmpty ? partsList.join(', ') : 'Location Shared';
                _addressCache[widget.mapsUrl] = addressStr;
                if (mounted) {
                  setState(() {
                    _address = addressStr;
                  });
                }
                return;
              }
            }
          }
        }
      }
    } catch (_) {
      // Fallback
    }

    if (mounted) {
      setState(() {
        _address = 'Location Shared';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;
    final primaryColor = isMe ? Colors.white : const Color(0xFF00E676);
    final secondaryColor = isMe ? Colors.white70 : const Color(0xFF8B88A5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_rounded,
              color: primaryColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          widget.mapsUrl,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: secondaryColor,
            fontSize: 11,
            decoration: TextDecoration.underline,
          ),
        ),
      ],
    );
  }
}

class _CachedChatImageBubble extends StatefulWidget {
  final String imageUrl;
  final String heroTag;
  final VoidCallback onTap;

  const _CachedChatImageBubble({
    required this.imageUrl,
    required this.heroTag,
    required this.onTap,
  });

  @override
  State<_CachedChatImageBubble> createState() => _CachedChatImageBubbleState();
}

class _CachedChatImageBubbleState extends State<_CachedChatImageBubble> {
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  Future<void> _resolveImage() async {
    final cached = ChatImageCacheService.getLocalPath(widget.imageUrl) ??
        await ChatImageCacheService.getLocalPathAsync(widget.imageUrl);

    if (cached != null) {
      if (mounted) setState(() => _localPath = cached);
    } else {
      final downloaded = await ChatImageCacheService.downloadAndCache(widget.imageUrl);
      if (downloaded != null && mounted) {
        setState(() => _localPath = downloaded);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width * 0.70;
    const maxH = 340.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: widget.onTap,
          child: Hero(
            tag: widget.heroTag,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxW,
                  maxHeight: maxH,
                ),
                child: _localPath != null && File(_localPath!).existsSync()
                    ? Image.file(
                        File(_localPath!),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => CachedNetworkImage(
                          imageUrl: widget.imageUrl,
                          fit: BoxFit.contain,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: widget.imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Container(
                          width: 200,
                          height: 150,
                          color: const Color(0xFF161426),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E676)),
                          ),
                        ),
                        errorWidget: (context, url, error) => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image, color: Color(0xFF8B88A5)),
                              SizedBox(width: 8),
                              Text('Image failed to load', style: TextStyle(color: Color(0xFF8B88A5), fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FullScreenImagePreview extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  final bool isLocal;

  const _FullScreenImagePreview({
    required this.imageUrl,
    required this.heroTag,
    this.isLocal = false,
  });

  @override
  Widget build(BuildContext context) {
    final cachedPath = isLocal ? imageUrl : ChatImageCacheService.getLocalPath(imageUrl);
    final displayLocal = cachedPath != null && File(cachedPath).existsSync();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Hero(
                tag: heroTag,
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: displayLocal
                      ? Image.file(
                          File(cachedPath),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                                SizedBox(height: 12),
                                Text('Unable to load image file', style: TextStyle(color: Colors.white70)),
                              ],
                            ),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(color: Color(0xFF00E676)),
                          ),
                          errorWidget: (context, url, error) => const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                                SizedBox(height: 12),
                                Text('Failed to load image', style: TextStyle(color: Colors.white70)),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(10),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(10),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

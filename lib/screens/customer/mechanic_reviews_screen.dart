import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mechtech/models/service_model.dart';

class MechanicReviewsScreen extends StatefulWidget {
  final String mechanicId;
  final String mechanicName;
  final String? mechanicPhotoUrl;
  final ServiceBooking? booking;

  const MechanicReviewsScreen({
    super.key,
    required this.mechanicId,
    required this.mechanicName,
    this.mechanicPhotoUrl,
    this.booking,
  });

  @override
  State<MechanicReviewsScreen> createState() => _MechanicReviewsScreenState();
}

class _MechanicReviewsScreenState extends State<MechanicReviewsScreen> {
  int _selectedFilter = 0; // 0: All, 5: 5★, 4: 4★, 3: 3★, 2: 2★, 1: 1★
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime? date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is String) {
      date = DateTime.tryParse(timestamp);
    } else if (timestamp is int) {
      date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    if (date == null) return '';

    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) return 'Just now';
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _showRatingBottomSheet({Map<String, dynamic>? existingReview}) {
    int currentRating = existingReview != null ? (existingReview['rating'] as num).toInt() : 0;
    final textController = TextEditingController(text: existingReview?['comment'] ?? '');
    bool isSubmitting = false;
    String? validationError;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161426),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF302B53),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    existingReview != null ? 'Edit Your Review' : 'Rate Your Mechanic',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.mechanicName,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF8B88A5),
                    ),
                  ),

                  // Inline Validation Error Message (no border, no bg)
                  if (validationError != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252), size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            validationError!,
                            style: GoogleFonts.inter(
                              color: const Color(0xFFFF5252),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // 5 Interactive Rating Stars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = index + 1;
                      final isFilled = starValue <= currentRating;
                      return IconButton(
                        iconSize: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: isFilled ? const Color(0xFFFFD700) : const Color(0xFF4A4470),
                        ),
                        onPressed: () {
                          setModalState(() {
                            currentRating = starValue;
                            validationError = null;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentRating == 5
                        ? 'Excellent Service! 🔥'
                        : currentRating == 4
                            ? 'Very Good 👍'
                            : currentRating == 3
                                ? 'Good Experience 🙂'
                                : currentRating == 2
                                    ? 'Below Average 😐'
                                    : currentRating == 1
                                        ? 'Needs Improvement 👎'
                                        : 'Tap stars above to rate',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: currentRating > 0 ? const Color(0xFFFFD700) : const Color(0xFF8B88A5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Feedback TextField with character limit
                  TextField(
                    controller: textController,
                    maxLength: 250,
                    maxLines: 3,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    onChanged: (_) {
                      if (validationError != null) {
                        setModalState(() => validationError = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Share your experience or feedback for the mechanic (Required)...',
                      hintStyle: GoogleFonts.inter(color: const Color(0xFF635E85), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF0D0B18),
                      counterStyle: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 11),
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (currentRating == 0) {
                                setModalState(() {
                                  validationError = 'Please select a star rating (1-5 stars) required.';
                                });
                                return;
                              }

                              final reviewText = textController.text.trim();
                              if (reviewText.isEmpty) {
                                setModalState(() {
                                  validationError = 'Please write a feedback before submitting.';
                                });
                                return;
                              }

                              setModalState(() {
                                validationError = null;
                                isSubmitting = true;
                              });

                              try {
                                final user = FirebaseAuth.instance.currentUser;
                                final customerName = user?.displayName ?? widget.booking?.customerName ?? 'Customer';
                                final customerPhoto = user?.photoURL ?? '';
                                final bookingId = widget.booking?.id ?? '';

                                final reviewData = {
                                  'mechanicId': widget.mechanicId,
                                  'mechanicName': widget.mechanicName,
                                  'customerId': _currentUserId ?? '',
                                  'customerName': customerName,
                                  'customerPhoto': customerPhoto,
                                  'bookingId': bookingId,
                                  'rating': currentRating,
                                  'comment': reviewText,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                };

                                // Check if user already has an existing review document in Firestore
                                final existingSnap = await FirebaseFirestore.instance
                                    .collection('reviews')
                                    .where('mechanicId', isEqualTo: widget.mechanicId)
                                    .where('customerId', isEqualTo: _currentUserId)
                                    .get();

                                if (existingSnap.docs.isNotEmpty) {
                                  final docId = existingSnap.docs.first.id;
                                  await FirebaseFirestore.instance
                                      .collection('reviews')
                                      .doc(docId)
                                      .update(reviewData);
                                } else {
                                  reviewData['createdAt'] = FieldValue.serverTimestamp();
                                  await FirebaseFirestore.instance.collection('reviews').add(reviewData);
                                }

                                // Also update booking doc if available
                                if (bookingId.isNotEmpty) {
                                  final updateBooking = {
                                    'hasReviewed': true,
                                    'userRating': currentRating,
                                    'userReview': reviewText,
                                    'reviewDate': FieldValue.serverTimestamp(),
                                  };
                                  await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update(updateBooking);
                                }

                                if (Navigator.of(modalContext).canPop()) {
                                  Navigator.of(modalContext).pop();
                                }

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Thank you! Your review has been saved.'),
                                      backgroundColor: Color(0xFF00E676),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                debugPrint("Error saving review: $e");
                                setModalState(() => isSubmitting = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                            )
                          : Text(
                              existingReview != null ? 'Update Review' : 'Submit Review',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteReview(String reviewId) async {
    try {
      await FirebaseFirestore.instance.collection('reviews').doc(reviewId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your review has been deleted.'),
            backgroundColor: Color(0xFFFF5252),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error deleting review: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161426),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF00B0FF).withValues(alpha: 0.15),
              backgroundImage: (widget.mechanicPhotoUrl != null && widget.mechanicPhotoUrl!.isNotEmpty)
                  ? NetworkImage(widget.mechanicPhotoUrl!)
                  : null,
              child: (widget.mechanicPhotoUrl == null || widget.mechanicPhotoUrl!.isEmpty)
                  ? const Icon(Icons.person_rounded, color: Color(0xFF00B0FF), size: 20)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.mechanicName,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Ratings & Reviews',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8B88A5),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reviews')
            .where('mechanicId', isEqualTo: widget.mechanicId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00B0FF)),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          List<Map<String, dynamic>> allReviews = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList();

          // Calculate average & distribution
          double avgRating = 0.0;
          int totalReviews = allReviews.length;
          Map<int, int> counts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

          if (totalReviews > 0) {
            double sum = 0;
            for (var r in allReviews) {
              final val = (r['rating'] as num?)?.toInt() ?? 5;
              sum += val;
              counts[val] = (counts[val] ?? 0) + 1;
            }
            avgRating = sum / totalReviews;
          }

          // Separate user's own review
          Map<String, dynamic>? myReview;
          if (_currentUserId != null) {
            final idx = allReviews.indexWhere((r) => r['customerId'] == _currentUserId);
            if (idx != -1) {
              myReview = allReviews[idx];
            }
          }

          // Filter reviews
          List<Map<String, dynamic>> filteredReviews = allReviews;
          if (_selectedFilter > 0) {
            filteredReviews = allReviews.where((r) => ((r['rating'] as num?)?.toInt() ?? 0) == _selectedFilter).toList();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Play Store Style Summary Header Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161426),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      // Left: Big Rating Number & Stars
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            Text(
                              avgRating.toStringAsFixed(1),
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 44,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                5,
                                (index) => Icon(
                                  (index < avgRating.floor())
                                      ? Icons.star_rounded
                                      : (index < avgRating)
                                          ? Icons.star_half_rounded
                                          : Icons.star_outline_rounded,
                                  color: const Color(0xFFFFD700),
                                  size: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$totalReviews Reviews',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF8B88A5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Divider Line
                      Container(
                        width: 1,
                        height: 90,
                        color: const Color(0xFF26223E),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                      ),

                      // Right: 5-Star Distribution Bars
                      Expanded(
                        flex: 6,
                        child: Column(
                          children: List.generate(5, (i) {
                            final starNum = 5 - i;
                            final count = counts[starNum] ?? 0;
                            final percent = totalReviews > 0 ? count / totalReviews : 0.0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.5),
                              child: Row(
                                children: [
                                  Text(
                                    '$starNum',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF8B88A5),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 11),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: percent,
                                        minHeight: 6,
                                        backgroundColor: const Color(0xFF26223E),
                                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2. Play Store Style "Your Review" Card
                Text(
                  'Your Rating & Review',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                if (myReview != null) ...[
                  // User has ALREADY reviewed card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161426),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFFFFD700).withValues(alpha: 0.2),
                              backgroundImage: (myReview['customerPhoto'] != null && myReview['customerPhoto'].isNotEmpty)
                                  ? NetworkImage(myReview['customerPhoto'])
                                  : null,
                              child: (myReview['customerPhoto'] == null || myReview['customerPhoto'].isEmpty)
                                  ? const Icon(Icons.person_rounded, color: Color(0xFFFFD700), size: 20)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Your Review',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'YOU',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFFFFD700),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Row(
                                        children: List.generate(
                                          5,
                                          (idx) => Icon(
                                            (idx < ((myReview!['rating'] as num?)?.toInt() ?? 5))
                                                ? Icons.star_rounded
                                                : Icons.star_outline_rounded,
                                            color: const Color(0xFFFFD700),
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatTimestamp(myReview['updatedAt'] ?? myReview['createdAt'] ?? myReview['reviewDate']),
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF8B88A5),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Edit & Delete Action Buttons
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, color: Color(0xFF00B0FF), size: 20),
                              onPressed: () => _showRatingBottomSheet(existingReview: myReview),
                              tooltip: 'Edit Review',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF5252), size: 20),
                              onPressed: () => _deleteReview(myReview!['id']),
                              tooltip: 'Delete Review',
                            ),
                          ],
                        ),
                        if (myReview['comment'] != null && myReview['comment'].isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            myReview['comment'],
                            style: GoogleFonts.inter(
                              color: const Color(0xFFD1CFCF),
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  // User HAS NOT reviewed yet card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161426),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rate this Mechanic',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: List.generate(
                                5,
                                (idx) => InkWell(
                                  onTap: () => _showRatingBottomSheet(),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 2),
                                    child: Icon(
                                      Icons.star_outline_rounded,
                                      color: Color(0xFF635E85),
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showRatingBottomSheet(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E676),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.rate_review_rounded, color: Colors.black, size: 16),
                          label: Text(
                            'Write Review',
                            style: GoogleFonts.outfit(
                              color: Colors.black,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // 3. Choice Chips Filter Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'All Reviews',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${filteredReviews.length} total',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8B88A5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [0, 5, 4, 3, 2, 1].map((star) {
                      final isSelected = _selectedFilter == star;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(star == 0 ? 'All' : '$star'),
                              if (star > 0) ...[
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.star_rounded,
                                  size: 13,
                                  color: isSelected ? Colors.black : const Color(0xFFFFD700),
                                ),
                              ],
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedFilter = star;
                            });
                          },
                          selectedColor: const Color(0xFFFFD700),
                          backgroundColor: const Color(0xFF161426),
                          labelStyle: GoogleFonts.inter(
                            color: isSelected ? Colors.black : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide.none,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 14),

                // 4. List of Reviews
                if (filteredReviews.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.rate_review_outlined, color: Color(0xFF635E85), size: 48),
                          const SizedBox(height: 10),
                          Text(
                            'No reviews found for this rating filter.',
                            style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredReviews.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final rev = filteredReviews[index];
                      final ratingVal = (rev['rating'] as num?)?.toInt() ?? 5;
                      final cName = rev['customerName'] as String? ?? 'Verified Customer';
                      final cPhoto = rev['customerPhoto'] as String?;
                      final comment = rev['comment'] as String? ?? '';
                      final dateStr = _formatTimestamp(rev['updatedAt'] ?? rev['createdAt'] ?? rev['reviewDate']);

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161426),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Customer Header
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF00B0FF).withValues(alpha: 0.15),
                                  backgroundImage: (cPhoto != null && cPhoto.isNotEmpty) ? NetworkImage(cPhoto) : null,
                                  child: (cPhoto == null || cPhoto.isEmpty)
                                      ? const Icon(Icons.person_rounded, color: Color(0xFF00B0FF), size: 18)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            cName,
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(Icons.verified_rounded, color: Color(0xFF00E676), size: 14),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Row(
                                            children: List.generate(
                                              5,
                                              (idx) => Icon(
                                                (idx < ratingVal) ? Icons.star_rounded : Icons.star_outline_rounded,
                                                color: const Color(0xFFFFD700),
                                                size: 13,
                                              ),
                                            ),
                                          ),
                                          if (dateStr.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              dateStr,
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFF8B88A5),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            if (comment.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                comment,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFD1CFCF),
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

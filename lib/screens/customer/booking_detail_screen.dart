import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/service_model.dart';
import '../../services/app_state.dart';
import '../../utils/invoice_helper.dart';
import 'mechanic_profile_details_screen.dart';

class BookingDetailScreen extends StatefulWidget {
  final ServiceBooking booking;

  const BookingDetailScreen({super.key, required this.booking});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  String? _mechanicName;
  String? _mechanicPhotoUrl;
  Map<String, dynamic>? _mechanicData;
  Timer? _swapTimer;
  int _swapIndex = 0;

  @override
  void initState() {
    super.initState();
    _mechanicName = widget.booking.mechanicName;
    _mechanicPhotoUrl = widget.booking.mechanicPhotoUrl;
    _fetchRealMechanicProfile();
    _startSwapTimer();
  }

  void _startSwapTimer() {
    _swapTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() {
          _swapIndex = (_swapIndex + 1) % 2;
        });
      }
    });
  }

  @override
  void dispose() {
    _swapTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchRealMechanicProfile() async {
    final mechId = widget.booking.mechanicId;
    if (mechId == null || mechId.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(mechId).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _mechanicData = data;
          _mechanicName = data['name'] ?? data['shopName'] ?? widget.booking.mechanicName;
          _mechanicPhotoUrl = data['photoUrl'] ?? data['photo'] ?? data['profilePhotoUrl'] ?? data['mechanicPhotoUrl'] ?? widget.booking.mechanicPhotoUrl;
        });
      }
    } catch (e) {
      debugPrint("Error fetching real mechanic profile: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    Color statusColor = const Color(0xFFFF9100);
    if (booking.status == 'In Progress') {
      statusColor = const Color(0xFF00B0FF);
    } else if (booking.status == 'Completed') {
      statusColor = const Color(0xFF00E676);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161426),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Booking Details',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              booking.status,
              style: GoogleFonts.inter(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Booking ID & Date Card
            _infoCard(
              children: [
                _buildDetailRow('Booking ID', booking.id),
                _divider(),
                _buildDetailRow(
                  'Booked On',
                  '${booking.bookingDate.day.toString().padLeft(2, '0')}/'
                  '${booking.bookingDate.month.toString().padLeft(2, '0')}/'
                  '${booking.bookingDate.year}',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Vehicle & Mechanic Card
            _sectionTitle('Vehicle & Service Info'),
            const SizedBox(height: 8),
            _infoCard(
              children: [
                // 1. Header: Vehicle Icon + Model + Type
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        booking.vehicleType == VehicleType.car
                            ? Icons.directions_car_rounded
                            : booking.vehicleType == VehicleType.bike
                                ? Icons.two_wheeler_rounded
                                : Icons.electric_car_rounded,
                        color: const Color(0xFF00E676),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.vehicleModel,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          booking.vehicleType.displayName,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF8B88A5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // 2. Mechanic Profile + Name Row (clickable with 'Tap to view detail')
                _divider(),
                InkWell(
                  onTap: () async {
                    if (booking.mechanicId != null && booking.mechanicId!.isNotEmpty) {
                      try {
                        final mechMap = Map<String, dynamic>.from(_mechanicData ?? {});
                        mechMap['mechanicId'] = booking.mechanicId;
                        mechMap['uid'] = booking.mechanicId;
                        mechMap['name'] = _mechanicName ?? booking.mechanicName ?? 'Mechanic';
                        mechMap['title'] = mechMap['shopName'] ?? mechMap['workshopName'] ?? mechMap['title'] ?? _mechanicName ?? 'Mechanic Specialist';
                        mechMap['photo'] = _mechanicPhotoUrl ?? mechMap['photoUrl'] ?? mechMap['mechanicPhotoUrl'] ?? mechMap['photo'] ?? booking.mechanicPhotoUrl ?? '';
                        if (context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MechanicProfileDetailsScreen(mechanic: mechMap),
                            ),
                          );
                        }
                      } catch (e) {
                        debugPrint("Error opening mechanic details: $e");
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mechanic details will be available once assigned.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF00B0FF).withValues(alpha: 0.15),
                          backgroundImage: (_mechanicPhotoUrl != null && _mechanicPhotoUrl!.isNotEmpty)
                              ? NetworkImage(_mechanicPhotoUrl!)
                              : null,
                          child: (_mechanicPhotoUrl == null || _mechanicPhotoUrl!.isEmpty)
                              ? const Icon(Icons.person_rounded, color: Color(0xFF00B0FF), size: 22)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _mechanicName ?? booking.mechanicName ?? 'Searching...',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              SizedBox(
                                height: 18,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 450),
                                  switchOutCurve: const Interval(0.0, 0.7, curve: Curves.easeInCubic),
                                  switchInCurve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
                                  transitionBuilder: (Widget child, Animation<double> animation) {
                                    final currentKey = _swapIndex == 0 ? 'tap_detail' : 'location_detail';
                                    final isIncoming = (child.key as ValueKey<String>?)?.value == currentKey;
                                    
                                    final inAnimation = Tween<Offset>(
                                      begin: const Offset(0.0, 1.0),
                                      end: Offset.zero,
                                    ).animate(animation);

                                    final outAnimation = Tween<Offset>(
                                      begin: const Offset(0.0, -1.0),
                                      end: Offset.zero,
                                    ).animate(animation);

                                    return SlideTransition(
                                      position: isIncoming ? inAnimation : outAnimation,
                                      child: FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: (_swapIndex == 0 || booking.bookingLocation == null || booking.bookingLocation!.isEmpty)
                                      ? Row(
                                          key: const ValueKey('tap_detail'),
                                          children: [
                                            Text(
                                              'Tap to view details',
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFF8B88A5),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            const Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              color: Color(0xFF8B88A5),
                                              size: 9,
                                            ),
                                          ],
                                        )
                                      : Row(
                                          key: const ValueKey('location_detail'),
                                          children: [
                                            const Icon(
                                              Icons.location_on_rounded,
                                              color: Color(0xFFFF9100),
                                              size: 12,
                                            ),
                                            const SizedBox(width: 3),
                                            Expanded(
                                              child: Text(
                                                booking.bookingLocation!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                  color: const Color(0xFF8B88A5),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Payment Card
            _sectionTitle('Payment Info'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161426),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (booking.paymentStatus == 'paid'
                          ? const Color(0xFF00E676)
                          : const Color(0xFFFF5252))
                      .withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment Status',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF8B88A5),
                          fontSize: 13,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: (booking.paymentStatus == 'paid'
                                  ? const Color(0xFF00E676)
                                  : const Color(0xFFFF5252))
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (booking.paymentStatus == 'paid'
                                    ? const Color(0xFF00E676)
                                    : const Color(0xFFFF5252))
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          (booking.paymentStatus ?? 'unpaid').toUpperCase(),
                          style: GoogleFonts.inter(
                            color: booking.paymentStatus == 'paid'
                                ? const Color(0xFF00E676)
                                : const Color(0xFFFF5252),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (booking.paymentId != null &&
                      booking.paymentId!.isNotEmpty) ...[
                    _divider(),
                    _buildDetailRow('Transaction ID', booking.paymentId!),
                  ],
                  if (booking.paymentId == 'COD') ...[
                    _divider(),
                    _buildDetailRow('Payment Method', 'Cash on Delivery'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Services Ordered
            _sectionTitle('Services Ordered'),
            const SizedBox(height: 8),
            _infoCard(
              children: [
                ...booking.selectedServices.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final s = entry.value;
                  return Column(
                    children: [
                      if (idx > 0) _divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.name,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    s.category,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF8B88A5),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₹${s.price.toStringAsFixed(0)}',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF00E676),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),

            // Payment Summary Breakdown Card
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161426),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF302B53),
                  width: 1.2,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Service Charges',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF8B88A5),
                        ),
                      ),
                      Text(
                        '₹${booking.serviceTotal.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Platform Charges',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF8B88A5),
                        ),
                      ),
                      Text(
                        '₹${booking.platformFee.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  if (booking.discount > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'S-Coin Discount',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFFFFD700),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '-₹${booking.discount.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: const Color(0xFFFFD700),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Divider(color: Color(0xFF302B53), height: 20, thickness: 1.2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${booking.totalAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          color: const Color(0xFF00E676),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Download Invoice Button
            ElevatedButton.icon(
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Generating Invoice PDF...'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                final file = await InvoiceHelper.generateInvoice(booking);
                if (context.mounted) {
                  if (file != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invoice saved to Downloads'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Color(0xFF00E676),
                        duration: Duration(seconds: 5),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to download invoice.'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.download_rounded),
              label: Text(
                'Download Invoice',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: const Color(0xFF0D0B18),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),

            // Cancel Booking Button
            if (booking.status != 'Completed') ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () =>
                    _confirmAndCancelBooking(context, booking),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF5252),
                  side: const BorderSide(color: Color(0xFFFF5252), width: 1.5),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'Cancel Booking',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Widget _infoCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161426),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF302B53), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF8B88A5),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _divider() => const Divider(
        color: Color(0xFF302B53),
        height: 20,
        thickness: 1,
      );

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
              color: const Color(0xFF8B88A5), fontSize: 13),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  void _confirmAndCancelBooking(BuildContext context, ServiceBooking booking) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161426),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF302B53), width: 1.5),
          ),
          title: Text(
            'Cancel Booking',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to cancel booking ${booking.id}? This action will permanently delete this booking.',
            style: GoogleFonts.inter(
                color: const Color(0xFF8B88A5), height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'No, Keep It',
                style: GoogleFonts.inter(
                    color: const Color(0xFF8B88A5),
                    fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                final appState = context.read<AppState>();
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (loadingContext) {
                    Future.microtask(() async {
                      final success =
                          await appState.cancelBooking(booking.id);
                      if (loadingContext.mounted) {
                        Navigator.of(loadingContext).pop();
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop(); // back to history list
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Booking ${booking.id} cancelled successfully.'
                                  : 'Failed to cancel booking. Please try again.',
                            ),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: success
                                ? const Color(0xFF00E676)
                                : Colors.redAccent,
                          ),
                        );
                      }
                    });
                    return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFFF5252)),
                    );
                  },
                );
              },
              child: Text(
                'Yes, Cancel',
                style: GoogleFonts.inter(
                    color: const Color(0xFFFF5252),
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}

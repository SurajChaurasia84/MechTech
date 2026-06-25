import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/service_model.dart';
import '../../services/app_state.dart';
import '../../utils/invoice_helper.dart';

class BookingDetailScreen extends StatelessWidget {
  final ServiceBooking booking;

  const BookingDetailScreen({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
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
                if (booking.mechanicName != null) ...[
                  _divider(),
                  _buildDetailRow(
                    'Assigned Mechanic',
                    booking.mechanicName ?? 'Searching...',
                  ),
                ],
                if (booking.bookingLocation != null) ...[
                  _divider(),
                  _buildDetailRow('Service Location', booking.bookingLocation!),
                ],
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

            // Total Amount
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00E676).withValues(alpha: 0.15),
                    const Color(0xFF00B0FF).withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF00E676).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
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
                      fontSize: 22,
                      color: const Color(0xFF00E676),
                      fontWeight: FontWeight.bold,
                    ),
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

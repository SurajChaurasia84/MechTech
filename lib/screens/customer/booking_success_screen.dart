import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/service_model.dart';

class BookingSuccessScreen extends StatelessWidget {
  final bool isSuccess;
  final ServiceBooking? booking;
  final String? errorMessage;

  const BookingSuccessScreen({
    super.key,
    required this.isSuccess,
    this.booking,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = isSuccess ? const Color(0xFF00E676) : Colors.redAccent;
    final iconData = isSuccess
        ? Icons.check_circle_outline_rounded
        : Icons.error_outline_rounded;
    final titleText = isSuccess ? 'Booking Confirmed!' : 'Payment Failed';
    final subtitleText = isSuccess
        ? 'Your booking request has been successfully created.'
        : 'We could not process your transaction or confirm your booking.';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B18),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Status Icon Container
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: themeColor.withOpacity(0.1),
                    border: Border.all(color: themeColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    iconData,
                    size: 80,
                    color: themeColor,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  titleText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitleText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF8B88A5),
                  ),
                ),
                const SizedBox(height: 32),

                // Details Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161426),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF302B53), width: 1.2),
                  ),
                  child: isSuccess && booking != null
                      ? Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Booking ID',
                                  style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 13),
                                ),
                                Text(
                                  booking!.id,
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                  Text(
                                    'Vehicle Model',
                                    style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 13),
                                  ),
                                  Text(
                                    booking!.vehicleModel,
                                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Services Booked',
                                    style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 13),
                                  ),
                                  Text(
                                    '${booking!.selectedServices.length} items',
                                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              if (booking!.paymentId != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Transaction ID',
                                      style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 13),
                                    ),
                                    Text(
                                      booking!.paymentId!,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Paid',
                                    style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 13),
                                  ),
                                  Text(
                                    '₹${booking!.totalAmount.toStringAsFixed(2)}',
                                    style: GoogleFonts.outfit(color: const Color(0xFF00B0FF), fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Failure Details',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Divider(color: Color(0xFF302B53), height: 20, thickness: 1.2),
                            Text(
                              errorMessage ?? 'Transaction was cancelled or declined by the provider.',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF8B88A5),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Status',
                                  style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 13),
                                ),
                                Text(
                                  'Payment Failed',
                                  style: GoogleFonts.outfit(
                                    color: Colors.redAccent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 48),

                // Back to Dashboard Button
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF302B53), width: 1.5),
                      color: const Color(0xFF161426),
                    ),
                    child: Center(
                      child: Text(
                        'Back to Dashboard',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

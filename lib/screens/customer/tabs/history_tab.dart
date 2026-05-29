import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/service_model.dart';
import '../../../services/app_state.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final bookings = appState.bookings;

    if (bookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 64,
                color: const Color(0xFF8B88A5).withValues(alpha: 0.5),
              ),
              const SizedBox(height: 20),
              Text(
                'No Bookings Yet',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Browse services and schedule your first booking today.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF8B88A5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 100.0),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final serviceCount = booking.selectedServices.length;

        // Custom status badge
        Color statusColor = const Color(0xFFFF9100); // Pending
        if (booking.status == 'In Progress') {
          statusColor = const Color(0xFF00B0FF);
        } else if (booking.status == 'Completed') {
          statusColor = const Color(0xFF00E676);
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: GestureDetector(
            onTap: () => _showBookingDetails(context, booking),
            child: Container(
              padding: const EdgeInsets.all(18.0),
              decoration: BoxDecoration(
                color: const Color(0xFF161426),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF302B53).withValues(alpha: 0.8),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        booking.id,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1),
                        ),
                        child: Text(
                          booking.status,
                          style: GoogleFonts.inter(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        booking.vehicleType == VehicleType.car
                            ? Icons.directions_car_outlined
                            : booking.vehicleType == VehicleType.bike
                                ? Icons.two_wheeler_outlined
                                : Icons.electric_car_outlined,
                        color: const Color(0xFF8B88A5),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        booking.vehicleModel,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Booked on ${booking.bookingDate.day}/${booking.bookingDate.month}/${booking.bookingDate.year}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8B88A5),
                      fontSize: 12,
                    ),
                  ),
                  const Divider(color: Color(0xFF302B53), height: 24, thickness: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$serviceCount ${serviceCount == 1 ? 'Service' : 'Services'}',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF8B88A5),
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '₹${booking.totalAmount.toStringAsFixed(0)}',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF00E676),
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBookingDetails(BuildContext context, ServiceBooking booking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161426),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        Color statusColor = const Color(0xFFFF9100);
        if (booking.status == 'In Progress') {
          statusColor = const Color(0xFF00B0FF);
        } else if (booking.status == 'Completed') {
          statusColor = const Color(0xFF00E676);
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Booking Details',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Status & ID Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0B18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF302B53), width: 1.2),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Booking ID', booking.id),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Status', style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 13)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            booking.status,
                            style: GoogleFonts.inter(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Booked Date',
                      '${booking.bookingDate.day}/${booking.bookingDate.month}/${booking.bookingDate.year}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Vehicle & Mechanic info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0B18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF302B53), width: 1.2),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Vehicle Type', booking.vehicleType.displayName),
                    const SizedBox(height: 12),
                    _buildDetailRow('Vehicle Model', booking.vehicleModel),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Assigned Mechanic',
                      booking.mechanicName ?? 'Searching for mechanic...',
                    ),
                    if (booking.bookingLocation != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow('Booking Address', booking.bookingLocation!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Services Ordered List
              Text(
                'Services Ordered:',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: booking.selectedServices.length,
                  itemBuilder: (context, index) {
                    final s = booking.selectedServices[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              s.name,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                            ),
                          ),
                          Text(
                            '₹${s.price.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(color: const Color(0xFF00E676), fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(color: Color(0xFF302B53), height: 32, thickness: 1.2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Amount', style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 14)),
                  Text(
                    '₹${booking.totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(fontSize: 18, color: const Color(0xFF00E676), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 13)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class BookingHistoryScreen extends StatelessWidget {
  const BookingHistoryScreen({super.key});

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
        title: Text(
          'Booking History',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
        ),
      ),
      body: const HistoryTab(),
    );
  }
}

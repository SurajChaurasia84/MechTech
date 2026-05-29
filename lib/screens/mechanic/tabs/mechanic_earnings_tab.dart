import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/service_model.dart';
import '../../../services/app_state.dart';

class MechanicEarningsTab extends StatelessWidget {
  const MechanicEarningsTab({super.key});

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    
    int hour = date.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final hourStr = hour.toString().padLeft(2, '0');
    final minuteStr = date.minute.toString().padLeft(2, '0');
    
    return '$day $month $year, $hourStr:$minuteStr $period';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final allJobs = appState.allGlobalBookings;

    // Filter jobs completed by this mechanic
    final completedJobs = allJobs.where((job) => 
      job.status == 'Completed' && job.mechanicId == appState.user?.uid
    ).toList();

    // Calculations
    double totalEarnings = 0;
    for (final job in completedJobs) {
      totalEarnings += job.totalAmount;
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 100.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Earnings & Stats',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // Stats Card Row
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Total Earnings',
                    value: '₹${totalEarnings.toStringAsFixed(0)}',
                    icon: Icons.account_balance_wallet_outlined,
                    color: const Color(0xFF00E676),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Jobs Completed',
                    value: '${completedJobs.length}',
                    icon: Icons.done_all_rounded,
                    color: const Color(0xFF00B0FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Jobs history list header
            Text(
              'Completed Job History (${completedJobs.length})',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            if (completedJobs.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF161426),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF302B53).withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.history_toggle_off_rounded,
                      size: 44,
                      color: const Color(0xFF8B88A5).withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No job history found. Complete jobs to see your history and earnings!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8B88A5),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...completedJobs.map((job) => _buildHistoryCard(job)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161426),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF302B53).withOpacity(0.8),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0xFF8B88A5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(ServiceBooking job) {
    final grandTotal = job.totalAmount;
    final dateStr = _formatDate(job.bookingDate);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFF161426),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF302B53).withOpacity(0.5),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0B18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                job.vehicleType == VehicleType.car
                    ? Icons.directions_car_outlined
                    : job.vehicleType == VehicleType.bike
                        ? Icons.two_wheeler_outlined
                        : Icons.electric_car_outlined,
                color: const Color(0xFF00E676),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.vehicleModel,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8B88A5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+ ₹${grandTotal.toStringAsFixed(0)}',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF00E676),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Paid',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF00E676),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

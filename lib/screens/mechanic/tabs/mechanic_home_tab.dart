import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/service_model.dart';
import '../../../services/app_state.dart';
import '../../chat/chat_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MechanicHomeTab extends StatefulWidget {
  const MechanicHomeTab({super.key});

  @override
  State<MechanicHomeTab> createState() => _MechanicHomeTabState();
}

class _MechanicHomeTabState extends State<MechanicHomeTab> {
  bool _isLoading = false;

  void _handleMessageCustomer(ServiceBooking job, AppState appState) async {
    final mechanicId = appState.user?.uid;
    final customerId = job.customerId;
    if (mechanicId == null || customerId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E676)),
      ),
    );

    try {
      final roomId = customerId.compareTo(mechanicId) < 0
          ? '${customerId}_$mechanicId'
          : '${mechanicId}_$customerId';

      final chatDocRef = FirebaseFirestore.instance.collection('chats').doc(roomId);
      final chatDoc = await chatDocRef.get();
      if (!chatDoc.exists) {
        await chatDocRef.set({
          'id': roomId,
          'customerId': customerId,
          'customerName': job.customerName,
          'customerPhotoUrl': '',
          'mechanicId': mechanicId,
          'mechanicName': job.mechanicName ?? appState.user?.displayName ?? 'Mechanic',
          'mechanicPhotoUrl': appState.user?.photoURL ?? '',
          'lastMessage': '',
          'lastSenderId': '',
          'timestamp': FieldValue.serverTimestamp(),
          'unreadByCustomer': false,
          'unreadByMechanic': false,
        });
      }

      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              roomId: roomId,
              recipientId: customerId,
              recipientName: job.customerName,
              recipientPhotoUrl: '',
              recipientRole: 'Client',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      debugPrint("Error launching chat from mechanic: $e");
    }
  }

  Future<void> _handleAcceptJob(AppState appState, String bookingId) async {
    setState(() => _isLoading = true);
    await appState.acceptJob(bookingId);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleCompleteJob(AppState appState, String bookingId) async {
    setState(() => _isLoading = true);
    await appState.completeJob(bookingId);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final allJobs = appState.allGlobalBookings;

    final pendingJobs = allJobs.where((job) => job.status == 'Pending').toList();
    final activeJobs = allJobs.where((job) => 
      job.status == 'In Progress' && job.mechanicId == appState.user?.uid
    ).toList();

    return SafeArea(
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 100.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161426),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF302B53).withOpacity(0.5),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFF0D0B18),
                        backgroundImage: appState.currentCustomerPhotoUrl != null
                            ? NetworkImage(appState.currentCustomerPhotoUrl!)
                            : null,
                        child: appState.currentCustomerPhotoUrl == null
                            ? const Icon(Icons.build, color: Color(0xFF00E676), size: 26)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mechanic Panel',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF00E676),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              appState.currentCustomerName ?? 'Professional Mechanic',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF00E676).withOpacity(0.5)),
                        ),
                        child: Text(
                          'Online',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF00E676),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Active Jobs Section
                Text(
                  'My Active Jobs (${activeJobs.length})',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                if (activeJobs.isEmpty)
                  _buildEmptyState('No active jobs. Claim a request below to get started!')
                else
                  ...activeJobs.map((job) => _buildJobCard(job, appState, isActive: true)),

                const SizedBox(height: 36),

                // Pending requests section
                Text(
                  'Incoming Booking Requests (${pendingJobs.length})',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                if (pendingJobs.isEmpty)
                  _buildEmptyState('No pending service requests available.')
                else
                  ...pendingJobs.map((job) => _buildJobCard(job, appState, isActive: false)),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00E676)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161426),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF302B53).withOpacity(0.3)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: const Color(0xFF8B88A5),
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildJobCard(ServiceBooking job, AppState appState, {required bool isActive}) {
    final grandTotal = job.totalAmount * 1.18; // Subtotal + 18% Tax

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFF161426),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF00B0FF) : const Color(0xFF302B53),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row: Job ID + Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  job.id,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '₹${grandTotal.toStringAsFixed(0)}',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF00E676),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(color: Color(0xFF302B53), height: 20),

            // Vehicle info
            Row(
              children: [
                Icon(
                  job.vehicleType == VehicleType.car
                      ? Icons.directions_car_outlined
                      : job.vehicleType == VehicleType.bike
                          ? Icons.two_wheeler_outlined
                          : Icons.electric_car_outlined,
                  color: const Color(0xFF8B88A5),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  job.vehicleModel,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${job.vehicleType.displayName})',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8B88A5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Customer details
            Row(
              children: [
                const Icon(Icons.person_outline, color: Color(0xFF8B88A5), size: 16),
                const SizedBox(width: 8),
                Text(
                  job.customerName,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                ),
                if (isActive && job.customerPhone != null) ...[
                  const Spacer(),
                  const Icon(Icons.phone_outlined, color: Color(0xFF00B0FF), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    job.customerPhone!,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF00B0FF),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Services list summary
            Text(
              'Services requested:',
              style: GoogleFonts.inter(
                color: const Color(0xFF8B88A5),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: job.selectedServices.map((service) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0B18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    service.name,
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            if (isActive)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF302B53)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _handleMessageCustomer(job, appState),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Message',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _handleCompleteJob(appState, job.id),
                          child: Center(
                            child: Text(
                              'Complete Job',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF0D0B18),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00B0FF), Color(0xFF9C27B0)],
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _handleAcceptJob(appState, job.id),
                    child: Center(
                      child: Text(
                        'Accept Job Request',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

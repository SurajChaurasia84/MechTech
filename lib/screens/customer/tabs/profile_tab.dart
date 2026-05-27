import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../services/app_state.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final customerName = appState.currentCustomerName ?? 'Valued Customer';
    final customerEmail = appState.currentCustomerEmail ?? 'No email associated';
    final bookingsCount = appState.bookings.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile Detail Card (Background removed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundColor: const Color(0xFF161426),
                  backgroundImage: appState.currentCustomerPhotoUrl != null
                      ? NetworkImage(appState.currentCustomerPhotoUrl!)
                      : null,
                  child: appState.currentCustomerPhotoUrl == null
                      ? const Icon(Icons.person, color: Color(0xFF00E676), size: 46)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  customerName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  customerEmail,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF8B88A5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Statistics Row
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  title: 'Bookings',
                  value: bookingsCount.toString(),
                  icon: Icons.calendar_today_rounded,
                  color: const Color(0xFF00E676),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  title: 'Completed',
                  value: appState.bookings.where((b) => b.status == 'Completed').length.toString(),
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF00B0FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Actions List
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161426),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF302B53).withOpacity(0.5),
                width: 1.2,
              ),
            ),
            child: Column(
              children: [
                _buildProfileListItem(
                  icon: Icons.settings_outlined,
                  title: 'App Settings',
                  onTap: () {},
                ),
                const Divider(color: Color(0xFF302B53), height: 1, thickness: 1),
                _buildProfileListItem(
                  icon: Icons.help_outline_rounded,
                  title: 'Support & FAQs',
                  onTap: () {},
                ),
                const Divider(color: Color(0xFF302B53), height: 1, thickness: 1),
                _buildProfileListItem(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  onTap: () {},
                ),
                const Divider(color: Color(0xFF302B53), height: 1, thickness: 1),
                _buildProfileListItem(
                  icon: Icons.logout_rounded,
                  title: 'Log Out',
                  titleColor: Colors.redAccent,
                  iconColor: Colors.redAccent,
                  onTap: () => appState.logout(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF161426),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF302B53).withOpacity(0.5),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF8B88A5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileListItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color titleColor = Colors.white,
    Color iconColor = const Color(0xFF8B88A5),
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: GoogleFonts.inter(color: titleColor, fontSize: 14, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF535072)),
      onTap: onTap,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/app_state.dart';
import '../edit_profile_screen.dart';
import '../add_address_screen.dart';
import 'history_tab.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final customerName = appState.currentCustomerName ?? 'Valued Customer';
    final customerEmail = appState.currentCustomerEmail ?? 'No email associated';

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
                  icon: Icons.person_2_outlined,
                  title: 'Edit Profile',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    );
                  },
                ),
                const Divider(color: Color(0xFF302B53), height: 1, thickness: 1),
                _buildProfileListItem(
                  icon: Icons.map_outlined,
                  title: 'Add Address',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddAddressScreen(),
                      ),
                    );
                  },
                ),
                const Divider(color: Color(0xFF302B53), height: 1, thickness: 1),
                _buildProfileListItem(
                  icon: Icons.history_rounded,
                  title: 'Booking History',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BookingHistoryScreen(),
                      ),
                    );
                  },
                ),
                const Divider(color: Color(0xFF302B53), height: 1, thickness: 1),
                _buildProfileListItem(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & Support',
                  onTap: () async {
                    final Uri emailLaunchUri = Uri(
                      scheme: 'mailto',
                      path: '1shreejee1@gmail.com',
                      query: Uri.encodeFull('subject=MechTech Support Request'),
                    );
                    if (await canLaunchUrl(emailLaunchUri)) {
                      await launchUrl(emailLaunchUri);
                    }
                  },
                ),
                const Divider(color: Color(0xFF302B53), height: 1, thickness: 1),
                _buildProfileListItem(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  onTap: () async {
                    final Uri url = Uri.parse('https://example.com/privacy-policy');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                const Divider(color: Color(0xFF302B53), height: 1, thickness: 1),
                _buildProfileListItem(
                  icon: Icons.share_outlined,
                  title: 'Share App',
                  onTap: () {
                    Share.share(
                      'Check out MechTech - the premium mechanic service app! Download now: https://play.google.com/store/apps/details?id=com.mechtech.mechanic.apps',
                    );
                  },
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

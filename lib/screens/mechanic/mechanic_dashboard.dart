import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tabs/mechanic_home_tab.dart';
import 'tabs/mechanic_earnings_tab.dart';
import 'tabs/mechanic_profile_tab.dart';
import 'tabs/mechanic_messages_tab.dart';
import 'manage_service_screen.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';

class MechanicDashboard extends StatefulWidget {
  const MechanicDashboard({super.key});

  @override
  State<MechanicDashboard> createState() => _MechanicDashboardState();
}

class _MechanicDashboardState extends State<MechanicDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0B18),
        appBar: AppBar(
          backgroundColor: const Color(0xFF161426),
          elevation: 0,
          title: Row(
            children: [
              if (_currentIndex == 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/icon.png',
                    height: 28,
                    width: 28,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                _getAppBarTitle(),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          automaticallyImplyLeading: false, // Don't show back button for top level dashboard
          actions: [
            if (_currentIndex == 3)
              IconButton(
                icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
                tooltip: 'Switch Profile Role',
                onPressed: () => _showRoleSwitchDialog(context),
              ),
          ],
        ),
        body: _buildBody(),
        extendBody: true,
        bottomNavigationBar: BottomAppBar(
          color: const Color(0xFF161426),
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          clipBehavior: Clip.antiAlias,
          padding: EdgeInsets.zero,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: const Color(0xFF302B53).withOpacity(0.4),
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Jobs button
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _currentIndex = 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _currentIndex == 0 ? Icons.build : Icons.build_outlined,
                          color: _currentIndex == 0 ? const Color(0xFF00E676) : const Color(0xFF8B88A5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Jobs',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: _currentIndex == 0 ? FontWeight.bold : FontWeight.normal,
                            color: _currentIndex == 0 ? const Color(0xFF00E676) : const Color(0xFF8B88A5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Earnings button
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _currentIndex = 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _currentIndex == 1 ? Icons.account_balance_wallet : Icons.account_balance_wallet_outlined,
                          color: _currentIndex == 1 ? const Color(0xFF00E676) : const Color(0xFF8B88A5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Earnings',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: _currentIndex == 1 ? FontWeight.bold : FontWeight.normal,
                            color: _currentIndex == 1 ? const Color(0xFF00E676) : const Color(0xFF8B88A5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Empty space for FloatingActionButton
                const SizedBox(width: 48),
                 // Messages button
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _currentIndex = 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('chats')
                              .where('mechanicId', isEqualTo: appState.user?.uid)
                              .where('unreadByMechanic', isEqualTo: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  _currentIndex == 2 ? Icons.forum : Icons.forum_outlined,
                                  color: _currentIndex == 2 ? const Color(0xFF00E676) : const Color(0xFF8B88A5),
                                ),
                                if (hasUnread)
                                  Positioned(
                                    top: -2,
                                    right: -2,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Messages',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: _currentIndex == 2 ? FontWeight.bold : FontWeight.normal,
                            color: _currentIndex == 2 ? const Color(0xFF00E676) : const Color(0xFF8B88A5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Profile button
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _currentIndex = 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _currentIndex == 3 ? Icons.person : Icons.person_outline,
                          color: _currentIndex == 3 ? const Color(0xFF00E676) : const Color(0xFF8B88A5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Profile',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: _currentIndex == 3 ? FontWeight.bold : FontWeight.normal,
                            color: _currentIndex == 3 ? const Color(0xFF00E676) : const Color(0xFF8B88A5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: SizedBox(
          height: 60,
          width: 60,
          child: FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ManageServiceScreen(),
                ),
              );
            },
            shape: const CircleBorder(),
            backgroundColor: const Color(0xFF08693F), // Rich green brand color
            elevation: 8.0,
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'MechTech Jobs';
      case 1:
        return 'My Earnings';
      case 2:
        return 'Messages';
      case 3:
        return 'Mechanic Profile';
      default:
        return 'MechTech';
    }
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const MechanicHomeTab();
      case 1:
        return const MechanicEarningsTab();
      case 2:
        return const MechanicMessagesTab();
      case 3:
        return const MechanicProfileTab();
      default:
        return const SizedBox.shrink();
    }
  }

  void _showRoleSwitchDialog(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    final currentRole = appState.userRole ?? 'customer';
    String tempSelectedRole = currentRole;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161426),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF302B53), width: 1.5),
              ),
              title: Text(
                'Switch Profile Role',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Select which panel role you want to switch to:',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8B88A5),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Customer Choice Card
                  InkWell(
                    onTap: () {
                      setDialogState(() {
                        tempSelectedRole = 'customer';
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: tempSelectedRole == 'customer'
                            ? const Color(0xFF00E676).withOpacity(0.08)
                            : const Color(0xFF0D0B18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: tempSelectedRole == 'customer'
                              ? const Color(0xFF00E676)
                              : const Color(0xFF302B53),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_rounded,
                            color: tempSelectedRole == 'customer'
                                ? const Color(0xFF00E676)
                                : const Color(0xFF8B88A5),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Customer Panel',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'Book services and find mechanics.',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF8B88A5),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (tempSelectedRole == 'customer')
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Mechanic Choice Card
                  InkWell(
                    onTap: () {
                      setDialogState(() {
                        tempSelectedRole = 'mechanic';
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: tempSelectedRole == 'mechanic'
                            ? const Color(0xFF00B0FF).withOpacity(0.08)
                            : const Color(0xFF0D0B18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: tempSelectedRole == 'mechanic'
                              ? const Color(0xFF00B0FF)
                              : const Color(0xFF302B53),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.build_rounded,
                            color: tempSelectedRole == 'mechanic'
                                ? const Color(0xFF00B0FF)
                                : const Color(0xFF8B88A5),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mechanic Panel',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'Manage bookings and view earnings.',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF8B88A5),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (tempSelectedRole == 'mechanic')
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF00B0FF)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8B88A5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    if (tempSelectedRole != currentRole) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              ),
                              SizedBox(width: 12),
                              Text('Switching roles...'),
                            ],
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );

                      await appState.switchUserRole(tempSelectedRole);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      }
                    }
                  },
                  child: Text(
                    'Switch',
                    style: GoogleFonts.inter(
                      color: tempSelectedRole == 'customer'
                          ? const Color(0xFF00E676)
                          : const Color(0xFF00B0FF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

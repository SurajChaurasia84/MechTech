import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/service_model.dart';
import '../../services/app_state.dart';
import 'tabs/home_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/messages_tab.dart';


class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final selectedType = appState.selectedVehicleType;

    // Accent color based on vehicle selection
    Color accentColor = const Color(0xFF00E676);
    if (selectedType == VehicleType.car) {
      accentColor = const Color(0xFF9C27B0);
    } else if (selectedType == VehicleType.ev) {
      accentColor = const Color(0xFF00B0FF);
    }

    return PopScope(
      canPop: _currentIndex == 0, // allow close only from Home tab
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
                const Icon(
                  Icons.build_rounded,
                  color: Color(0xFF00E676),
                  size: 24,
                ),
                const SizedBox(width: 10),
              ],
              Text(
                _getAppBarTitle(),
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
              ),
            ],
          ),
          automaticallyImplyLeading: false,
          actions: [
            if (_currentIndex == 3)
              IconButton(
                icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
                tooltip: 'Switch Profile Role',
                onPressed: () => _showRoleSwitchDialog(context),
              ),
          ],
        ),
        body: Stack(
          children: [
            // Background soft glows for aesthetic depth
            Positioned(
              top: 40,
              left: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withOpacity(0.08),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.08),
                      blurRadius: 60,
                      spreadRadius: 30,
                    ),
                  ],
                ),
              ),
            ),
            
            // Switch between Tabs based on current index
            _buildBody(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: const Color(0xFF302B53).withOpacity(0.6),
                width: 1.5,
              ),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            backgroundColor: const Color(0xFF161426),
            selectedItemColor: accentColor,
            unselectedItemColor: const Color(0xFF8B88A5),
            selectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
            type: BottomNavigationBarType.fixed,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.assignment_turned_in_outlined),
                activeIcon: Icon(Icons.assignment_turned_in_rounded),
                label: 'Bookings',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.forum_outlined),
                activeIcon: Icon(Icons.forum_rounded),
                label: 'Messages',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ), // Scaffold
    ); // PopScope
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'MechTech';
      case 1:
        return 'Booking History';
      case 2:
        return 'Messages';
      case 3:
        return 'My Profile';
      default:
        return 'MechTech';
    }
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const HomeTab();
      case 1:
        return const HistoryTab();
      case 2:
        return const MessagesTab();
      case 3:
        return const ProfileTab();
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

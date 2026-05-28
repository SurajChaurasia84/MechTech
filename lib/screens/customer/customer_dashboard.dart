import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/service_model.dart';
import '../../services/app_state.dart';
import 'tabs/home_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/messages_tab.dart';
import 'find_mechanic_screen.dart';

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
        extendBody: true, // Let body extend behind BottomAppBar for notch look
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
                // Home button
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _currentIndex = 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _currentIndex == 0 ? Icons.home_rounded : Icons.home_outlined,
                          color: _currentIndex == 0 ? const Color(0xFF00E676) : const Color(0xFF8B88A5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Home',
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
                // Bookings button
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _currentIndex = 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _currentIndex == 1 ? Icons.assignment_turned_in_rounded : Icons.assignment_turned_in_outlined,
                          color: _currentIndex == 1 ? const Color(0xFF00E676) : const Color(0xFF8B88A5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bookings',
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
                        Icon(
                          _currentIndex == 2 ? Icons.forum_rounded : Icons.forum_outlined,
                          color: _currentIndex == 2 ? const Color(0xFF00E676) : const Color(0xFF8B88A5),
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
                          _currentIndex == 3 ? Icons.person_rounded : Icons.person_outline_rounded,
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
        floatingActionButton: Container(
          height: 60,
          width: 60,
          child: FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const FindMechanicScreen(),
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
}

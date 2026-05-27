import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/service_model.dart';
import '../../services/app_state.dart';
import 'tabs/home_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/profile_tab.dart';

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
              Image.asset(
                'assets/icon.png',
                height: 28,
                width: 28,
              ),
              const SizedBox(width: 10),
            ],
            Text(
              _getAppBarTitle(),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
            ),
          ],
        ),
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
          selectedItemColor: const Color(0xFF00E676),
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
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
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
        return const ProfileTab();
      default:
        return const SizedBox.shrink();
    }
  }
}

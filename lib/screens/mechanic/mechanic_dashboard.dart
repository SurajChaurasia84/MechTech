import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tabs/mechanic_home_tab.dart';
import 'tabs/mechanic_earnings_tab.dart';
import 'tabs/mechanic_profile_tab.dart';
import 'tabs/mechanic_messages_tab.dart';
import 'manage_service_screen.dart';

class MechanicDashboard extends StatefulWidget {
  const MechanicDashboard({super.key});

  @override
  State<MechanicDashboard> createState() => _MechanicDashboardState();
}

class _MechanicDashboardState extends State<MechanicDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
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
          title: Text(
            _getAppBarTitle(),
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
          automaticallyImplyLeading: false, // Don't show back button for top level dashboard
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
                        Icon(
                          _currentIndex == 2 ? Icons.forum : Icons.forum_outlined,
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
}

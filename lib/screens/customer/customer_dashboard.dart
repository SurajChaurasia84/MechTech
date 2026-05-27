import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/service_model.dart';
import '../../services/app_state.dart';
import 'service_selection_screen.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _currentIndex = 0;
  String? _selectedModel;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final selectedType = appState.selectedVehicleType;
    final models = selectedType != null ? appState.getModelsForType(selectedType) : <VehicleModel>[];

    // Accent color based on vehicle selection
    Color accentColor = const Color(0xFF00E676);
    if (selectedType == VehicleType.car) {
      accentColor = const Color(0xFF9C27B0);
    } else if (selectedType == VehicleType.ev) {
      accentColor = const Color(0xFF00B0FF);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161426),
        elevation: 0,
        title: Text(
          _getAppBarTitle(),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
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
          _buildBody(appState, accentColor, models),
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
    );
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

  Widget _buildBody(AppState appState, Color accentColor, List<VehicleModel> models) {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab(appState, accentColor, models);
      case 1:
        return _buildHistoryTab(appState);
      case 2:
        return _buildProfileTab(appState);
      default:
        return const SizedBox.shrink();
    }
  }

  // --- HOME TAB ---
  Widget _buildHomeTab(AppState appState, Color accentColor, List<VehicleModel> models) {
    final customerName = appState.currentCustomerName ?? 'Valued Customer';
    final selectedType = appState.selectedVehicleType;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
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
                        ? const Icon(Icons.person, color: Color(0xFF00E676), size: 26)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF8B88A5),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          customerName,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Select Vehicle Header
            Text(
              'Select Vehicle Category',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Car / Bike / EV Row
            Row(
              children: [
                Expanded(
                  child: _buildCategoryCard(
                    title: 'Car',
                    icon: Icons.directions_car_outlined,
                    type: VehicleType.car,
                    isSelected: selectedType == VehicleType.car,
                    activeColor: const Color(0xFF9C27B0),
                    appState: appState,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCategoryCard(
                    title: 'Bike',
                    icon: Icons.two_wheeler_outlined,
                    type: VehicleType.bike,
                    isSelected: selectedType == VehicleType.bike,
                    activeColor: const Color(0xFF00E676),
                    appState: appState,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCategoryCard(
                    title: 'EV',
                    icon: Icons.electric_car_outlined,
                    type: VehicleType.ev,
                    isSelected: selectedType == VehicleType.ev,
                    activeColor: const Color(0xFF00B0FF),
                    appState: appState,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Dropdown & Proceed button
            if (selectedType != null) ...[
              Text(
                'Choose Your ${selectedType.displayName} Model',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF161426),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF302B53), width: 1.5),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    dropdownColor: const Color(0xFF161426),
                    value: _selectedModel,
                    hint: Text(
                      'Select Model Number/Name',
                      style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 15),
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF00E676)),
                    isExpanded: true,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                    items: models.map((model) {
                      return DropdownMenuItem<String>(
                        value: model.name,
                        child: Text(model.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedModel = val;
                      });
                      if (val != null) {
                        appState.selectVehicleModel(val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 48),

              AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _selectedModel != null ? 1.0 : 0.4,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: _selectedModel != null
                          ? [const Color(0xFF00E676), const Color(0xFF00B0FF)]
                          : [const Color(0xFF302B53), const Color(0xFF302B53)],
                    ),
                    boxShadow: _selectedModel != null
                        ? [
                            BoxShadow(
                              color: const Color(0xFF00E676).withOpacity(0.25),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            )
                          ]
                        : [],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _selectedModel != null
                          ? () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ServiceSelectionScreen(),
                                ),
                              );
                            }
                          : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Explore Services Chart',
                            style: GoogleFonts.outfit(
                              color: _selectedModel != null ? const Color(0xFF0D0B18) : const Color(0xFF8B88A5),
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: _selectedModel != null ? const Color(0xFF0D0B18) : const Color(0xFF8B88A5),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Empty State message
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
                      Icons.directions_car_outlined,
                      size: 48,
                      color: const Color(0xFF8B88A5).withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Please select a vehicle category above to browse available services.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8B88A5),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required IconData icon,
    required VehicleType type,
    required bool isSelected,
    required Color activeColor,
    required AppState appState,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedModel = null;
        });
        appState.selectVehicleType(type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.15) : const Color(0xFF161426),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFF302B53),
            width: isSelected ? 2.0 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 36,
              color: isSelected ? activeColor : const Color(0xFF8B88A5),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF8B88A5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HISTORY TAB ---
  Widget _buildHistoryTab(AppState appState) {
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
                color: const Color(0xFF8B88A5).withOpacity(0.5),
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
      padding: const EdgeInsets.all(24.0),
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
          child: Container(
            padding: const EdgeInsets.all(18.0),
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
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withOpacity(0.5), width: 1),
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
                      '₹${(booking.totalAmount * 1.18).toStringAsFixed(0)}', // Total with tax
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
        );
      },
    );
  }

  // --- PROFILE TAB ---
  Widget _buildProfileTab(AppState appState) {
    final customerName = appState.currentCustomerName ?? 'Valued Customer';
    final customerEmail = appState.currentCustomerEmail ?? 'No email associated';
    final bookingsCount = appState.bookings.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile Detail Card
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: const Color(0xFF161426),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF302B53).withOpacity(0.8),
                width: 1.2,
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundColor: const Color(0xFF0D0B18),
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
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  customerEmail,
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
              ],
            ),
          ),
          const SizedBox(height: 48),

          // Log Out Button
          Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1.5),
              color: Colors.redAccent.withOpacity(0.06),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => appState.logout(),
                child: Center(
                  child: Text(
                    'Log Out',
                    style: GoogleFonts.outfit(
                      color: Colors.redAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
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
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF8B88A5)),
      title: Text(
        title,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF535072)),
      onTap: onTap,
    );
  }
}

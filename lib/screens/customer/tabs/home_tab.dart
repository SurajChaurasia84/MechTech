import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/service_model.dart';
import '../../../services/app_state.dart';
import '../service_selection_screen.dart';
import 'history_tab.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
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

    final customerName = appState.currentCustomerName ?? 'Valued Customer';

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
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF161426),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedModel != null ? accentColor : const Color(0xFF302B53),
                    width: 1.5,
                  ),
                  boxShadow: _selectedModel != null
                      ? [
                          BoxShadow(
                            color: accentColor.withOpacity(0.12),
                            blurRadius: 10,
                            spreadRadius: 1,
                          )
                        ]
                      : [],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    dropdownColor: const Color(0xFF161426),
                    borderRadius: BorderRadius.circular(16),
                    value: _selectedModel,
                    hint: Row(
                      children: [
                        Icon(
                          selectedType == VehicleType.car
                              ? Icons.directions_car_outlined
                              : selectedType == VehicleType.bike
                                  ? Icons.two_wheeler_outlined
                                  : Icons.electric_car_outlined,
                          color: const Color(0xFF8B88A5),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Select Model Number/Name',
                          style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 15),
                        ),
                      ],
                    ),
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: accentColor),
                    isExpanded: true,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                    items: models.map((model) {
                      return DropdownMenuItem<String>(
                        value: model.name,
                        child: Row(
                          children: [
                            Icon(
                              selectedType == VehicleType.car
                                  ? Icons.directions_car_rounded
                                  : selectedType == VehicleType.bike
                                      ? Icons.two_wheeler_rounded
                                      : Icons.electric_car_rounded,
                              color: _selectedModel == model.name ? accentColor : const Color(0xFF8B88A5),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              model.name,
                              style: GoogleFonts.inter(
                                fontWeight: _selectedModel == model.name ? FontWeight.bold : FontWeight.normal,
                                color: _selectedModel == model.name ? Colors.white : const Color(0xFFD0CFDD),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    selectedItemBuilder: (BuildContext context) {
                      return models.map((model) {
                        return Row(
                          children: [
                            Icon(
                              selectedType == VehicleType.car
                                  ? Icons.directions_car_rounded
                                  : selectedType == VehicleType.bike
                                      ? Icons.two_wheeler_rounded
                                      : Icons.electric_car_rounded,
                              color: accentColor,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              model.name,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
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
            const SizedBox(height: 40),

            // Recent Bookings Header with "View All" Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Bookings',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Pushes the separate Booking History Screen onto the navigation stack
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BookingHistoryScreen(),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        'View All',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF00E676),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Color(0xFF00E676),
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Preview card of the most recent bookings (max 3)
            if (appState.bookings.isNotEmpty) ...[
              ...appState.bookings.reversed.take(3).map((booking) {
                Color statusColor = const Color(0xFFFF9100);
                if (booking.status == 'In Progress') {
                  statusColor = const Color(0xFF00B0FF);
                } else if (booking.status == 'Completed') {
                  statusColor = const Color(0xFF00E676);
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161426),
                      borderRadius: BorderRadius.circular(16),
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
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: statusColor.withOpacity(0.5), width: 1),
                              ),
                              child: Text(
                                booking.status,
                                style: GoogleFonts.inter(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              booking.vehicleType == VehicleType.car
                                  ? Icons.directions_car_outlined
                                  : booking.vehicleType == VehicleType.bike
                                      ? Icons.two_wheeler_outlined
                                      : Icons.electric_car_outlined,
                              color: const Color(0xFF8B88A5),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              booking.vehicleModel,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '₹${(booking.totalAmount * 1.18).toStringAsFixed(0)}',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF00E676),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No booking history',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8B88A5),
                      fontSize: 13,
                    ),
                  ),
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
}

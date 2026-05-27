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
  String? _selectedModel;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final customerName = appState.currentCustomerName ?? 'Valued Customer';
    final selectedType = appState.selectedVehicleType;
    
    // Fetch models if type is selected
    final models = selectedType != null ? appState.getModelsForType(selectedType) : <VehicleModel>[];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161426),
        elevation: 0,
        title: Text(
          'MechTech Services',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: () {
              context.read<AppState>().logout();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background soft glows
          Positioned(
            top: 40,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E676).withOpacity(0.08),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E676).withOpacity(0.08),
                    blurRadius: 60,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Greeting
                  Text(
                    'Welcome back,',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF8B88A5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    customerName,
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Header for selection
                  Text(
                    'Select Vehicle Category',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3 Cards: Car, Bike, EV
                  Row(
                    children: [
                      Expanded(
                        child: _buildCategoryCard(
                          context,
                          title: 'Car',
                          icon: Icons.directions_car_outlined,
                          type: VehicleType.car,
                          isSelected: selectedType == VehicleType.car,
                          activeColor: const Color(0xFF9C27B0), // Purple theme
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCategoryCard(
                          context,
                          title: 'Bike',
                          icon: Icons.two_wheeler_outlined,
                          type: VehicleType.bike,
                          isSelected: selectedType == VehicleType.bike,
                          activeColor: const Color(0xFF00E676), // Green theme
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCategoryCard(
                          context,
                          title: 'EV',
                          icon: Icons.electric_car_outlined,
                          type: VehicleType.ev,
                          isSelected: selectedType == VehicleType.ev,
                          activeColor: const Color(0xFF00B0FF), // Blue theme
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Model Selection section
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
                              context.read<AppState>().selectVehicleModel(val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Proceed Button
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
                    // Empty State helper
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
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VehicleType type,
    required bool isSelected,
    required Color activeColor,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedModel = null;
        });
        context.read<AppState>().selectVehicleType(type);
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

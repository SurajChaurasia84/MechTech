import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/service_model.dart';
import '../../services/app_state.dart';
import 'select_mechanic_screen.dart';

class ServiceSelectionScreen extends StatelessWidget {
  const ServiceSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final vehicleType = appState.selectedVehicleType;
    final vehicleModel = appState.selectedVehicleModel ?? 'Unknown';

    if (vehicleType == null) {
      return const Scaffold(
        body: Center(child: Text('Error: No vehicle selected.')),
      );
    }

    final services = appState.getServicesForType(vehicleType);
    if (services.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0B18),
        appBar: AppBar(
          backgroundColor: const Color(0xFF161426),
          elevation: 0,
          title: Text(
            'Select Services',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'No services are currently available for $vehicleModel.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 14),
            ),
          ),
        ),
      );
    }
    final selectedServices = appState.selectedServices;
    final totalAmount = selectedServices.fold<double>(0.0, (sum, item) => sum + item.price);

    // Dynamic accent color based on vehicle type
    Color accentColor;
    switch (vehicleType) {
      case VehicleType.car:
        accentColor = const Color(0xFF9C27B0);
        break;
      case VehicleType.bike:
        accentColor = const Color(0xFF00E676);
        break;
      case VehicleType.ev:
        accentColor = const Color(0xFF00B0FF);
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161426),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Services',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
            Text(
              '$vehicleModel (${vehicleType.displayName})',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8B88A5)),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // List of Services
          ListView.builder(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 120),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
              final isSelected = selectedServices.contains(service);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: InkWell(
                  onTap: () {
                    context.read<AppState>().toggleServiceSelection(service);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: isSelected ? accentColor.withOpacity(0.08) : const Color(0xFF161426),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? accentColor : const Color(0xFF302B53),
                        width: isSelected ? 1.8 : 1.2,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Checkbox custom container
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? accentColor : Colors.transparent,
                            border: Border.all(
                              color: isSelected ? accentColor : const Color(0xFF535072),
                              width: 2.0,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Color(0xFF0D0B18),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        // Service details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                service.name,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                service.description,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF8B88A5),
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '₹${service.price.toStringAsFixed(0)}',
                                style: GoogleFonts.outfit(
                                  color: accentColor,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Fixed Bottom Checkout Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 28),
              decoration: BoxDecoration(
                color: const Color(0xFF161426),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF302B53).withOpacity(0.8),
                    width: 1.5,
                  ),
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${selectedServices.length} Selected',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF8B88A5),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${totalAmount.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        opacity: selectedServices.isNotEmpty ? 1.0 : 0.4,
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: selectedServices.isNotEmpty
                                  ? [const Color(0xFF00E676), const Color(0xFF00B0FF)]
                                  : [const Color(0xFF302B53), const Color(0xFF302B53)],
                            ),
                            boxShadow: selectedServices.isNotEmpty
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF00E676).withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                : [],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: selectedServices.isNotEmpty
                                  ? () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const SelectMechanicScreen(),
                                        ),
                                      );
                                    }
                                  : null,
                              child: Center(
                                child: Text(
                                  'Confirm Services',
                                  style: GoogleFonts.outfit(
                                    color: selectedServices.isNotEmpty
                                        ? const Color(0xFF0D0B18)
                                        : const Color(0xFF8B88A5),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

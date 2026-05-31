import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/service_model.dart';
import '../../../services/app_state.dart';

class VehicleSelectionSheet extends StatefulWidget {
  final VehicleType? initialType;

  const VehicleSelectionSheet({super.key, this.initialType});

  @override
  State<VehicleSelectionSheet> createState() => _VehicleSelectionSheetState();
}

class _VehicleSelectionSheetState extends State<VehicleSelectionSheet> {
  late VehicleType _selectedType;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? VehicleType.car;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final models = appState.getModelsForType(_selectedType);
    final filteredModels = models.where((model) {
      return model.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFF302B53),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Vehicle Model',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Vehicle Type Chips Row
          Row(
            children: [
              _buildTypeCard(VehicleType.car, 'Car', Icons.directions_car_rounded),
              const SizedBox(width: 8),
              _buildTypeCard(VehicleType.bike, 'Bike', Icons.motorcycle_rounded),
              const SizedBox(width: 8),
              _buildTypeCard(VehicleType.ev, 'EV', Icons.electric_car_rounded),
            ],
          ),
          const SizedBox(height: 20),

          // Search Field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D0B18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF302B53)),
            ),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search model (e.g. Nexon, Swift...)',
                hintStyle: GoogleFonts.inter(color: const Color(0xFF8B88A5)),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8B88A5)),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: InputBorder.none,
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.white, size: 18),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),
          const SizedBox(height: 16),

          // Models List
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: filteredModels.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                    child: Center(
                      child: Text(
                        'No matching models found.',
                        style: GoogleFonts.inter(color: const Color(0xFF8B88A5)),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredModels.length,
                    itemBuilder: (context, index) {
                      final model = filteredModels[index];
                      final isCurrent = appState.selectedVehicleModel == model.name;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: InkWell(
                          onTap: () async {
                            await appState.saveSelectedVehicle(_selectedType, model.name);
                            if (context.mounted) {
                              Navigator.of(context).pop(model.name);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? const Color(0xFF08693F).withValues(alpha: 0.12)
                                  : const Color(0xFF0D0B18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCurrent
                                    ? const Color(0xFF00E676)
                                    : const Color(0xFF302B53).withValues(alpha: 0.5),
                                width: isCurrent ? 1.2 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _selectedType == VehicleType.car
                                      ? Icons.directions_car_outlined
                                      : _selectedType == VehicleType.bike
                                          ? Icons.two_wheeler_outlined
                                          : Icons.electric_car_outlined,
                                  color: isCurrent ? const Color(0xFF00E676) : const Color(0xFF8B88A5),
                                  size: 20,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    model.name,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (isCurrent)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF00E676),
                                    size: 18,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCard(VehicleType type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            _searchController.clear();
            _searchQuery = '';
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF08693F).withValues(alpha: 0.15) : const Color(0xFF161426),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF00E676) : const Color(0xFF302B53),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF00E676) : const Color(0xFF8B88A5),
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: isSelected ? Colors.white : const Color(0xFF8B88A5),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showVehicleSelectionBottomSheet(BuildContext context, {VehicleType? initialType}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF161426),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return VehicleSelectionSheet(initialType: initialType);
    },
  );
}

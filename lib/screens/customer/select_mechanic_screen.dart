import 'package:flutter/material.dart';
import 'find_mechanic_screen.dart';

class SelectMechanicScreen extends StatelessWidget {
  final String? specialtyFilter;
  final String? vehicleTypeFilter;

  const SelectMechanicScreen({
    super.key,
    this.specialtyFilter,
    this.vehicleTypeFilter,
  });

  @override
  Widget build(BuildContext context) {
    return FindMechanicScreen(
      initialFilter: specialtyFilter,
      initialVehicleCategory: vehicleTypeFilter,
    );
  }
}

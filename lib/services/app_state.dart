import 'package:flutter/material.dart';
import '../models/service_model.dart';

class AppState extends ChangeNotifier {
  String? _currentCustomerName;
  VehicleType? _selectedVehicleType;
  String? _selectedVehicleModel;
  final List<ServiceItem> _selectedServices = [];
  final List<ServiceBooking> _bookings = [];

  // Getters
  String? get currentCustomerName => _currentCustomerName;
  VehicleType? get selectedVehicleType => _selectedVehicleType;
  String? get selectedVehicleModel => _selectedVehicleModel;
  List<ServiceItem> get selectedServices => List.unmodifiable(_selectedServices);
  List<ServiceBooking> get bookings => List.unmodifiable(_bookings);

  // Mock Data
  final List<VehicleModel> _allModels = [
    // Cars
    const VehicleModel(name: 'Honda Civic', type: VehicleType.car),
    const VehicleModel(name: 'Toyota Camry', type: VehicleType.car),
    const VehicleModel(name: 'Hyundai Creta', type: VehicleType.car),
    const VehicleModel(name: 'Tata Harrier', type: VehicleType.car),
    const VehicleModel(name: 'Suzuki Swift', type: VehicleType.car),
    // Bikes
    const VehicleModel(name: 'Royal Enfield Classic 350', type: VehicleType.bike),
    const VehicleModel(name: 'Yamaha YZF-R15', type: VehicleType.bike),
    const VehicleModel(name: 'KTM Duke 390', type: VehicleType.bike),
    const VehicleModel(name: 'Honda Activa 6G', type: VehicleType.bike),
    const VehicleModel(name: 'Suzuki Access 125', type: VehicleType.bike),
    // EVs
    const VehicleModel(name: 'Tata Nexon EV Max', type: VehicleType.ev),
    const VehicleModel(name: 'Ather 450X Gen 3', type: VehicleType.ev),
    const VehicleModel(name: 'Ola S1 Pro', type: VehicleType.ev),
    const VehicleModel(name: 'Tata Tiago EV', type: VehicleType.ev),
    const VehicleModel(name: 'MG ZS EV', type: VehicleType.ev),
  ];

  final List<ServiceItem> _allServices = [
    // Car Services
    const ServiceItem(
      id: 'car_periodic',
      name: 'Periodic Full Service',
      price: 3499.00,
      description: 'Engine oil top-up, filter clean, coolant level check, and 40-point vehicle inspection.',
      duration: '4 hrs',
      vehicleType: VehicleType.car,
    ),
    const ServiceItem(
      id: 'car_battery',
      name: 'Battery Replacement',
      price: 4999.00,
      description: 'High-performance battery replacement with a 36-month warranty and eco-friendly disposal.',
      duration: '1 hr',
      vehicleType: VehicleType.car,
    ),
    const ServiceItem(
      id: 'car_brake',
      name: 'Front & Rear Brake Service',
      price: 1999.00,
      description: 'Brake pad cleaning, caliper greasing, disc inspection, and brake fluid top-up.',
      duration: '2 hrs',
      vehicleType: VehicleType.car,
    ),
    const ServiceItem(
      id: 'car_engine',
      name: 'Engine Tune-up & Scan',
      price: 5999.00,
      description: 'Spark plug replacement, fuel filter check, throttle body cleaning, and computer diagnostics.',
      duration: '5 hrs',
      vehicleType: VehicleType.car,
    ),
    const ServiceItem(
      id: 'car_ac',
      name: 'Air Conditioning (AC) Service',
      price: 2499.00,
      description: 'AC gas recharge, filter replacement, leak test, and cabin deodorization.',
      duration: '3 hrs',
      vehicleType: VehicleType.car,
    ),
    const ServiceItem(
      id: 'car_alignment',
      name: 'Wheel Alignment & Balancing',
      price: 999.00,
      description: 'Laser wheel alignment, 3D computer balancing, and tyre rotation.',
      duration: '1.5 hrs',
      vehicleType: VehicleType.car,
    ),

    // Bike Services
    const ServiceItem(
      id: 'bike_general',
      name: 'General Oil & Filter Service',
      price: 799.00,
      description: 'Premium engine oil replacement, oil filter replacement, spark plug cleaning, and general check.',
      duration: '1 hr',
      vehicleType: VehicleType.bike,
    ),
    const ServiceItem(
      id: 'bike_chain',
      name: 'Chain Lubrication & Clean',
      price: 299.00,
      description: 'High-pressure chain cleaning, rust removal, and premium dry-wax lubrication coating.',
      duration: '30 mins',
      vehicleType: VehicleType.bike,
    ),
    const ServiceItem(
      id: 'bike_brake',
      name: 'Brake Pads & Shoe Change',
      price: 499.00,
      description: 'Front disc pad or rear brake shoe installation, drum cleaning, and lever play adjustment.',
      duration: '45 mins',
      vehicleType: VehicleType.bike,
    ),
    const ServiceItem(
      id: 'bike_engine',
      name: 'Engine Performance Tuning',
      price: 1499.00,
      description: 'Carburetor cleaning/fuel-injection scanning, valve clearance setting, and air filter wash.',
      duration: '3 hrs',
      vehicleType: VehicleType.bike,
    ),
    const ServiceItem(
      id: 'bike_adjustment',
      name: 'Clutch & Cable Adjustment',
      price: 199.00,
      description: 'Clutch, accelerator, and brake cable inspection, routing adjustment, and lubrication.',
      duration: '20 mins',
      vehicleType: VehicleType.bike,
    ),

    // EV Services
    const ServiceItem(
      id: 'ev_battery',
      name: 'Battery Health & OBD Scan',
      price: 1999.00,
      description: 'Battery state-of-health (SoH) diagnostics, cell voltage balance analysis, and thermal scan.',
      duration: '2 hrs',
      vehicleType: VehicleType.ev,
    ),
    const ServiceItem(
      id: 'ev_wiring',
      name: 'Wiring & Sensor Diagnostics',
      price: 1499.00,
      description: 'High-voltage insulation testing, connector check, and sensor diagnostic scanner run.',
      duration: '1.5 hrs',
      vehicleType: VehicleType.ev,
    ),
    const ServiceItem(
      id: 'ev_braking',
      name: 'Regenerative Braking Service',
      price: 899.00,
      description: 'KERS sensor inspection, electronic caliper configuration, and pad thickness check.',
      duration: '1 hr',
      vehicleType: VehicleType.ev,
    ),
    const ServiceItem(
      id: 'ev_coolant',
      name: 'Electric Motor Coolant Top-up',
      price: 1199.00,
      description: 'Cooling system pressure test and specialized non-conductive motor coolant replenishment.',
      duration: '1 hr',
      vehicleType: VehicleType.ev,
    ),
    const ServiceItem(
      id: 'ev_transmission',
      name: 'EV Reduction Gearbox Service',
      price: 699.00,
      description: 'Single-speed transmission oil check, motor belt tensioning, and bearing lubrication check.',
      duration: '45 mins',
      vehicleType: VehicleType.ev,
    ),
  ];

  // Helper Methods
  List<VehicleModel> getModelsForType(VehicleType type) {
    return _allModels.where((m) => m.type == type).toList();
  }

  List<ServiceItem> getServicesForType(VehicleType type) {
    return _allServices.where((s) => s.vehicleType == type).toList();
  }

  // Actions
  void login(String name) {
    _currentCustomerName = name;
    notifyListeners();
  }

  void logout() {
    _currentCustomerName = null;
    _selectedVehicleType = null;
    _selectedVehicleModel = null;
    _selectedServices.clear();
    notifyListeners();
  }

  void selectVehicleType(VehicleType type) {
    _selectedVehicleType = type;
    _selectedVehicleModel = null;
    _selectedServices.clear();
    notifyListeners();
  }

  void selectVehicleModel(String model) {
    _selectedVehicleModel = model;
    _selectedServices.clear();
    notifyListeners();
  }

  void toggleServiceSelection(ServiceItem item) {
    if (_selectedServices.contains(item)) {
      _selectedServices.remove(item);
    } else {
      _selectedServices.add(item);
    }
    notifyListeners();
  }

  void clearServiceSelection() {
    _selectedServices.clear();
    notifyListeners();
  }

  ServiceBooking? submitBooking() {
    if (_currentCustomerName == null ||
        _selectedVehicleType == null ||
        _selectedVehicleModel == null ||
        _selectedServices.isEmpty) {
      return null;
    }

    final newBooking = ServiceBooking(
      id: 'MT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      customerName: _currentCustomerName!,
      vehicleType: _selectedVehicleType!,
      vehicleModel: _selectedVehicleModel!,
      selectedServices: List.from(_selectedServices),
      bookingDate: DateTime.now(),
    );

    _bookings.add(newBooking);
    
    // Clear selection for next time
    _selectedVehicleType = null;
    _selectedVehicleModel = null;
    _selectedServices.clear();
    
    notifyListeners();
    return newBooking;
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service_model.dart';

class AppState extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  String? _currentCustomerName; // Fallback for testing/non-firebase
  String? _currentCustomerEmail; // Fallback for testing/non-firebase
  String? _currentCustomerPhone;
  String? _customerAddress;
  VehicleType? _selectedVehicleType;
  String? _selectedVehicleModel;
  final List<ServiceItem> _selectedServices = [];
  final List<ServiceBooking> _bookings = [];

  // Constructor
  AppState() {
    _auth.authStateChanges().listen((User? user) async {
      _user = user;
      if (user != null) {
        try {
          final doc = await _firestore.collection('users').doc(user.uid).get();
          if (doc.exists) {
            final data = doc.data();
            _currentCustomerPhone = data?['phone'] as String?;
            _customerAddress = data?['address'] as String?;
            _currentCustomerName = data?['name'] as String?;
            _currentCustomerEmail = data?['email'] as String?;
          }
        } catch (e) {
          debugPrint("Error loading user profile: $e");
        }
      } else {
        _currentCustomerPhone = null;
        _customerAddress = null;
        _currentCustomerEmail = null;
      }
      notifyListeners();
    });
  }

  // Getters
  User? get user => _user;
  String? get currentCustomerName => _user?.displayName ?? _currentCustomerName;
  String? get currentCustomerEmail => _user?.email ?? _currentCustomerEmail;
  String? get currentCustomerPhone => _currentCustomerPhone;
  String? get customerAddress => _customerAddress;
  String? get currentCustomerPhotoUrl => _user?.photoURL;
  
  VehicleType? get selectedVehicleType => _selectedVehicleType;
  String? get selectedVehicleModel => _selectedVehicleModel;
  List<ServiceItem> get selectedServices => List.unmodifiable(_selectedServices);
  List<ServiceBooking> get bookings => List.unmodifiable(_bookings);

  Future<void> updateUserProfile({required String name, required String email, String? phone}) async {
    _currentCustomerName = name;
    _currentCustomerEmail = email;
    _currentCustomerPhone = phone;
    
    final currentUser = _user;
    if (currentUser != null) {
      try {
        await currentUser.updateDisplayName(name);
        await _firestore.collection('users').doc(currentUser.uid).update({
          'name': name,
          'email': email,
          'phone': phone,
        });
      } catch (e) {
        debugPrint("Error updating profile: $e");
      }
    }
    notifyListeners();
  }

  Future<void> updateCustomerAddress(String address) async {
    _customerAddress = address;
    final currentUser = _user;
    if (currentUser != null) {
      try {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'address': address,
        });
      } catch (e) {
        debugPrint("Error updating address: $e");
      }
    }
    notifyListeners();
  }

  // Mock Data
  final List<VehicleModel> _allModels = [
    // Cars
    const VehicleModel(name: 'Maruti Suzuki Swift', type: VehicleType.car),
    const VehicleModel(name: 'Maruti Suzuki Baleno', type: VehicleType.car),
    const VehicleModel(name: 'Maruti Suzuki Brezza', type: VehicleType.car),
    const VehicleModel(name: 'Maruti Suzuki WagonR', type: VehicleType.car),
    const VehicleModel(name: 'Hyundai Creta', type: VehicleType.car),
    const VehicleModel(name: 'Hyundai i20', type: VehicleType.car),
    const VehicleModel(name: 'Hyundai Verna', type: VehicleType.car),
    const VehicleModel(name: 'Tata Nexon', type: VehicleType.car),
    const VehicleModel(name: 'Tata Harrier', type: VehicleType.car),
    const VehicleModel(name: 'Tata Punch', type: VehicleType.car),
    const VehicleModel(name: 'Tata Altroz', type: VehicleType.car),
    const VehicleModel(name: 'Mahindra XUV700', type: VehicleType.car),
    const VehicleModel(name: 'Mahindra Scorpio-N', type: VehicleType.car),
    const VehicleModel(name: 'Mahindra Thar', type: VehicleType.car),
    const VehicleModel(name: 'Toyota Fortuner', type: VehicleType.car),
    const VehicleModel(name: 'Toyota Innova Crysta', type: VehicleType.car),
    const VehicleModel(name: 'Honda City', type: VehicleType.car),
    const VehicleModel(name: 'Honda Amaze', type: VehicleType.car),
    const VehicleModel(name: 'Kia Seltos', type: VehicleType.car),
    const VehicleModel(name: 'Kia Sonet', type: VehicleType.car),
    // Bikes
    const VehicleModel(name: 'Hero Splendor Plus', type: VehicleType.bike),
    const VehicleModel(name: 'Hero HF Deluxe', type: VehicleType.bike),
    const VehicleModel(name: 'Hero Passion Pro', type: VehicleType.bike),
    const VehicleModel(name: 'Hero Glamour', type: VehicleType.bike),
    const VehicleModel(name: 'Hero Xpulse 200 4V', type: VehicleType.bike),
    const VehicleModel(name: 'Honda Shine', type: VehicleType.bike),
    const VehicleModel(name: 'Honda Activa 6G', type: VehicleType.bike),
    const VehicleModel(name: 'Honda Activa 125', type: VehicleType.bike),
    const VehicleModel(name: 'Honda Unicorn', type: VehicleType.bike),
    const VehicleModel(name: 'Honda Hornet 2.0', type: VehicleType.bike),
    const VehicleModel(name: 'TVS Jupiter', type: VehicleType.bike),
    const VehicleModel(name: 'TVS Jupiter 125', type: VehicleType.bike),
    const VehicleModel(name: 'TVS Raider 125', type: VehicleType.bike),
    const VehicleModel(name: 'TVS Apache RTR 160', type: VehicleType.bike),
    const VehicleModel(name: 'TVS Apache RTR 200 4V', type: VehicleType.bike),
    const VehicleModel(name: 'TVS Apache RR 310', type: VehicleType.bike),
    const VehicleModel(name: 'Suzuki Access 125', type: VehicleType.bike),
    const VehicleModel(name: 'Suzuki Burgman Street', type: VehicleType.bike),
    const VehicleModel(name: 'Suzuki Gixxer SF', type: VehicleType.bike),
    const VehicleModel(name: 'Bajaj Platina 110', type: VehicleType.bike),
    const VehicleModel(name: 'Bajaj Pulsar 125', type: VehicleType.bike),
    const VehicleModel(name: 'Bajaj Pulsar 150', type: VehicleType.bike),
    const VehicleModel(name: 'Bajaj Pulsar N160', type: VehicleType.bike),
    const VehicleModel(name: 'Bajaj Pulsar NS200', type: VehicleType.bike),
    const VehicleModel(name: 'Bajaj Pulsar 220F', type: VehicleType.bike),
    const VehicleModel(name: 'Bajaj Avenger Cruise 220', type: VehicleType.bike),
    const VehicleModel(name: 'Yamaha FZ-S', type: VehicleType.bike),
    const VehicleModel(name: 'Yamaha YZF-R15', type: VehicleType.bike),
    const VehicleModel(name: 'Yamaha MT-15', type: VehicleType.bike),
    const VehicleModel(name: 'Yamaha Aerox 155', type: VehicleType.bike),
    const VehicleModel(name: 'Royal Enfield Classic 350', type: VehicleType.bike),
    const VehicleModel(name: 'Royal Enfield Bullet 350', type: VehicleType.bike),
    const VehicleModel(name: 'Royal Enfield Hunter 350', type: VehicleType.bike),
    const VehicleModel(name: 'Royal Enfield Meteor 350', type: VehicleType.bike),
    const VehicleModel(name: 'Royal Enfield Himalayan', type: VehicleType.bike),
    const VehicleModel(name: 'Royal Enfield Continental GT 650', type: VehicleType.bike),
    const VehicleModel(name: 'KTM Duke 125', type: VehicleType.bike),
    const VehicleModel(name: 'KTM Duke 200', type: VehicleType.bike),
    const VehicleModel(name: 'KTM Duke 390', type: VehicleType.bike),
    const VehicleModel(name: 'KTM RC 200', type: VehicleType.bike),
    const VehicleModel(name: 'KTM Adventure 390', type: VehicleType.bike),
    const VehicleModel(name: 'Jawa 42', type: VehicleType.bike),
    const VehicleModel(name: 'Yezdi Roadster', type: VehicleType.bike),
    // EVs
    const VehicleModel(name: 'Tata Nexon EV', type: VehicleType.ev),
    const VehicleModel(name: 'Tata Tiago EV', type: VehicleType.ev),
    const VehicleModel(name: 'Tata Punch EV', type: VehicleType.ev),
    const VehicleModel(name: 'MG ZS EV', type: VehicleType.ev),
    const VehicleModel(name: 'MG Comet EV', type: VehicleType.ev),
    const VehicleModel(name: 'BYD Atto 3', type: VehicleType.ev),
    const VehicleModel(name: 'Hyundai Ioniq 5', type: VehicleType.ev),
    const VehicleModel(name: 'Ola S1 Pro', type: VehicleType.ev),
    const VehicleModel(name: 'Ola S1 Air', type: VehicleType.ev),
    const VehicleModel(name: 'Ather 450X', type: VehicleType.ev),
    const VehicleModel(name: 'TVS iQube', type: VehicleType.ev),
    const VehicleModel(name: 'Bajaj Chetak EV', type: VehicleType.ev),
    const VehicleModel(name: 'Hero Vida V1 Pro', type: VehicleType.ev),
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

  // Google Sign-In Action
  Future<bool> signInWithGoogle() async {
    try {
      // Trigger the Google Authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return false; // User cancelled
      }

      // Obtain auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        // Save/update user profile in Firestore
        await _firestore.collection('users').doc(firebaseUser.uid).set({
          'uid': firebaseUser.uid,
          'name': firebaseUser.displayName,
          'email': firebaseUser.email,
          'photoUrl': firebaseUser.photoURL,
          'lastSignIn': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error in Google Sign-In: $e");
      return false;
    }
  }

  // Logout Action
  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    
    _currentCustomerName = null;
    _currentCustomerEmail = null;
    _currentCustomerPhone = null;
    _customerAddress = null;
    _selectedVehicleType = null;
    _selectedVehicleModel = null;
    _selectedServices.clear();
    notifyListeners();
  }

  // Local-only Fallback Login (for unit tests/offline debugging)
  void loginOffline(String name) {
    _currentCustomerName = name;
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
    final name = currentCustomerName;
    if (name == null ||
        _selectedVehicleType == null ||
        _selectedVehicleModel == null ||
        _selectedServices.isEmpty) {
      return null;
    }

    final newBooking = ServiceBooking(
      id: 'MT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      customerName: name,
      vehicleType: _selectedVehicleType!,
      vehicleModel: _selectedVehicleModel!,
      selectedServices: List.from(_selectedServices),
      bookingDate: DateTime.now(),
    );

    _bookings.add(newBooking);
    
    // In a real app we might also save this booking under users/uid/bookings in Firestore:
    if (_user != null) {
      _firestore.collection('users').doc(_user!.uid).collection('bookings').doc(newBooking.id).set({
        'id': newBooking.id,
        'vehicleType': _selectedVehicleType!.name,
        'vehicleModel': _selectedVehicleModel,
        'totalAmount': newBooking.totalAmount,
        'bookingDate': FieldValue.serverTimestamp(),
        'status': newBooking.status,
        'services': _selectedServices.map((s) => {'id': s.id, 'name': s.name, 'price': s.price}).toList(),
      });
    }

    // Clear selection for next time
    _selectedVehicleType = null;
    _selectedVehicleModel = null;
    _selectedServices.clear();
    
    notifyListeners();
    return newBooking;
  }
}

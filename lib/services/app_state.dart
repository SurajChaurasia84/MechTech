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
  bool _isAuthLoading = true; // true until first Firebase auth event resolves
  String? _userRole; // 'customer' or 'mechanic'
  String? _currentCustomerName; // Fallback for testing/non-firebase
  String? _currentCustomerEmail; // Fallback for testing/non-firebase
  String? _currentCustomerPhone;
  String? _customerAddress;
  VehicleType? _selectedVehicleType;
  String? _selectedVehicleModel;
  final List<ServiceItem> _selectedServices = [];
  final List<ServiceBooking> _bookings = [];
  final List<ServiceBooking> _allGlobalBookings = [];

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
            _userRole = data?['role'] as String?;

            final vTypeStr = data?['selectedVehicleType'] as String?;
            if (vTypeStr != null) {
              if (vTypeStr == 'car') _selectedVehicleType = VehicleType.car;
              if (vTypeStr == 'bike') _selectedVehicleType = VehicleType.bike;
              if (vTypeStr == 'ev') _selectedVehicleType = VehicleType.ev;
            }
            _selectedVehicleModel = data?['selectedVehicleModel'] as String?;
          }
          _userRole ??= 'customer';
        } catch (e) {
          debugPrint("Error loading user profile: $e");
          _userRole = 'customer';
        }
        // Load appropriate bookings/jobs
        if (_userRole == 'mechanic') {
          await _loadMechanicJobsFromFirestore();
        } else {
          await _loadBookingsFromFirestore(user.uid);
        }
      } else {
        _currentCustomerPhone = null;
        _customerAddress = null;
        _currentCustomerEmail = null;
        _userRole = null;
        _bookings.clear();
        _allGlobalBookings.clear();
      }
      _isAuthLoading = false;
      notifyListeners();
    });
  }

  Future<void> _loadBookingsFromFirestore(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('bookings')
          .orderBy('bookingDate', descending: true)
          .get();

      _bookings.clear();
      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Parse vehicleType from stored string
        VehicleType vType = VehicleType.car;
        final vTypeStr = data['vehicleType'] as String? ?? 'car';
        if (vTypeStr == 'bike') vType = VehicleType.bike;
        if (vTypeStr == 'ev') vType = VehicleType.ev;

        // Resolve services by ID using stored price
        final rawServices = (data['services'] as List<dynamic>?) ?? [];
        final resolvedServices = rawServices.map((s) {
          final catalogItem = _allServices.cast<ServiceItem?>().firstWhere(
            (item) => item?.id == s['id'],
            orElse: () => null,
          );
          return ServiceItem(
            id: s['id'] as String? ?? '',
            name: s['name'] as String? ?? catalogItem?.name ?? '',
            price: (s['price'] as num?)?.toDouble() ?? catalogItem?.price ?? 0.0,
            description: catalogItem?.description ?? '',
            duration: catalogItem?.duration ?? '',
            vehicleType: catalogItem?.vehicleType ?? vType,
            category: catalogItem?.category ?? '',
          );
        }).toList();

        // Parse bookingDate — Firestore Timestamp or fallback
        DateTime bookingDate = DateTime.now();
        final rawDate = data['bookingDate'];
        if (rawDate != null && rawDate is Timestamp) {
          bookingDate = rawDate.toDate();
        }

        _bookings.add(ServiceBooking(
          id: data['id'] as String? ?? doc.id,
          customerName: data['customerName'] as String? ?? _currentCustomerName ?? '',
          customerId: data['customerId'] as String? ?? uid,
          customerPhone: data['customerPhone'] as String? ?? _currentCustomerPhone,
          customerEmail: data['customerEmail'] as String? ?? _currentCustomerEmail,
          vehicleType: vType,
          vehicleModel: data['vehicleModel'] as String? ?? '',
          selectedServices: resolvedServices,
          bookingDate: bookingDate,
          status: data['status'] as String? ?? 'Pending',
          mechanicId: data['mechanicId'] as String?,
          mechanicName: data['mechanicName'] as String?,
          latitude: (data['latitude'] as num?)?.toDouble(),
          longitude: (data['longitude'] as num?)?.toDouble(),
          bookingLocation: data['bookingLocation'] as String?,
        ));
      }
    } catch (e) {
      debugPrint("Error loading bookings: $e");
    }
  }

  Future<void> _loadMechanicJobsFromFirestore() async {
    try {
      final snapshot = await _firestore
          .collection('bookings')
          .orderBy('bookingDate', descending: true)
          .get();

      _allGlobalBookings.clear();
      for (final doc in snapshot.docs) {
        final data = doc.data();

        VehicleType vType = VehicleType.car;
        final vTypeStr = data['vehicleType'] as String? ?? 'car';
        if (vTypeStr == 'bike') vType = VehicleType.bike;
        if (vTypeStr == 'ev') vType = VehicleType.ev;

        final rawServices = (data['services'] as List<dynamic>?) ?? [];
        final resolvedServices = rawServices.map((s) {
          final catalogItem = _allServices.cast<ServiceItem?>().firstWhere(
            (item) => item?.id == s['id'],
            orElse: () => null,
          );
          return ServiceItem(
            id: s['id'] as String? ?? '',
            name: s['name'] as String? ?? catalogItem?.name ?? '',
            price: (s['price'] as num?)?.toDouble() ?? catalogItem?.price ?? 0.0,
            description: catalogItem?.description ?? '',
            duration: catalogItem?.duration ?? '',
            vehicleType: catalogItem?.vehicleType ?? vType,
            category: catalogItem?.category ?? '',
          );
        }).toList();

        DateTime bookingDate = DateTime.now();
        final rawDate = data['bookingDate'];
        if (rawDate != null && rawDate is Timestamp) {
          bookingDate = rawDate.toDate();
        }

        _allGlobalBookings.add(ServiceBooking(
          id: data['id'] as String? ?? doc.id,
          customerName: data['customerName'] as String? ?? '',
          customerId: data['customerId'] as String?,
          customerPhone: data['customerPhone'] as String?,
          customerEmail: data['customerEmail'] as String?,
          vehicleType: vType,
          vehicleModel: data['vehicleModel'] as String? ?? '',
          selectedServices: resolvedServices,
          bookingDate: bookingDate,
          status: data['status'] as String? ?? 'Pending',
          mechanicId: data['mechanicId'] as String?,
          mechanicName: data['mechanicName'] as String?,
          latitude: (data['latitude'] as num?)?.toDouble(),
          longitude: (data['longitude'] as num?)?.toDouble(),
          bookingLocation: data['bookingLocation'] as String?,
        ));
      }
    } catch (e) {
      debugPrint("Error loading mechanic jobs: $e");
    }
  }

  // Getters
  User? get user => _user;
  bool get isAuthLoading => _isAuthLoading;
  String? get userRole => _userRole;
  String? get currentCustomerName => _user?.displayName ?? _currentCustomerName;
  String? get currentCustomerEmail => _user?.email ?? _currentCustomerEmail;
  String? get currentCustomerPhone => _currentCustomerPhone;
  String? get customerAddress => _customerAddress;
  String? get currentCustomerPhotoUrl => _user?.photoURL;
  
  VehicleType? get selectedVehicleType => _selectedVehicleType;
  String? get selectedVehicleModel => _selectedVehicleModel;
  List<ServiceItem> get selectedServices => List.unmodifiable(_selectedServices);
  List<ServiceBooking> get bookings => List.unmodifiable(_bookings);
  List<ServiceBooking> get allGlobalBookings => List.unmodifiable(_allGlobalBookings);

  Future<void> updateUserProfile({required String name, required String email, String? phone}) async {
    _currentCustomerName = name;
    _currentCustomerEmail = email;
    _currentCustomerPhone = phone;
    
    final currentUser = _user;
    if (currentUser != null) {
      try {
        await currentUser.updateDisplayName(name);
        await currentUser.reload();           // refresh cached User object
        _user = _auth.currentUser;            // re-assign with updated displayName
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
      category: 'Oil Change',
    ),
    const ServiceItem(
      id: 'car_battery',
      name: 'Battery Replacement',
      price: 4999.00,
      description: 'High-performance battery replacement with a 36-month warranty and eco-friendly disposal.',
      duration: '1 hr',
      vehicleType: VehicleType.car,
      category: 'Electrical',
    ),
    const ServiceItem(
      id: 'car_brake',
      name: 'Front & Rear Brake Service',
      price: 1999.00,
      description: 'Brake pad cleaning, caliper greasing, disc inspection, and brake fluid top-up.',
      duration: '2 hrs',
      vehicleType: VehicleType.car,
      category: 'Brakes',
    ),
    const ServiceItem(
      id: 'car_engine',
      name: 'Engine Tune-up & Scan',
      price: 5999.00,
      description: 'Spark plug replacement, fuel filter check, throttle body cleaning, and computer diagnostics.',
      duration: '5 hrs',
      vehicleType: VehicleType.car,
      category: 'Engine',
    ),
    const ServiceItem(
      id: 'car_ac',
      name: 'Air Conditioning (AC) Service',
      price: 2499.00,
      description: 'AC gas recharge, filter replacement, leak test, and cabin deodorization.',
      duration: '3 hrs',
      vehicleType: VehicleType.car,
      category: 'Electrical',
    ),
    const ServiceItem(
      id: 'car_alignment',
      name: 'Wheel Alignment & Balancing',
      price: 999.00,
      description: 'Laser wheel alignment, 3D computer balancing, and tyre rotation.',
      duration: '1.5 hrs',
      vehicleType: VehicleType.car,
      category: 'Tyre',
    ),

    // Bike Services
    const ServiceItem(
      id: 'bike_general',
      name: 'General Oil & Filter Service',
      price: 799.00,
      description: 'Premium engine oil replacement, oil filter replacement, spark plug cleaning, and general check.',
      duration: '1 hr',
      vehicleType: VehicleType.bike,
      category: 'Oil Change',
    ),
    const ServiceItem(
      id: 'bike_chain',
      name: 'Chain Lubrication & Clean',
      price: 299.00,
      description: 'High-pressure chain cleaning, rust removal, and premium dry-wax lubrication coating.',
      duration: '30 mins',
      vehicleType: VehicleType.bike,
      category: 'Tyre',
    ),
    const ServiceItem(
      id: 'bike_brake',
      name: 'Brake Pads & Shoe Change',
      price: 499.00,
      description: 'Front disc pad or rear brake shoe installation, drum cleaning, and lever play adjustment.',
      duration: '45 mins',
      vehicleType: VehicleType.bike,
      category: 'Brakes',
    ),
    const ServiceItem(
      id: 'bike_engine',
      name: 'Engine Performance Tuning',
      price: 1499.00,
      description: 'Carburetor cleaning/fuel-injection scanning, valve clearance setting, and air filter wash.',
      duration: '3 hrs',
      vehicleType: VehicleType.bike,
      category: 'Engine',
    ),
    const ServiceItem(
      id: 'bike_adjustment',
      name: 'Clutch & Cable Adjustment',
      price: 199.00,
      description: 'Clutch, accelerator, and brake cable inspection, routing adjustment, and lubrication.',
      duration: '20 mins',
      vehicleType: VehicleType.bike,
      category: 'Engine',
    ),

    // EV Services
    const ServiceItem(
      id: 'ev_battery',
      name: 'Battery Health & OBD Scan',
      price: 1999.00,
      description: 'Battery state-of-health (SoH) diagnostics, cell voltage balance analysis, and thermal scan.',
      duration: '2 hrs',
      vehicleType: VehicleType.ev,
      category: 'Electrical',
    ),
    const ServiceItem(
      id: 'ev_wiring',
      name: 'Wiring & Sensor Diagnostics',
      price: 1499.00,
      description: 'High-voltage insulation testing, connector check, and sensor diagnostic scanner run.',
      duration: '1.5 hrs',
      vehicleType: VehicleType.ev,
      category: 'Electrical',
    ),
    const ServiceItem(
      id: 'ev_braking',
      name: 'Regenerative Braking Service',
      price: 899.00,
      description: 'KERS sensor inspection, electronic caliper configuration, and pad thickness check.',
      duration: '1 hr',
      vehicleType: VehicleType.ev,
      category: 'Brakes',
    ),
    const ServiceItem(
      id: 'ev_coolant',
      name: 'Electric Motor Coolant Top-up',
      price: 1199.00,
      description: 'Cooling system pressure test and specialized non-conductive motor coolant replenishment.',
      duration: '1 hr',
      vehicleType: VehicleType.ev,
      category: 'Electrical',
    ),
    const ServiceItem(
      id: 'ev_transmission',
      name: 'EV Reduction Gearbox Service',
      price: 699.00,
      description: 'Single-speed transmission oil check, motor belt tensioning, and bearing lubrication check.',
      duration: '45 mins',
      vehicleType: VehicleType.ev,
      category: 'Engine',
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
  Future<bool> signInWithGoogle({required String selectedRole}) async {
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
        String finalRole = selectedRole;

        // Save/update user profile in Firestore
        await _firestore.collection('users').doc(firebaseUser.uid).set({
          'uid': firebaseUser.uid,
          'name': firebaseUser.displayName,
          'email': firebaseUser.email,
          'photoUrl': firebaseUser.photoURL,
          'role': finalRole,
          'lastSignIn': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        _userRole = finalRole;
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
    _userRole = null;
    _selectedServices.clear();
    _bookings.clear();
    _allGlobalBookings.clear();
    notifyListeners();
  }

  // Switch User Role
  Future<void> switchUserRole(String newRole) async {
    final uid = _user?.uid;
    if (uid == null) return;

    try {
      await _firestore.collection('users').doc(uid).update({
        'role': newRole,
      });
      _userRole = newRole;

      // Load appropriate bookings/jobs after role switch
      if (_userRole == 'mechanic') {
        await _loadMechanicJobsFromFirestore();
      } else {
        await _loadBookingsFromFirestore(uid);
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error switching user role: $e");
    }
  }

  // Local-only Fallback Login (for unit tests/offline debugging)
  void loginOffline(String name, {String role = 'customer'}) {
    _currentCustomerName = name;
    _userRole = role;
    notifyListeners();
  }

  // Mechanic Actions
  Future<void> acceptJob(String bookingId) async {
    final currentUser = _user;
    if (currentUser == null) return;

    try {
      final doc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final customerId = data['customerId'] as String?;

      final updateData = {
        'status': 'In Progress',
        'mechanicId': currentUser.uid,
        'mechanicName': currentUser.displayName ?? 'Professional Mechanic',
      };

      // Update global document
      await _firestore.collection('bookings').doc(bookingId).update(updateData);

      // Update customer document
      if (customerId != null) {
        await _firestore
            .collection('users')
            .doc(customerId)
            .collection('bookings')
            .doc(bookingId)
            .update(updateData);
      }

      // Reload jobs
      await _loadMechanicJobsFromFirestore();
    } catch (e) {
      debugPrint("Error accepting job: $e");
    }
  }

  Future<void> completeJob(String bookingId) async {
    try {
      final doc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final customerId = data['customerId'] as String?;

      final updateData = {
        'status': 'Completed',
      };

      // Update global document
      await _firestore.collection('bookings').doc(bookingId).update(updateData);

      // Update customer document
      if (customerId != null) {
        await _firestore
            .collection('users')
            .doc(customerId)
            .collection('bookings')
            .doc(bookingId)
            .update(updateData);
      }

      // Reload jobs
      await _loadMechanicJobsFromFirestore();
    } catch (e) {
      debugPrint("Error completing job: $e");
    }
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

  void applyMechanicRates(Map<String, int> specializationRates) {
    for (int i = 0; i < _selectedServices.length; i++) {
      final service = _selectedServices[i];
      final rate = specializationRates[service.category] ?? specializationRates[service.name];
      if (rate != null && rate > 0) {
        _selectedServices[i] = ServiceItem(
          id: service.id,
          name: service.name,
          price: rate.toDouble(),
          description: service.description,
          duration: service.duration,
          vehicleType: service.vehicleType,
          category: service.category,
        );
      }
    }
    notifyListeners();
  }

  Future<void> saveSelectedVehicle(VehicleType type, String model) async {
    _selectedVehicleType = type;
    _selectedVehicleModel = model;
    notifyListeners();

    final currentUser = _user;
    if (currentUser != null) {
      try {
        await _firestore.collection('users').doc(currentUser.uid).set({
          'selectedVehicleType': type.name,
          'selectedVehicleModel': model,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("Error saving selected vehicle to Firestore: $e");
      }
    }
  }

  Future<ServiceBooking?> submitBooking({
    double? latitude,
    double? longitude,
    String? bookingLocation,
    String? mechanicId,
    String? mechanicName,
  }) async {
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
      customerId: _user?.uid,
      customerPhone: _currentCustomerPhone,
      customerEmail: currentCustomerEmail,
      vehicleType: _selectedVehicleType!,
      vehicleModel: _selectedVehicleModel!,
      selectedServices: List.from(_selectedServices),
      bookingDate: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      bookingLocation: bookingLocation,
      mechanicId: mechanicId,
      mechanicName: mechanicName,
    );

    // Save to Firestore first
    if (_user != null) {
      try {
        final bookingData = {
          'id': newBooking.id,
          'customerId': _user!.uid,
          'customerName': name,
          'customerPhone': _currentCustomerPhone,
          'customerEmail': currentCustomerEmail,
          'vehicleType': _selectedVehicleType!.name,
          'vehicleModel': _selectedVehicleModel,
          'totalAmount': newBooking.totalAmount,
          'bookingDate': FieldValue.serverTimestamp(),
          'status': newBooking.status,
          'mechanicId': mechanicId,
          'mechanicName': mechanicName,
          'latitude': latitude,
          'longitude': longitude,
          'bookingLocation': bookingLocation,
          'services': _selectedServices
              .map((s) => {'id': s.id, 'name': s.name, 'price': s.price})
              .toList(),
        };

        // Write to customer's subcollection
        await _firestore
            .collection('users')
            .doc(_user!.uid)
            .collection('bookings')
            .doc(newBooking.id)
            .set(bookingData);

        // Write to global root bookings collection
        await _firestore
            .collection('bookings')
            .doc(newBooking.id)
            .set(bookingData);

        // Reload from Firestore so history is consistent
        await _loadBookingsFromFirestore(_user!.uid);
      } catch (e) {
        debugPrint("Error saving booking: $e");
        // Fallback: add locally if Firestore fails
        _bookings.insert(0, newBooking);
      }
    } else {
      // Offline fallback
      _bookings.insert(0, newBooking);
    }

    // Clear selection for next time
    _selectedVehicleType = null;
    _selectedVehicleModel = null;
    _selectedServices.clear();

    notifyListeners();
    return newBooking;
  }
}

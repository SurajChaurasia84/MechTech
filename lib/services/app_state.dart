import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  List<ServiceItem> _activeServices = [];
  final List<ServiceItem> _selectedServices = [];
  final List<ServiceBooking> _bookings = [];
  final List<ServiceBooking> _allGlobalBookings = [];

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Constructor
  AppState() {
    _initLocalNotifications();
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
            await fetchActiveServices();
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
        initPushNotifications();
      } else {
        _currentCustomerPhone = null;
        _customerAddress = null;
        _currentCustomerEmail = null;
        _userRole = null;
        _bookings.clear();
        _allGlobalBookings.clear();
        _activeServices.clear();
      }
      _isAuthLoading = false;
      notifyListeners();
    });
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint("Notification clicked: ${details.payload}");
      },
    );
  }

  Future<void> initPushNotifications() async {
    final currentUser = _user;
    if (currentUser == null) return;

    try {
      // 1. Request Permission
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('User granted permission: ${settings.authorizationStatus}');

      // Request runtime notification permission for Android 13+
      final androidPlugin = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }

      // 2. Fetch token
      String? token = await _fcm.getToken();
      if (token != null) {
        debugPrint("FCM Token: $token");
        await _saveFcmToken(currentUser.uid, token);
      }

      // 3. Set up token refresh listener
      _fcm.onTokenRefresh.listen((newToken) async {
        if (_auth.currentUser != null) {
          await _saveFcmToken(_auth.currentUser!.uid, newToken);
        }
      });

      // 4. Foreground Message Listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
          _showLocalNotification(message);
        }
      });
    } catch (e) {
      debugPrint("Error initializing push notifications: $e");
    }
  }

  Future<void> _saveFcmToken(String uid, String token) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error saving FCM token: $e");
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'mechtech_booking_channel',
      'Booking Notifications',
      channelDescription: 'Notifications related to booking requests and updates.',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      icon: '@mipmap/launcher_icon',
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotificationsPlugin.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: platformChannelSpecifics,
      payload: jsonEncode(message.data),
    );
  }

  Future<void> sendNotification({
    required String recipientUid,
    required String title,
    required String body,
  }) async {
    try {
      // 1. Fetch recipient's token from firestore
      final userDoc = await _firestore.collection('users').doc(recipientUid).get();
      if (!userDoc.exists) {
        debugPrint("User profile for $recipientUid not found.");
        return;
      }

      final fcmToken = userDoc.data()?['fcmToken'] as String?;
      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint("No FCM token registered for user $recipientUid");
        return;
      }

      // 2. Post to Vercel Gateway
      final url = Uri.parse('https://vercel-ten-gray-35.vercel.app/api/send-notification');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': fcmToken,
          'title': title,
          'body': body,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("FCM notification dispatched successfully to $recipientUid");
      } else {
        debugPrint("Failed to send notification: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("Error sending push notification via Vercel gateway: $e");
    }
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
          final name = s['name'] as String? ?? '';
          return ServiceItem(
            id: s['id'] as String? ?? '',
            name: name,
            price: (s['price'] as num?)?.toDouble() ?? 0.0,
            description: 'Professional $name services.',
            vehicleType: vType,
            category: name,
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
          final name = s['name'] as String? ?? '';
          return ServiceItem(
            id: s['id'] as String? ?? '',
            name: name,
            price: (s['price'] as num?)?.toDouble() ?? 0.0,
            description: 'Professional $name services.',
            vehicleType: vType,
            category: name,
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
    const VehicleModel(name: 'Maruti Suzuki Dzire', type: VehicleType.car),
    const VehicleModel(name: 'Maruti Suzuki Ertiga', type: VehicleType.car),
    const VehicleModel(name: 'Maruti Suzuki Grand Vitara', type: VehicleType.car),
    const VehicleModel(name: 'Maruti Suzuki Alto K10', type: VehicleType.car),
    const VehicleModel(name: 'Maruti Suzuki Celerio', type: VehicleType.car),
    const VehicleModel(name: 'Maruti Suzuki S-Presso', type: VehicleType.car),
    const VehicleModel(name: 'Maruti Suzuki Ignis', type: VehicleType.car),
    const VehicleModel(name: 'Maruti Suzuki Ciaz', type: VehicleType.car),
    const VehicleModel(name: 'Hyundai Creta', type: VehicleType.car),
    const VehicleModel(name: 'Hyundai i20', type: VehicleType.car),
    const VehicleModel(name: 'Hyundai i10 Grand', type: VehicleType.car),
    const VehicleModel(name: 'Hyundai Verna', type: VehicleType.car),
    const VehicleModel(name: 'Hyundai Venue', type: VehicleType.car),
    const VehicleModel(name: 'Hyundai Exter', type: VehicleType.car),
    const VehicleModel(name: 'Hyundai Aura', type: VehicleType.car),
    const VehicleModel(name: 'Hyundai Alcazar', type: VehicleType.car),
    const VehicleModel(name: 'Hyundai Tucson', type: VehicleType.car),
    const VehicleModel(name: 'Tata Nexon', type: VehicleType.car),
    const VehicleModel(name: 'Tata Harrier', type: VehicleType.car),
    const VehicleModel(name: 'Tata Punch', type: VehicleType.car),
    const VehicleModel(name: 'Tata Altroz', type: VehicleType.car),
    const VehicleModel(name: 'Tata Tiago', type: VehicleType.car),
    const VehicleModel(name: 'Tata Tigor', type: VehicleType.car),
    const VehicleModel(name: 'Tata Safari', type: VehicleType.car),
    const VehicleModel(name: 'Mahindra XUV700', type: VehicleType.car),
    const VehicleModel(name: 'Mahindra Scorpio-N', type: VehicleType.car),
    const VehicleModel(name: 'Mahindra Scorpio Classic', type: VehicleType.car),
    const VehicleModel(name: 'Mahindra Thar', type: VehicleType.car),
    const VehicleModel(name: 'Mahindra Bolero', type: VehicleType.car),
    const VehicleModel(name: 'Mahindra XUV 3XO', type: VehicleType.car),
    const VehicleModel(name: 'Mahindra Bolero Neo', type: VehicleType.car),
    const VehicleModel(name: 'Toyota Fortuner', type: VehicleType.car),
    const VehicleModel(name: 'Toyota Innova Crysta', type: VehicleType.car),
    const VehicleModel(name: 'Toyota Innova Hycross', type: VehicleType.car),
    const VehicleModel(name: 'Toyota Urban Cruiser Taisor', type: VehicleType.car),
    const VehicleModel(name: 'Toyota Glanza', type: VehicleType.car),
    const VehicleModel(name: 'Honda City', type: VehicleType.car),
    const VehicleModel(name: 'Honda Amaze', type: VehicleType.car),
    const VehicleModel(name: 'Honda Elevate', type: VehicleType.car),
    const VehicleModel(name: 'Kia Seltos', type: VehicleType.car),
    const VehicleModel(name: 'Kia Sonet', type: VehicleType.car),
    const VehicleModel(name: 'Kia Carens', type: VehicleType.car),
    const VehicleModel(name: 'Volkswagen Virtus', type: VehicleType.car),
    const VehicleModel(name: 'Volkswagen Taigun', type: VehicleType.car),
    const VehicleModel(name: 'Skoda Slavia', type: VehicleType.car),
    const VehicleModel(name: 'Skoda Kushaq', type: VehicleType.car),
    const VehicleModel(name: 'Renault Kwid', type: VehicleType.car),
    const VehicleModel(name: 'Renault Triber', type: VehicleType.car),
    const VehicleModel(name: 'Renault Kiger', type: VehicleType.car),
    const VehicleModel(name: 'Nissan Magnite', type: VehicleType.car),
    // Bikes
    const VehicleModel(name: 'Hero Splendor Plus', type: VehicleType.bike),
    const VehicleModel(name: 'Hero HF Deluxe', type: VehicleType.bike),
    const VehicleModel(name: 'Hero Passion Pro', type: VehicleType.bike),
    const VehicleModel(name: 'Hero Glamour', type: VehicleType.bike),
    const VehicleModel(name: 'Hero Xpulse 200 4V', type: VehicleType.bike),
    const VehicleModel(name: 'Hero Mavrick 440', type: VehicleType.bike),
    const VehicleModel(name: 'Hero Karizma XMR', type: VehicleType.bike),
    const VehicleModel(name: 'Honda Shine', type: VehicleType.bike),
    const VehicleModel(name: 'Honda Activa 6G', type: VehicleType.bike),
    const VehicleModel(name: 'Honda Activa 125', type: VehicleType.bike),
    const VehicleModel(name: 'Honda Unicorn', type: VehicleType.bike),
    const VehicleModel(name: 'Honda Hornet 2.0', type: VehicleType.bike),
    const VehicleModel(name: 'Honda SP 125', type: VehicleType.bike),
    const VehicleModel(name: 'Honda H\'ness CB350', type: VehicleType.bike),
    const VehicleModel(name: 'TVS Jupiter', type: VehicleType.bike),
    const VehicleModel(name: 'TVS Jupiter 125', type: VehicleType.bike),
    const VehicleModel(name: 'TVS Raider 125', type: VehicleType.bike),
    const VehicleModel(name: 'TVS Apache RTR 160', type: VehicleType.bike),
    const VehicleModel(name: 'TVS Apache RTR 200 4V', type: VehicleType.bike),
    const VehicleModel(name: 'TVS Apache RR 310', type: VehicleType.bike),
    const VehicleModel(name: 'TVS Ntorq 125', type: VehicleType.bike),
    const VehicleModel(name: 'TVS Ronin', type: VehicleType.bike),
    const VehicleModel(name: 'Suzuki Access 125', type: VehicleType.bike),
    const VehicleModel(name: 'Suzuki Burgman Street', type: VehicleType.bike),
    const VehicleModel(name: 'Suzuki Gixxer SF', type: VehicleType.bike),
    const VehicleModel(name: 'Suzuki V-Strom SX', type: VehicleType.bike),
    const VehicleModel(name: 'Bajaj Platina 110', type: VehicleType.bike),
    const VehicleModel(name: 'Bajaj Pulsar 125', type: VehicleType.bike),
    const VehicleModel(name: 'Bajaj Pulsar 150', type: VehicleType.bike),
    const VehicleModel(name: 'Bajaj Pulsar N160', type: VehicleType.bike),
    const VehicleModel(name: 'Bajaj Pulsar NS200', type: VehicleType.bike),
    const VehicleModel(name: 'Bajaj Pulsar 220F', type: VehicleType.bike),
    const VehicleModel(name: 'Bajaj Avenger Cruise 220', type: VehicleType.bike),
    const VehicleModel(name: 'Bajaj Dominar 400', type: VehicleType.bike),
    const VehicleModel(name: 'Yamaha FZ-S', type: VehicleType.bike),
    const VehicleModel(name: 'Yamaha YZF-R15', type: VehicleType.bike),
    const VehicleModel(name: 'Yamaha MT-15', type: VehicleType.bike),
    const VehicleModel(name: 'Yamaha Aerox 155', type: VehicleType.bike),
    const VehicleModel(name: 'Yamaha RayZR 125', type: VehicleType.bike),
    const VehicleModel(name: 'Royal Enfield Classic 350', type: VehicleType.bike),
    const VehicleModel(name: 'Royal Enfield Bullet 350', type: VehicleType.bike),
    const VehicleModel(name: 'Royal Enfield Hunter 350', type: VehicleType.bike),
    const VehicleModel(name: 'Royal Enfield Meteor 350', type: VehicleType.bike),
    const VehicleModel(name: 'Royal Enfield Himalayan', type: VehicleType.bike),
    const VehicleModel(name: 'Royal Enfield Continental GT 650', type: VehicleType.bike),
    const VehicleModel(name: 'Royal Enfield Interceptor 650', type: VehicleType.bike),
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
    const VehicleModel(name: 'Tata Tigor EV', type: VehicleType.ev),
    const VehicleModel(name: 'Tata Punch EV', type: VehicleType.ev),
    const VehicleModel(name: 'Tata Curvv EV', type: VehicleType.ev),
    const VehicleModel(name: 'MG ZS EV', type: VehicleType.ev),
    const VehicleModel(name: 'MG Comet EV', type: VehicleType.ev),
    const VehicleModel(name: 'MG Windsor EV', type: VehicleType.ev),
    const VehicleModel(name: 'BYD Atto 3', type: VehicleType.ev),
    const VehicleModel(name: 'BYD Seal', type: VehicleType.ev),
    const VehicleModel(name: 'BYD e6', type: VehicleType.ev),
    const VehicleModel(name: 'Hyundai Ioniq 5', type: VehicleType.ev),
    const VehicleModel(name: 'Kia EV6', type: VehicleType.ev),
    const VehicleModel(name: 'Ola S1 Pro', type: VehicleType.ev),
    const VehicleModel(name: 'Ola S1 Air', type: VehicleType.ev),
    const VehicleModel(name: 'Ola S1 X', type: VehicleType.ev),
    const VehicleModel(name: 'Ola Roadster', type: VehicleType.ev),
    const VehicleModel(name: 'Ather 450X', type: VehicleType.ev),
    const VehicleModel(name: 'Ather Apex', type: VehicleType.ev),
    const VehicleModel(name: 'Ather Rizta', type: VehicleType.ev),
    const VehicleModel(name: 'TVS iQube', type: VehicleType.ev),
    const VehicleModel(name: 'Bajaj Chetak EV', type: VehicleType.ev),
    const VehicleModel(name: 'Hero Vida V1 Pro', type: VehicleType.ev),
    const VehicleModel(name: 'Simple One', type: VehicleType.ev),
    const VehicleModel(name: 'River Indie', type: VehicleType.ev),
    const VehicleModel(name: 'Ultraviolette F77', type: VehicleType.ev),
    const VehicleModel(name: 'Revolt RV400', type: VehicleType.ev),
    const VehicleModel(name: 'Oben Rorr', type: VehicleType.ev),
  ];

  // Helper Methods
  List<VehicleModel> getModelsForType(VehicleType type) {
    return _allModels.where((m) => m.type == type).toList();
  }

  List<ServiceItem> getServicesForType(VehicleType type) {
    return _activeServices.where((s) => s.vehicleType == type).toList();
  }

  Future<void> fetchActiveServices() async {
    final typeStr = _selectedVehicleType?.name;
    final modelStr = _selectedVehicleModel;
    if (typeStr == null || modelStr == null) {
      _activeServices = [];
      return;
    }

    try {
      final querySnapshot = await _firestore
          .collection('job_posts')
          .where('vehicleCategory', isEqualTo: typeStr)
          .where('vehicleModel', isEqualTo: modelStr)
          .get();

      final Map<String, ServiceItem> dynamicServicesMap = {};

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final categories = (data['categories'] as List<dynamic>?)?.map((c) => c.toString()).toList() ?? [];
        final specializationRates = Map<String, int>.from(
          (data['specializationRates'] as Map<String, dynamic>? ?? {}).map(
            (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
          ),
        );

        for (final serviceName in categories) {
          final rate = specializationRates[serviceName] ?? 0;
          if (rate > 0) {
            if (dynamicServicesMap.containsKey(serviceName)) {
              // Keep minimum price across all mechanics
              final existing = dynamicServicesMap[serviceName]!;
              if (rate < existing.price) {
                dynamicServicesMap[serviceName] = ServiceItem(
                  id: existing.id,
                  name: serviceName,
                  price: rate.toDouble(),
                  description: existing.description,
                  vehicleType: _selectedVehicleType!,
                  category: serviceName,
                );
              }
            } else {
              dynamicServicesMap[serviceName] = ServiceItem(
                id: 'dyn_${serviceName.hashCode}',
                name: serviceName,
                price: rate.toDouble(),
                description: 'Professional $serviceName services offered by expert mechanics for $modelStr.',
                vehicleType: _selectedVehicleType!,
                category: serviceName,
              );
            }
          }
        }
      }

      _activeServices = dynamicServicesMap.values.toList();
    } catch (e) {
      debugPrint("Error fetching dynamic services: $e");
    }
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

        // Load appropriate bookings/jobs and update UI
        if (_userRole == 'mechanic') {
          await _loadMechanicJobsFromFirestore();
        } else {
          await _loadBookingsFromFirestore(firebaseUser.uid);
        }
        notifyListeners();
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
      final vehicleModel = data['vehicleModel'] as String? ?? 'Vehicle';

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

      if (customerId != null) {
        sendNotification(
          recipientUid: customerId,
          title: 'Booking Accepted!',
          body: '${currentUser.displayName ?? 'Mechanic'} has accepted your booking for $vehicleModel.',
        );
      }
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
      final vehicleModel = data['vehicleModel'] as String? ?? 'Vehicle';
      final mechanicName = data['mechanicName'] as String? ?? 'Mechanic';

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

      if (customerId != null) {
        sendNotification(
          recipientUid: customerId,
          title: 'Service Completed!',
          body: '$mechanicName has completed the service on your $vehicleModel.',
        );
      }
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
    await fetchActiveServices();
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

        if (mechanicId != null) {
          sendNotification(
            recipientUid: mechanicId,
            title: 'New Booking Request!',
            body: '$name requested a service for ${newBooking.vehicleModel}.',
          );
        }
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

  Future<bool> cancelBooking(String bookingId) async {
    final currentUser = _user;
    
    // Always remove from local list to reflect instantly in UI
    _bookings.removeWhere((b) => b.id == bookingId);
    notifyListeners();

    if (currentUser == null) return true;

    try {
      // Fetch details before deleting
      final doc = await _firestore.collection('bookings').doc(bookingId).get();
      String? customerId;
      String? mechanicId;
      String? customerName;
      String? mechanicName;
      if (doc.exists) {
        final data = doc.data()!;
        customerId = data['customerId'] as String?;
        mechanicId = data['mechanicId'] as String?;
        customerName = data['customerName'] as String?;
        mechanicName = data['mechanicName'] as String?;
      }

      // 1. Delete from customer's subcollection
      final targetCustomer = customerId ?? currentUser.uid;
      await _firestore
          .collection('users')
          .doc(targetCustomer)
          .collection('bookings')
          .doc(bookingId)
          .delete();

      // 2. Delete from global root bookings collection
      await _firestore
          .collection('bookings')
          .doc(bookingId)
          .delete();

      // Reload bookings/jobs based on role
      if (_userRole == 'mechanic') {
        await _loadMechanicJobsFromFirestore();
      } else {
        await _loadBookingsFromFirestore(currentUser.uid);
      }
      notifyListeners();

      // Trigger notifications
      if (customerId != null) {
        if (currentUser.uid == customerId && mechanicId != null) {
          sendNotification(
            recipientUid: mechanicId,
            title: 'Booking Cancelled',
            body: '${customerName ?? 'Customer'} cancelled booking $bookingId.',
          );
        } else if (currentUser.uid == mechanicId) {
          sendNotification(
            recipientUid: customerId,
            title: 'Booking Declined',
            body: '${mechanicName ?? 'Mechanic'} has declined your booking request.',
          );
        }
      }

      return true;
    } catch (e) {
      debugPrint("Error cancelling booking: $e");
      return false;
    }
  }
}


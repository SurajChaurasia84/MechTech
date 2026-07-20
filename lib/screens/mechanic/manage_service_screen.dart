
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/app_state.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';
import 'dart:convert';
import '../../models/service_model.dart';
import '../../utils/location_helper.dart';

class SubCategoryItem {
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController descController;

  SubCategoryItem({
    required String name,
    required String price,
    String description = '',
  })  : nameController = TextEditingController(text: name),
        priceController = TextEditingController(text: price),
        descController = TextEditingController(text: description);

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    descController.dispose();
  }
}

class ManageServiceScreen extends StatefulWidget {
  final JobPost? existingPost;
  const ManageServiceScreen({super.key, this.existingPost});

  @override
  State<ManageServiceScreen> createState() => _ManageServiceScreenState();
}

class _ManageServiceScreenState extends State<ManageServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _expController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _customModelController = TextEditingController();

  bool _isLoading = false;
  bool _isFetchingLocation = false;
  
  String _selectedCategory = 'car';
  String? _selectedModel;

  VehicleType get _vehicleTypeEnum {
    switch (_selectedCategory) {
      case 'bike':
        return VehicleType.bike;
      case 'ev':
        return VehicleType.ev;
      case 'car':
      default:
        return VehicleType.car;
    }
  }
  
  final Map<String, List<String>> _categorySpecializations = const {
    'car': [
      'Periodic Services',
      'Spa & Detailing',
      'Tyres & Wheel',
      'Batteries',
      'Brake & Suspension',
      'Clutch & Body',
      'Lights & Mirror',
      'Denting & Paint',
      'Custom Repair',
      'Car Inspection',
      'Insurance',
      'Electrical',
    ],
    'bike': [
      'Periodic Services',
      'Spa & Detailing',
      'Tyres & Wheel Care',
      'Batteries',
      'Brake & Suspension',
      'Clutch & Trans.',
      'Lights & Mirror',
      'Denting & Paint',
      'Custom Repair',
      'Accessories',
      'Electrical',
      'Body Parts',
    ],
    'ev': [
      'Periodic Services',
      'Tyres & Wheel Care',
      'Battery Diagnostics',
      'Brake Check',
      'Motor Service',
      'Lights & Wiring',
      'Body Panels',
      'Charging Fix',
      'Accessories',
    ],
  };

  final Map<String, Map<String, List<Map<String, String>>>> _vehiclePresetSubCategories = const {
    'car': {
      'Periodic Services': [
        {
          'name': 'Basic Service',
          'desc': 'Engine oil replacement, oil filter replacement, air filter cleaning, Coolant top up, Spark plug checking'
        },
        {
          'name': 'Standard Service',
          'desc': 'engine oil replacement, oil filter replacement, air filter replacement, Coolant topup, Heater/Spark plug checking, brake fluid topup. and more'
        },
        {
          'name': 'Comprehensive Service',
          'desc': 'engine oil replacement, oil filter replacement, air filter replacement, Coolant topup, Heater/Spark plug checking, brake fluid topup, throttle body cleaning, gear oil topup, Wash and more.'
        },
      ],
      'Spa & Detailing': [
        {
          'name': 'Premium top wash',
          'desc': 'Exterior top wash, Rinsing, tyre wash, Hand drying'
        },
        {
          'name': 'Deep all round Spa',
          'desc': 'interior Vacuum cleaning, dashboard polish, interior wet detailing, Pressure car wash, rubbing with compound, wax polish, machine rubbing, tyre dressing, Alloy polish'
        },
        {
          'name': 'Car wash & wax',
          'desc': 'Car wash, Interior Vacuuming, Dashboard & tyre polish, Body wax.'
        },
      ],
      'Tyres & Wheel': [
        {'name': 'Puncture repair', 'desc': ''},
        {'name': 'Tyre Replacement', 'desc': ''},
        {'name': 'Tube replacement', 'desc': ''},
        {'name': 'Wheel balancing', 'desc': ''},
        {'name': 'Wheel Alignment', 'desc': ''},
      ],
      'Tyres & Wheel Care': [
        {'name': 'Puncture repair', 'desc': ''},
        {'name': 'Tyre Replacement', 'desc': ''},
        {'name': 'Tube replacement', 'desc': ''},
        {'name': 'Wheel balancing', 'desc': ''},
        {'name': 'Wheel Alignment', 'desc': ''},
      ],
      'Batteries': [
        {'name': 'Battery replacement', 'desc': ''},
        {'name': 'Battery Charging issue', 'desc': ''},
        {'name': 'Battery jump start', 'desc': ''},
        {'name': 'Battery Health check', 'desc': ''},
      ],
      'Brake & Suspension': [
        {'name': 'Front brake pad replacement', 'desc': ''},
        {'name': 'Rear brake-shoe replacement', 'desc': ''},
        {'name': 'Front brake disk replacement', 'desc': ''},
        {'name': 'Caliper pin replacement', 'desc': ''},
        {'name': 'ABS issue diagnosis', 'desc': ''},
        {'name': 'Shock absorber replacement', 'desc': ''},
        {'name': 'Suspension repair', 'desc': ''},
        {'name': 'Steering repair', 'desc': ''},
      ],
      'Clutch & Body': [
        {'name': 'Clutch plate replacement', 'desc': ''},
        {'name': 'Clutch Set replacement', 'desc': ''},
        {'name': 'Flywheel replacement', 'desc': ''},
        {'name': 'Clutch Cable Replacement', 'desc': ''},
        {'name': 'Front bumper replacement', 'desc': ''},
        {'name': 'Rear bumper replacement', 'desc': ''},
        {'name': 'Bonnet replacement', 'desc': ''},
      ],
      'Lights & Mirror': [
        {'name': 'Front Headlight Replacement', 'desc': ''},
        {'name': 'Rear taillight Replacement', 'desc': ''},
        {'name': 'Fog light', 'desc': ''},
        {'name': 'Side mirror', 'desc': ''},
      ],
      'Denting & Paint': [
        {'name': 'Front bumper paint', 'desc': ''},
        {'name': 'Bonnet paint', 'desc': ''},
        {'name': 'Rear bumper paint', 'desc': ''},
        {'name': 'Boot paint', 'desc': ''},
        {'name': 'Full body denting paint', 'desc': ''},
        {'name': 'Fender paint', 'desc': ''},
        {'name': 'Door paint', 'desc': ''},
      ],
      'Custom Repair': [
        {'name': 'Full Engine Diagnosis', 'desc': ''},
        {'name': 'Engine overall Maintenance', 'desc': ''},
        {'name': 'Engine mount Replacement', 'desc': ''},
        {'name': 'Radiator Replacement', 'desc': ''},
        {'name': 'Fuel pump Replacement', 'desc': ''},
        {'name': 'Wheel bearing Replacement', 'desc': ''},
        {'name': 'Timing Chain Replacement', 'desc': ''},
        {'name': 'Silencer Replacement', 'desc': ''},
        {'name': 'Bonnet lock Replacement', 'desc': ''},
      ],
      'Car Inspection': [
        {'name': 'General Health Check', 'desc': ''},
        {'name': 'Pre-purchase inspection', 'desc': ''},
        {'name': 'Long journey inspection', 'desc': ''},
        {'name': 'Used car inspection', 'desc': ''},
      ],
      'Insurance': [
        {'name': 'Insurance Claim Assistance', 'desc': ''},
        {'name': 'Claim Documentation Support', 'desc': ''},
        {'name': 'Accident Claim Processing', 'desc': ''},
      ],
      'Electrical': [
        {'name': 'Alternator Replacement', 'desc': ''},
        {'name': 'Starter motor Replacement', 'desc': ''},
        {'name': 'Wiring Replacement [Full]', 'desc': ''},
        {'name': 'Horn Replacement', 'desc': ''},
        {'name': 'Headlight bulb Replacement', 'desc': ''},
        {'name': 'Headlight Assembly Replacement', 'desc': ''},
        {'name': 'Tail Light Replacement', 'desc': ''},
        {'name': 'Reverse Camera Installment', 'desc': ''},
        {'name': 'Speaker Replacement', 'desc': ''},
      ],
    },
    'bike': {
      'Periodic Services': [
        {
          'name': 'Basic Service',
          'desc': 'engine oil change, chain lubrication, brake check, tyre pressure check and 3 more.'
        },
        {
          'name': 'Standard Service',
          'desc': 'Basic Service +, Air filter clean + clutch & brake adjustment + Washing'
        },
        {
          'name': 'Comprehensive Service',
          'desc': 'engine oil change, chain lubrication, brake shoe change, Air filter change, Oil filter change, clutch & brake adjustment, Washing and 6 more.'
        },
      ],
      'Spa & Detailing': [
        {
          'name': 'Bike Wash',
          'desc': 'Exterior pressure wash and cleaning'
        },
        {
          'name': 'Foam Wash',
          'desc': 'Exterior wash + Foam wash'
        },
        {
          'name': 'Full Bike Detailing',
          'desc': 'Full wash + Polish + Coating + alloy cleaning.'
        },
      ],
      'Tyres & Wheel Care': [
        {'name': 'Puncher Repair', 'desc': ''},
        {'name': 'Tube Replacement', 'desc': ''},
        {'name': 'Tyre Replacement', 'desc': ''},
        {'name': 'Wheel Balancing', 'desc': ''},
      ],
      'Tyres & Wheel': [
        {'name': 'Puncher Repair', 'desc': ''},
        {'name': 'Tube Replacement', 'desc': ''},
        {'name': 'Tyre Replacement', 'desc': ''},
        {'name': 'Wheel Balancing', 'desc': ''},
      ],
      'Batteries': [
        {'name': 'Battery Replacement', 'desc': ''},
        {'name': 'Jump Start', 'desc': ''},
      ],
      'Brake & Suspension': [
        {'name': 'Front Brake Shoe Replacement', 'desc': ''},
        {'name': 'Rear Brake Shoe Replacement', 'desc': ''},
        {'name': 'Brake Pad Replacement', 'desc': ''},
      ],
      'Clutch & Trans.': [
        {'name': 'Clutch Plate Replacement', 'desc': ''},
        {'name': 'Clutch Cable Replacement', 'desc': ''},
        {'name': 'Chain Sprocket Replacement', 'desc': ''},
      ],
      'Lights & Mirror': [
        {'name': 'Head Light Replacement', 'desc': ''},
        {'name': 'Tail Light Replacement', 'desc': ''},
        {'name': 'Indicator Replacement', 'desc': ''},
        {'name': 'Left Mirror Replacement', 'desc': ''},
        {'name': 'Right Mirror Replacement', 'desc': ''},
      ],
      'Body Parts': [
        {'name': 'Mudguard Replacement', 'desc': ''},
        {'name': 'Side Panel Replacement', 'desc': ''},
        {'name': 'Footrest Replacement', 'desc': ''},
        {'name': 'Seat Replacement', 'desc': ''},
      ],
      'Electrical': [
        {'name': 'Wiring Replacement', 'desc': ''},
        {'name': 'Starter Motor Replacement', 'desc': ''},
        {'name': 'Ignition Switch Replacement', 'desc': ''},
        {'name': 'Main Switch Replacement', 'desc': ''},
      ],
      'Engine Repair': [
        {'name': 'Engine Rebuild (Complete)', 'desc': ''},
        {'name': 'Carburetor Cleaning', 'desc': ''},
      ],
      'Custom Repair': [
        {'name': 'Smoke from Exhaust', 'desc': ''},
        {'name': 'Pick up Issue', 'desc': ''},
        {'name': 'Engine Making Noise', 'desc': ''},
        {'name': 'Fuel Leakage', 'desc': ''},
        {'name': 'Visor Noise', 'desc': ''},
      ],
    },
    'ev': {
      'Periodic Services': [
        {
          'name': 'Basic EV Service',
          'desc': 'general inspection & cleaning of EV'
        },
        {
          'name': 'Standard EV Service',
          'desc': 'Basic service, Brake, tyre and electrical inspection'
        },
        {
          'name': 'Comprehensive EV Service',
          'desc': 'complet inspection of battery, motor, Controller, charging system'
        },
      ],
      'Tyres & Wheel Care': [
        {'name': 'Puncture Repair', 'desc': ''},
        {'name': 'Tyre Replacement', 'desc': ''},
        {'name': 'Wheel balancing', 'desc': ''},
        {'name': 'Wheel Alignment', 'desc': ''},
      ],
      'Battery Diagnostics': [
        {'name': 'Battery Health check', 'desc': ''},
        {'name': 'Battery Diagnostics', 'desc': ''},
        {'name': 'Battery Balancing', 'desc': ''},
        {'name': 'Battery Replacement', 'desc': ''},
      ],
      'Brake Check': [
        {'name': 'Brake Pad Replacement', 'desc': ''},
        {'name': 'Brake Disc Replacement', 'desc': ''},
        {'name': 'Brake fluid Replacement', 'desc': ''},
      ],
      'Motor Service': [
        {'name': 'Motor Diagnosis', 'desc': ''},
        {'name': 'Motor Cleaning', 'desc': ''},
        {'name': 'Motor Bearing Replacement', 'desc': ''},
        {'name': 'Motor Replacement', 'desc': ''},
      ],
      'Lights & Wiring': [
        {'name': 'Headlight Replacement', 'desc': ''},
        {'name': 'Tail light Replacement', 'desc': ''},
        {'name': 'Indicator Replacement', 'desc': ''},
        {'name': 'Full wiring Replacement', 'desc': ''},
        {'name': 'All Fuse Replacement', 'desc': ''},
      ],
      'Body Panels': [
        {'name': 'Front panel Replacement', 'desc': ''},
        {'name': 'Side panel Replacement', 'desc': ''},
        {'name': 'Rear panel Replacement', 'desc': ''},
        {'name': 'Mudguard Replacement', 'desc': ''},
        {'name': 'Mirror Replacement', 'desc': ''},
      ],
      'Charging Fix': [
        {'name': 'Charging Port Repair', 'desc': ''},
        {'name': 'Charging Issue', 'desc': ''},
        {'name': 'Charging Connector Replacement', 'desc': ''},
        {'name': 'Charger Diagnosis', 'desc': ''},
        {'name': 'Home Charger Installation', 'desc': ''},
      ],
      'Accessories': [
        {'name': 'Mobile holder installation', 'desc': ''},
        {'name': 'GPS installation', 'desc': ''},
        {'name': 'Security alarm installation', 'desc': ''},
        {'name': 'Footrest installation', 'desc': ''},
      ],
    },
  };

  final List<String> _selectedCategories = [];
  final Map<String, List<SubCategoryItem>> _subCategoriesMap = {};
  final Set<String> _expandedCategories = {};
  final List<Map<String, dynamic>> _customCategorySections = [];

  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _loadCurrentServiceProfile();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _expController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _customModelController.dispose();

    for (final list in _subCategoriesMap.values) {
      for (final sub in list) {
        sub.dispose();
      }
    }

    for (final customSec in _customCategorySections) {
      (customSec['name'] as TextEditingController?)?.dispose();
      final subs = customSec['subs'] as List<SubCategoryItem>? ?? [];
      for (final sub in subs) {
        sub.dispose();
      }
    }

    super.dispose();
  }

  Future<void> _loadCurrentServiceProfile() async {
    if (widget.existingPost != null) {
      final post = widget.existingPost!;
      _titleController.text = post.title;

      final rawExp = post.experience;
      final expMatch = RegExp(r'\d+').firstMatch(rawExp);
      _expController.text = expMatch != null ? expMatch.group(0)! : '';

      var rawBio = post.desc;
      if (rawBio.startsWith('"') && rawBio.endsWith('"')) {
        rawBio = rawBio.substring(1, rawBio.length - 1);
      }
      _bioController.text = rawBio;

      var rawLocation = post.location;
      if (rawLocation.startsWith('Works in ')) {
        rawLocation = rawLocation.substring(9);
      }
      _locationController.text = rawLocation;

      _selectedCategory = post.vehicleCategory;
      
      final appState = Provider.of<AppState>(context, listen: false);
      final models = appState.getModelsForType(_vehicleTypeEnum);
      final exists = models.any((m) => m.name == post.vehicleModel);
      if (exists) {
        _selectedModel = post.vehicleModel;
        _customModelController.clear();
      } else if (post.vehicleModel != null && post.vehicleModel!.isNotEmpty) {
        _selectedModel = '+ Add Custom Model';
        _customModelController.text = post.vehicleModel!;
      } else {
        _selectedModel = null;
        _customModelController.clear();
      }

      _selectedCategories.clear();
      _subCategoriesMap.clear();
      _expandedCategories.clear();
      _customCategorySections.clear();

      final predefined = _categorySpecializations[post.vehicleCategory] ?? [];

      if (post.specializationSubCategories.isNotEmpty) {
        post.specializationSubCategories.forEach((catName, subList) {
          final items = <SubCategoryItem>[];
          for (final subMap in subList) {
            final sName = subMap['name']?.toString() ?? '';
            final sPrice = subMap['price']?.toString() ?? '';
            final sDesc = subMap['desc']?.toString() ?? subMap['description']?.toString() ?? '';
            items.add(SubCategoryItem(name: sName, price: sPrice, description: sDesc));
          }

          if (predefined.contains(catName)) {
            _selectedCategories.add(catName);
            _subCategoriesMap[catName] = items;
            _expandedCategories.add(catName);
          } else {
            _customCategorySections.add({
              'name': TextEditingController(text: catName),
              'subs': items,
            });
          }
        });
      } else if (post.specializationRates.isNotEmpty) {
        final vehicleMap = _vehiclePresetSubCategories[post.vehicleCategory] ?? _vehiclePresetSubCategories['car']!;
        post.specializationRates.forEach((catName, rate) {
          final sDesc = vehicleMap[catName]?.firstWhere(
                (p) => p['name'] == catName,
                orElse: () => {},
              )['desc'] ??
              '';
          final item = SubCategoryItem(name: catName, price: rate.toString(), description: sDesc);
          if (predefined.contains(catName)) {
            _selectedCategories.add(catName);
            _subCategoriesMap[catName] = [item];
            _expandedCategories.add(catName);
          } else {
            _customCategorySections.add({
              'name': TextEditingController(text: catName),
              'subs': [item],
            });
          }
        });
      }

      _latitude = post.latitude;
      _longitude = post.longitude;
      return;
    }

    _titleController.clear();
    _expController.clear();
    _bioController.clear();
    _locationController.clear();
    _selectedCategory = 'car';
    _selectedModel = null;
    _customModelController.clear();
    _selectedCategories.clear();
    for (final list in _subCategoriesMap.values) {
      for (final sub in list) {
        sub.dispose();
      }
    }
    _subCategoriesMap.clear();
    _expandedCategories.clear();
    for (final customSec in _customCategorySections) {
      (customSec['name'] as TextEditingController?)?.dispose();
      final subs = customSec['subs'] as List<SubCategoryItem>? ?? [];
      for (final sub in subs) {
        sub.dispose();
      }
    }
    _customCategorySections.clear();
    _latitude = null;
    _longitude = null;

    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    setState(() => _isFetchingLocation = true);

    double? lat;
    double? lon;
    String resolvedAddress = '';

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        permission = await LocationHelper.requestLocationPermissionWithDisclosure(context);
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied.';
      }

      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      lat = position.latitude;
      lon = position.longitude;

      // Try native geocoding first
      bool geocodeSuccess = false;
      try {
        final placemarks = await placemarkFromCoordinates(lat, lon);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final List<String> areaParts = [];
          
          if (p.thoroughfare != null && p.thoroughfare!.isNotEmpty) {
            areaParts.add(p.thoroughfare!);
          } else if (p.street != null && p.street!.isNotEmpty) {
            areaParts.add(p.street!);
          }

          final localArea = p.subLocality ?? '';
          if (localArea.isNotEmpty && !areaParts.contains(localArea)) {
            areaParts.add(localArea);
          }

          final city = p.locality ?? p.administrativeArea ?? '';
          if (city.isNotEmpty && !areaParts.contains(city)) {
            areaParts.add(city);
          }

          resolvedAddress = areaParts.join(', ');
          geocodeSuccess = true;
        }
      } catch (nativeError) {
        debugPrint("Native geocoding failed: $nativeError. Falling back to Nominatim API.");
      }

      // Fallback to Nominatim HTTP API if native geocoding failed
      if (!geocodeSuccess) {
        try {
          final client = HttpClient();
          client.userAgent = 'MechTechApp/1.0';
          final request = await client.getUrl(Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1'
          ));
          final response = await request.close();
          
          if (response.statusCode == 200) {
            final content = await response.transform(utf8.decoder).join();
            final Map<String, dynamic> data = jsonDecode(content);
            final Map<String, dynamic>? address = data['address'] as Map<String, dynamic>?;

            if (address != null) {
              final road = address['road'] ?? '';
              final neighbourhood = address['neighbourhood'] ?? '';
              final suburb = address['suburb'] ?? '';
              final cityDistrict = address['city_district'] ?? '';
              final village = address['village'] ?? '';
              final town = address['town'] ?? '';
              final city = address['city'] ?? address['state'] ?? '';

              final List<String> areaParts = [];
              if (road.toString().isNotEmpty) areaParts.add(road.toString());
              
              final localArea = suburb.toString().isNotEmpty 
                  ? suburb.toString() 
                  : (neighbourhood.toString().isNotEmpty 
                      ? neighbourhood.toString() 
                      : (cityDistrict.toString().isNotEmpty 
                          ? cityDistrict.toString() 
                          : village.toString()));
              if (localArea.isNotEmpty && !areaParts.contains(localArea)) {
                areaParts.add(localArea);
              }
              
              final cityStr = city.toString().isNotEmpty ? city.toString() : town.toString();
              if (cityStr.isNotEmpty && !areaParts.contains(cityStr)) {
                areaParts.add(cityStr);
              }
              
              resolvedAddress = areaParts.join(', ');
              geocodeSuccess = true;
            }
          }
        } catch (_) {}
      }

      if (resolvedAddress.isEmpty) {
        resolvedAddress = 'Bengaluru (GPS Verified)';
      }
      
      setState(() {
        _locationController.text = resolvedAddress;
        _latitude = lat;
        _longitude = lon;
        _isFetchingLocation = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location resolved: $resolvedAddress'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF00E676),
          ),
        );
      }
    } catch (e) {
      debugPrint("Gps fetch error: $e");
      setState(() => _isFetchingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resolve GPS coordinates: $e. Please type your location manually.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  List<SubCategoryItem> _initializeSubCategoriesForCategory(String cat) {
    final vehicleMap = _vehiclePresetSubCategories[_selectedCategory] ?? _vehiclePresetSubCategories['car']!;
    final presets = vehicleMap[cat] ?? [];
    if (presets.isNotEmpty) {
      return presets
          .map((p) => SubCategoryItem(
                name: p['name'] ?? '',
                price: '',
                description: p['desc'] ?? '',
              ))
          .toList();
    }
    return [SubCategoryItem(name: '', price: '', description: '')];
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate: vehicle model must be selected
    if (_selectedModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a vehicle model'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final finalModelName = _selectedModel == '+ Add Custom Model'
        ? _customModelController.text.trim()
        : _selectedModel;

    // Validation for sub-categories
    final appState = context.read<AppState>();
    final uid = appState.user?.uid;
    if (uid == null) return;

    final Map<String, List<Map<String, dynamic>>> subCategoriesData = {};
    final Map<String, int> ratesMap = {};
    final List<String> allCategories = [];

    _subCategoriesMap.forEach((cat, subs) {
      final validSubsList = <Map<String, dynamic>>[];
      for (final sub in subs) {
        final sName = sub.nameController.text.trim();
        final sPrice = int.tryParse(sub.priceController.text.trim()) ?? 0;
        if (sName.isNotEmpty && sPrice > 0) {
          validSubsList.add({
            'name': sName,
            'price': sPrice,
            'desc': sub.descController.text.trim(),
          });
          ratesMap[sName] = sPrice;
          if (!allCategories.contains(sName)) allCategories.add(sName);
        }
      }
      if (validSubsList.isNotEmpty) {
        subCategoriesData[cat] = validSubsList;
        if (!allCategories.contains(cat)) allCategories.add(cat);
      }
    });

    for (final customSec in _customCategorySections) {
      final catName = (customSec['name'] as TextEditingController).text.trim();
      final subs = customSec['subs'] as List<SubCategoryItem>;
      final validSubsList = <Map<String, dynamic>>[];
      for (final sub in subs) {
        final sName = sub.nameController.text.trim();
        final sPrice = int.tryParse(sub.priceController.text.trim()) ?? 0;
        if (sName.isNotEmpty && sPrice > 0) {
          validSubsList.add({
            'name': sName,
            'price': sPrice,
            'desc': sub.descController.text.trim(),
          });
          ratesMap[sName] = sPrice;
          if (!allCategories.contains(sName)) allCategories.add(sName);
        }
      }
      if (validSubsList.isNotEmpty && catName.isNotEmpty) {
        subCategoriesData[catName] = validSubsList;
        if (!allCategories.contains(catName)) allCategories.add(catName);
      }
    }

    if (subCategoriesData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid rate (> 0) for at least one sub-service to save post'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final expStr = '${_expController.text.trim()} years of experience';
      final bioStr = '"${_bioController.text.trim()}"';
      final locStr = _locationController.text.trim();

      final postId = widget.existingPost?.id ?? 'JP-${DateTime.now().millisecondsSinceEpoch}';

      final postData = {
        'id': postId,
        'mechanicId': uid,
        'mechanicName': appState.currentCustomerName ?? 'Specialist Mechanic',
        'mechanicPhotoUrl': appState.currentCustomerPhotoUrl ?? '',
        'title': _titleController.text.trim(),
        'experience': expStr,
        'desc': bioStr,
        'location': locStr,
        'categories': allCategories,
        'specializationRates': ratesMap,
        'specializationSubCategories': subCategoriesData,
        'tags': const <String>[],
        'latitude': _latitude,
        'longitude': _longitude,
        'createdAt': widget.existingPost?.createdAt ?? FieldValue.serverTimestamp(),
        'vehicleCategory': _selectedCategory,
        'vehicleModel': finalModelName,
      };

      // Save only to global job_posts collection
      await FirebaseFirestore.instance
          .collection('job_posts')
          .doc(postId)
          .set(postData, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service profile updated successfully!'),
            backgroundColor: Color(0xFF00E676),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      debugPrint("Error saving service profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161426),
        title: Text(
          widget.existingPost != null ? 'Edit Job Post' : 'Create Job Post',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(
                      controller: _titleController,
                      label: 'Job Post Title',
                      hint: 'e.g. Brake & Oil Change Expert',
                      textCapitalization: TextCapitalization.words,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Job title is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    // Experience field (full width)
                    _buildTextField(
                      controller: _expController,
                      label: 'Experience (Years)',
                      hint: 'e.g. 6',
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        if (int.tryParse(val.trim()) == null) return 'Invalid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Bio/Description
                    _buildTextField(
                      controller: _bioController,
                      label: 'About You',
                      hint: 'Describe your expertise and service quality...',
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Please add a short bio';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Location with fetch button
                    Text(
                      'Service Location',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF161426),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF302B53)),
                            ),
                            child: TextFormField(
                              controller: _locationController,
                              textCapitalization: TextCapitalization.words,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: _isFetchingLocation ? 'Fetching location...' : 'Enter location or tap GPS',
                                hintStyle: GoogleFonts.inter(color: const Color(0xFF8B88A5)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: InputBorder.none,
                                suffixIcon: _isFetchingLocation
                                    ? const Padding(
                                        padding: EdgeInsets.all(12.0),
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF00B0FF),
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Location required';
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF00B0FF), width: 1.2),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _isFetchingLocation ? null : _fetchLocation,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.my_location_rounded,
                                      color: _isFetchingLocation
                                          ? const Color(0xFF00B0FF).withValues(alpha: 0.5)
                                          : const Color(0xFF00B0FF),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'GPS',
                                      style: GoogleFonts.outfit(
                                        color: _isFetchingLocation
                                            ? const Color(0xFF00B0FF).withValues(alpha: 0.5)
                                            : const Color(0xFF00B0FF),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Vehicle Category
                    Text(
                      'Vehicle Category',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildCategoryChip('car', 'Car', Icons.directions_car_rounded),
                        const SizedBox(width: 10),
                        _buildCategoryChip('bike', 'Bike', Icons.motorcycle_rounded),
                        const SizedBox(width: 10),
                        _buildCategoryChip('ev', 'EV', Icons.electric_car_rounded),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Vehicle Model Selection Dropdown
                    Text(
                      'Vehicle Model',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161426),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF302B53)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<String>(
                          dropdownColor: const Color(0xFF161426),
                          value: _selectedModel,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                          hint: Text(
                            'Select Vehicle Model',
                            style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 14),
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF00E676)),
                          items: [
                            ...appState.getModelsForType(_vehicleTypeEnum).map((model) {
                              return DropdownMenuItem<String>(
                                value: model.name,
                                child: Text(
                                  model.name,
                                  style: GoogleFonts.inter(color: Colors.white),
                                ),
                              );
                            }),
                            DropdownMenuItem<String>(
                              value: '+ Add Custom Model',
                              child: Text(
                                '+ Add Custom Model',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF00E676),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedModel = val;
                            });
                          },
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please select a vehicle model';
                            }
                            return null;
                          },
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    if (_selectedModel == '+ Add Custom Model') ...[
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _customModelController,
                        label: 'Custom Vehicle Model Name',
                        hint: 'Enter Vehicle Model Name',
                        textCapitalization: TextCapitalization.words,
                        validator: (val) {
                          if (_selectedModel == '+ Add Custom Model') {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter custom vehicle model name';
                            }
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Specialty Categories
                    Text(
                      'Specializations',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select the services you offer and set a charge for each.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8B88A5),
                        fontSize: 12,
                      ),
                    ),
                    Column(
                      children: [
                          ...(_categorySpecializations[_selectedCategory] ?? []).asMap().entries.map((entry) {
                            final index = entry.key;
                            final cat = entry.value;
                            final subItems = _subCategoriesMap[cat] ?? [];
                            final validSubItemsCount = subItems.where((sub) {
                              final p = int.tryParse(sub.priceController.text.trim()) ?? 0;
                              return sub.nameController.text.trim().isNotEmpty && p > 0;
                            }).length;
                            final isSelected = validSubItemsCount > 0;
                            final isExpanded = _expandedCategories.contains(cat);
                            final specs = (_categorySpecializations[_selectedCategory] ?? []);
                            final isLast = index == specs.length - 1 && _customCategorySections.isEmpty;

                            return Column(
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (isExpanded) {
                                        _expandedCategories.remove(cat);
                                      } else {
                                        _expandedCategories.add(cat);
                                        if (_subCategoriesMap[cat] == null || _subCategoriesMap[cat]!.isEmpty) {
                                          _subCategoriesMap[cat] = _initializeSubCategoriesForCategory(cat);
                                        }
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                                    child: Row(
                                      children: [
                                        // Checkbox / Select Button
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              if (isExpanded) {
                                                _expandedCategories.remove(cat);
                                              } else {
                                                _expandedCategories.add(cat);
                                                if (_subCategoriesMap[cat] == null || _subCategoriesMap[cat]!.isEmpty) {
                                                  _subCategoriesMap[cat] = _initializeSubCategoriesForCategory(cat);
                                                }
                                              }
                                            });
                                          },
                                          child: Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isSelected ? const Color(0xFF00E676) : Colors.transparent,
                                              border: Border.all(
                                                color: isSelected ? const Color(0xFF00E676) : const Color(0xFF535072),
                                                width: 1.8,
                                              ),
                                            ),
                                            child: isSelected
                                                ? const Icon(Icons.check, size: 14, color: Color(0xFF0D0B18))
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Category Name
                                        Expanded(
                                          child: Text(
                                            cat,
                                            style: GoogleFonts.outfit(
                                              color: isSelected ? Colors.white : const Color(0xFF8B88A5),
                                              fontSize: 14,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        // Count Badge
                                        if (validSubItemsCount > 0) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00E676).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
                                            ),
                                            child: Text(
                                              '$validSubItemsCount sub-service${validSubItemsCount == 1 ? '' : 's'}',
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFF00E676),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Icon(
                                          isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                          color: const Color(0xFF8B88A5),
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Expanded Sub-categories Area
                                if (isExpanded)
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(top: 4, bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D0B18),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFF302B53)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Sub-categories for $cat:',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF8B88A5),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        ...subItems.asMap().entries.map((subEntry) {
                                          final sub = subEntry.value;
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 10.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    // Sub-category Name Field
                                                    Expanded(
                                                      child: SizedBox(
                                                        height: 38,
                                                        child: TextField(
                                                          controller: sub.nameController,
                                                          textCapitalization: TextCapitalization.words,
                                                          style: GoogleFonts.inter(
                                                            color: Colors.white,
                                                            fontSize: 13,
                                                          ),
                                                          decoration: InputDecoration(
                                                            hintText: 'e.g. Side Mirror / Oil Change',
                                                            hintStyle: GoogleFonts.inter(
                                                              color: const Color(0xFF535072),
                                                              fontSize: 12,
                                                            ),
                                                            contentPadding: const EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                              vertical: 8,
                                                            ),
                                                            filled: true,
                                                            fillColor: const Color(0xFF161426),
                                                            border: OutlineInputBorder(
                                                              borderRadius: BorderRadius.circular(10),
                                                              borderSide: const BorderSide(color: Color(0xFF302B53)),
                                                            ),
                                                            enabledBorder: OutlineInputBorder(
                                                              borderRadius: BorderRadius.circular(10),
                                                              borderSide: const BorderSide(color: Color(0xFF302B53)),
                                                            ),
                                                            focusedBorder: OutlineInputBorder(
                                                              borderRadius: BorderRadius.circular(10),
                                                              borderSide: const BorderSide(color: Color(0xFF00E676)),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    // Sub-category Price Field
                                                    SizedBox(
                                                      width: 95,
                                                      height: 38,
                                                      child: TextField(
                                                        controller: sub.priceController,
                                                        keyboardType: TextInputType.number,
                                                        onChanged: (_) => setState(() {}),
                                                        style: GoogleFonts.inter(
                                                          color: Colors.white,
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                        decoration: InputDecoration(
                                                          hintText: '₹ Charge',
                                                          hintStyle: GoogleFonts.inter(
                                                            color: const Color(0xFF535072),
                                                            fontSize: 12,
                                                          ),
                                                          contentPadding: const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 8,
                                                          ),
                                                          filled: true,
                                                          fillColor: const Color(0xFF161426),
                                                          border: OutlineInputBorder(
                                                            borderRadius: BorderRadius.circular(10),
                                                            borderSide: const BorderSide(color: Color(0xFF302B53)),
                                                          ),
                                                          enabledBorder: OutlineInputBorder(
                                                            borderRadius: BorderRadius.circular(10),
                                                            borderSide: const BorderSide(color: Color(0xFF302B53)),
                                                          ),
                                                          focusedBorder: OutlineInputBorder(
                                                            borderRadius: BorderRadius.circular(10),
                                                            borderSide: const BorderSide(color: Color(0xFF00E676)),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (sub.descController.text.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Padding(
                                                    padding: const EdgeInsets.only(left: 4.0, right: 8.0),
                                                    child: Text(
                                                      '- ${sub.descController.text}',
                                                      style: GoogleFonts.inter(
                                                        color: const Color(0xFF8B88A5),
                                                        fontSize: 11,
                                                        height: 1.3,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          );
                                        }),
                                        const SizedBox(height: 4),
                                        // "+ Add Sub-Category" Button
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              subItems.add(SubCategoryItem(name: '', price: ''));
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(10),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00E676).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.add_rounded, color: Color(0xFF00E676), size: 16),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Add Sub-Category',
                                                  style: GoogleFonts.inter(
                                                    color: const Color(0xFF00E676),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                if (!isLast)
                                  const Divider(
                                    height: 1,
                                    color: Color(0xFF302B53),
                                    indent: 4,
                                    endIndent: 4,
                                  ),
                              ],
                            );
                          }),

                          // Custom Category Sections
                          ..._customCategorySections.asMap().entries.map((entry) {
                            final cIdx = entry.key;
                            final customSec = entry.value;
                            final catNameCtrl = customSec['name'] as TextEditingController;
                            final subs = customSec['subs'] as List<SubCategoryItem>;

                            return Column(
                              children: [
                                const Divider(height: 1, color: Color(0xFF302B53), indent: 4, endIndent: 4),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D0B18),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFF00B0FF).withValues(alpha: 0.4)),
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            // Delete custom category
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  catNameCtrl.dispose();
                                                  for (final sub in subs) sub.dispose();
                                                  _customCategorySections.removeAt(cIdx);
                                                });
                                              },
                                              child: Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: const Color(0xFF2A1A2E),
                                                  border: Border.all(
                                                    color: Colors.redAccent.withValues(alpha: 0.6),
                                                    width: 1.2,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  size: 13,
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            // Custom category name field
                                            Expanded(
                                              child: SizedBox(
                                                height: 38,
                                                child: TextField(
                                                  controller: catNameCtrl,
                                                  textCapitalization: TextCapitalization.words,
                                                  style: GoogleFonts.outfit(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  decoration: InputDecoration(
                                                    hintText: 'Custom Category Name',
                                                    hintStyle: GoogleFonts.inter(
                                                      color: const Color(0xFF535072),
                                                      fontSize: 13,
                                                    ),
                                                    contentPadding: const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                                    filled: true,
                                                    fillColor: const Color(0xFF161426),
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                      borderSide: const BorderSide(color: Color(0xFF302B53)),
                                                    ),
                                                    enabledBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                      borderSide: const BorderSide(color: Color(0xFF302B53)),
                                                    ),
                                                    focusedBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                      borderSide: const BorderSide(color: Color(0xFF00B0FF)),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        ...subs.asMap().entries.map((subEntry) {
                                          final sIdx = subEntry.key;
                                          final sub = subEntry.value;
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 8.0),
                                            child: Row(
                                              children: [
                                                GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      sub.dispose();
                                                      subs.removeAt(sIdx);
                                                    });
                                                  },
                                                  child: Container(
                                                    width: 22,
                                                    height: 22,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: const Color(0xFF2A1A2E),
                                                      border: Border.all(
                                                        color: Colors.redAccent.withValues(alpha: 0.6),
                                                        width: 1.2,
                                                      ),
                                                    ),
                                                    child: const Icon(
                                                      Icons.close,
                                                      size: 12,
                                                      color: Colors.redAccent,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: SizedBox(
                                                    height: 36,
                                                    child: TextField(
                                                      controller: sub.nameController,
                                                      textCapitalization: TextCapitalization.words,
                                                      style: GoogleFonts.inter(
                                                        color: Colors.white,
                                                        fontSize: 13,
                                                      ),
                                                      decoration: InputDecoration(
                                                        hintText: 'Sub-category name',
                                                        hintStyle: GoogleFonts.inter(
                                                          color: const Color(0xFF535072),
                                                          fontSize: 12,
                                                        ),
                                                        contentPadding: const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 8,
                                                        ),
                                                        filled: true,
                                                        fillColor: const Color(0xFF161426),
                                                        border: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(10),
                                                          borderSide: const BorderSide(color: Color(0xFF302B53)),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                SizedBox(
                                                  width: 90,
                                                  height: 36,
                                                  child: TextField(
                                                    controller: sub.priceController,
                                                    keyboardType: TextInputType.number,
                                                    style: GoogleFonts.inter(
                                                      color: Colors.white,
                                                      fontSize: 13,
                                                    ),
                                                    decoration: InputDecoration(
                                                      hintText: '₹ Charge',
                                                      hintStyle: GoogleFonts.inter(
                                                        color: const Color(0xFF535072),
                                                        fontSize: 12,
                                                      ),
                                                      contentPadding: const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 8,
                                                      ),
                                                      filled: true,
                                                      fillColor: const Color(0xFF161426),
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(10),
                                                        borderSide: const BorderSide(color: Color(0xFF302B53)),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                        const SizedBox(height: 4),
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              subs.add(SubCategoryItem(name: '', price: ''));
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(10),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00B0FF).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: const Color(0xFF00B0FF).withValues(alpha: 0.3)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.add_rounded, color: Color(0xFF00B0FF), size: 15),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Add Sub-Category',
                                                  style: GoogleFonts.inter(
                                                    color: const Color(0xFF00B0FF),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),

                          // + Add Custom Category Button
                          Column(
                            children: [
                              const Divider(height: 1, color: Color(0xFF302B53)),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _customCategorySections.add({
                                      'name': TextEditingController(),
                                      'subs': [SubCategoryItem(name: '', price: '')],
                                    });
                                  });
                                },
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.add_circle_outline_rounded,
                                        color: Color(0xFF00B0FF),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Add Custom Category',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF00B0FF),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),

                    // Save Button
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E676).withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _saveProfile,
                          child: Center(
                            child: Text(
                              'Save Changes',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF0D0B18),
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
              ),
            ),
    );
  }

  Widget _buildCategoryChip(String value, String label, IconData icon) {
    final isSelected = _selectedCategory == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedCategory != value) {
            setState(() {
              _selectedCategory = value;
              _selectedModel = null;
              _customModelController.clear();
              _selectedCategories.clear();
              _expandedCategories.clear();
              for (final list in _subCategoriesMap.values) {
                for (final item in list) {
                  item.dispose();
                }
              }
              _subCategoriesMap.clear();
              for (final sec in _customCategorySections) {
                (sec['name'] as TextEditingController).dispose();
                for (final sub in (sec['subs'] as List<SubCategoryItem>)) {
                  sub.dispose();
                }
              }
              _customCategorySections.clear();
            });
          }
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
                size: 24,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161426),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF302B53)),
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(color: const Color(0xFF8B88A5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }
}

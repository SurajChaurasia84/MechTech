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

class ManageServiceScreen extends StatefulWidget {
  final JobPost? existingPost;
  const ManageServiceScreen({super.key, this.existingPost});

  @override
  State<ManageServiceScreen> createState() => _ManageServiceScreenState();
}

class _ManageServiceScreenState extends State<ManageServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _rateController = TextEditingController();
  final _expController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();

  bool _isLoading = false;
  bool _isFetchingLocation = false;
  
  String _selectedCategory = 'car';
  
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

  final List<String> _selectedCategories = [];



  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _loadCurrentServiceProfile();
  }

  Future<void> _loadCurrentServiceProfile() async {
    if (widget.existingPost != null) {
      final post = widget.existingPost!;
      _titleController.text = post.title;
      
      final rawRate = post.rate;
      final rateMatch = RegExp(r'\d+').firstMatch(rawRate);
      _rateController.text = rateMatch != null ? rateMatch.group(0)! : '';

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
      _selectedCategories.clear();
      _selectedCategories.addAll(post.categories);

      _latitude = post.latitude;
      _longitude = post.longitude;
      return;
    }

    _titleController.clear();
    _rateController.clear();
    _expController.clear();
    _bioController.clear();
    _locationController.clear();
    _selectedCategory = 'car';
    _selectedCategories.clear();
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
        permission = await Geolocator.requestPermission();
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final appState = context.read<AppState>();
    final uid = appState.user?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);

    try {
      final rateStr = '₹${_rateController.text.trim()}';
      final expStr = '${_expController.text.trim()} years of experience';
      final bioStr = '"${_bioController.text.trim()}"';
      final locStr = _locationController.text.trim().isNotEmpty
          ? 'Works in ${_locationController.text.trim()}'
          : 'Works in Bengaluru';

      final postId = widget.existingPost?.id ?? 'JP-${DateTime.now().millisecondsSinceEpoch}';

      final postData = {
        'id': postId,
        'mechanicId': uid,
        'mechanicName': appState.currentCustomerName ?? 'Specialist Mechanic',
        'mechanicPhotoUrl': appState.currentCustomerPhotoUrl ?? '',
        'title': _titleController.text.trim(),
        'rate': rateStr,
        'experience': expStr,
        'desc': bioStr,
        'location': locStr,
        'categories': _selectedCategories,
        'tags': const <String>[],
        'latitude': _latitude,
        'longitude': _longitude,
        'createdAt': widget.existingPost?.createdAt ?? FieldValue.serverTimestamp(),
        'vehicleCategory': _selectedCategory,
      };

      // 1. Save to user's subcollection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('job_posts')
          .doc(postId)
          .set(postData, SetOptions(merge: true));

      // 2. Save to global root collection
      await FirebaseFirestore.instance
          .collection('job_posts')
          .doc(postId)
          .set(postData, SetOptions(merge: true));

      // 3. Fallback update primary user document
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'rate': rateStr,
        'experience': expStr,
        'desc': bioStr,
        'location': locStr,
        'categories': _selectedCategories,
        'tags': const <String>[],
        'latitude': _latitude,
        'longitude': _longitude,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service profile updated successfully!'),
            backgroundColor: Color(0xFF00E676),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
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
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
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
                    // Price & Experience row
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _rateController,
                            label: 'Service Charge (₹)',
                            hint: 'e.g. 500',
                            keyboardType: TextInputType.number,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Required';
                              if (int.tryParse(val.trim()) == null) return 'Invalid number';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Bio/Description
                    _buildTextField(
                      controller: _bioController,
                      label: 'About Me / Biography Quote',
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
                    const SizedBox(height: 24),

                    // Specialty Categories
                    Text(
                      'Specializations (Select all that apply)',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (_categorySpecializations[_selectedCategory] ?? []).map((cat) {
                        final isSelected = _selectedCategories.contains(cat);
                        return FilterChip(
                          label: Text(cat),
                          selected: isSelected,
                          selectedColor: const Color(0xFF08693F),
                          checkmarkColor: Colors.white,
                          backgroundColor: const Color(0xFF161426),
                          labelStyle: GoogleFonts.inter(
                            color: isSelected ? Colors.white : const Color(0xFF8B88A5),
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected ? const Color(0xFF00E676) : const Color(0xFF302B53),
                            ),
                          ),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedCategories.add(cat);
                              } else {
                                _selectedCategories.remove(cat);
                              }
                            });
                          },
                        );
                      }).toList(),
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
          setState(() {
            _selectedCategory = value;
            _selectedCategories.clear();
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

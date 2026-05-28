import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/app_state.dart';
import 'package:geolocator/geolocator.dart';
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
  
  final List<String> _availableCategories = ['Oil Change', 'Engine', 'Brakes', 'Tyre', 'Electrical'];
  final List<String> _selectedCategories = [];

  final List<String> _availableTags = ['#petrol', '#diesel', '#ev', '#4x4', '#suv'];
  final List<String> _selectedTags = [];

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

      _selectedCategories.clear();
      _selectedCategories.addAll(post.categories);

      _selectedTags.clear();
      _selectedTags.addAll(post.tags);

      _latitude = post.latitude;
      _longitude = post.longitude;
      return;
    }

    final appState = context.read<AppState>();
    final uid = appState.user?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        
        // Parse Rate (e.g. extract 40 from "₹40/hr")
        final rawRate = data['rate'] as String? ?? '';
        final rateMatch = RegExp(r'\d+').firstMatch(rawRate);
        _rateController.text = rateMatch != null ? rateMatch.group(0)! : '';

        // Parse Experience (e.g. extract 6 from "6 years of experience")
        final rawExp = data['experience'] as String? ?? '';
        final expMatch = RegExp(r'\d+').firstMatch(rawExp);
        _expController.text = expMatch != null ? expMatch.group(0)! : '';

        // Parse Bio (strip outer quotes if any)
        var rawBio = data['desc'] as String? ?? '';
        if (rawBio.startsWith('"') && rawBio.endsWith('"')) {
          rawBio = rawBio.substring(1, rawBio.length - 1);
        }
        _bioController.text = rawBio;

        // Parse Location
        var rawLocation = data['location'] as String? ?? '';
        if (rawLocation.startsWith('Works in ')) {
          rawLocation = rawLocation.substring(9);
        } else if (rawLocation.startsWith('Works with ')) {
          // Fallback parsing for existing mock descriptions
          final index = rawLocation.indexOf('in ');
          if (index != -1) {
            rawLocation = rawLocation.substring(index + 3);
          }
        }
        _locationController.text = rawLocation;

        if (rawLocation.trim().isEmpty) {
          _fetchLocation();
        }

        // Load Categories
        final cats = data['categories'] as List<dynamic>? ?? [];
        _selectedCategories.clear();
        _selectedCategories.addAll(cats.map((c) => c.toString()));

        // Load Tags
        final tags = data['tags'] as List<dynamic>? ?? [];
        _selectedTags.clear();
        _selectedTags.addAll(tags.map((t) => t.toString()));

        // Load Coordinates
        _latitude = (data['latitude'] as num?)?.toDouble();
        _longitude = (data['longitude'] as num?)?.toDouble();
      }
    } catch (e) {
      debugPrint("Error loading service profile: $e");
    } finally {
      setState(() => _isLoading = false);
    }
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

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 4),
      );

      lat = position.latitude;
      lon = position.longitude;

      // Reverse geocoding via Nominatim
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
            
            // 1. Add specific road/street if available
            if (road.toString().isNotEmpty) {
              areaParts.add(road.toString());
            }
            
            // 2. Add suburb/neighbourhood/district/village
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
            
            // 3. Add town or city
            final cityStr = city.toString().isNotEmpty ? city.toString() : town.toString();
            if (cityStr.isNotEmpty && !areaParts.contains(cityStr)) {
              areaParts.add(cityStr);
            }
            
            resolvedAddress = areaParts.join(', ');
          }
        }
      } catch (_) {}

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
      final rateStr = '₹${_rateController.text.trim()}/hr';
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
        'tags': _selectedTags,
        'latitude': _latitude,
        'longitude': _longitude,
        'createdAt': widget.existingPost?.createdAt ?? FieldValue.serverTimestamp(),
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
        'tags': _selectedTags,
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
                            label: 'Hourly Rate (₹)',
                            hint: 'e.g. 40',
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
                      children: _availableCategories.map((cat) {
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
                    const SizedBox(height: 24),

                    // Fuel Type Tags
                    Text(
                      'Vehicle Capability Tags',
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
                      children: _availableTags.map((tag) {
                        final isSelected = _selectedTags.contains(tag);
                        return FilterChip(
                          label: Text(tag),
                          selected: isSelected,
                          selectedColor: const Color(0xFF00B0FF).withOpacity(0.2),
                          checkmarkColor: const Color(0xFF00B0FF),
                          backgroundColor: const Color(0xFF161426),
                          labelStyle: GoogleFonts.inter(
                            color: isSelected ? const Color(0xFF00B0FF) : const Color(0xFF8B88A5),
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected ? const Color(0xFF00B0FF) : const Color(0xFF302B53),
                            ),
                          ),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTags.add(tag);
                              } else {
                                _selectedTags.remove(tag);
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
                            color: const Color(0xFF00E676).withOpacity(0.2),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
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

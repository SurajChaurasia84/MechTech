import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/app_state.dart';

class ManageServiceScreen extends StatefulWidget {
  const ManageServiceScreen({super.key});

  @override
  State<ManageServiceScreen> createState() => _ManageServiceScreenState();
}

class _ManageServiceScreenState extends State<ManageServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rateController = TextEditingController();
  final _expController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();

  bool _isLoading = false;
  bool _isFetchingLocation = false;
  
  final List<String> _availableCategories = ['Oil Change', 'Engine', 'Brakes', 'Tyre', 'Electrical', 'AC'];
  final List<String> _selectedCategories = [];

  final List<String> _availableTags = ['#petrol', '#diesel', '#ev', '#4x4', '#suv'];
  final List<String> _selectedTags = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentServiceProfile();
  }

  Future<void> _loadCurrentServiceProfile() async {
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

        // Load Categories
        final cats = data['categories'] as List<dynamic>? ?? [];
        _selectedCategories.clear();
        _selectedCategories.addAll(cats.map((c) => c.toString()));

        // Load Tags
        final tags = data['tags'] as List<dynamic>? ?? [];
        _selectedTags.clear();
        _selectedTags.addAll(tags.map((t) => t.toString()));
      }
    } catch (e) {
      debugPrint("Error loading service profile: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchLocation() async {
    setState(() => _isFetchingLocation = true);

    // Simulate geolocator location fetching
    await Future.delayed(const Duration(seconds: 1500 ~/ 1000));

    final mockLocations = [
      'Koramangala, Bengaluru',
      'Indiranagar, Bengaluru',
      'HSR Layout, Bengaluru',
      'Whitefield, Bengaluru',
      'Jayanagar, Bengaluru',
    ];
    mockLocations.shuffle();

    setState(() {
      _locationController.text = mockLocations.first;
      _isFetchingLocation = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location updated to: ${_locationController.text}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'rate': rateStr,
        'experience': expStr,
        'desc': bioStr,
        'location': locStr,
        'categories': _selectedCategories,
        'tags': _selectedTags,
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
          'Manage Service Profile',
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
                                hintText: 'Fetching location...',
                                hintStyle: GoogleFonts.inter(color: const Color(0xFF8B88A5)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: InputBorder.none,
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
                                child: _isFetchingLocation
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF00B0FF),
                                        ),
                                      )
                                    : Row(
                                        children: [
                                          const Icon(Icons.my_location_rounded, color: Color(0xFF00B0FF), size: 16),
                                          const SizedBox(width: 6),
                                          Text(
                                            'GPS',
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFF00B0FF),
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

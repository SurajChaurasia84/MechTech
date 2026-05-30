import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/app_state.dart';
import 'booking_summary_screen.dart';

class SelectMechanicScreen extends StatefulWidget {
  final String? specialtyFilter;
  final String? vehicleTypeFilter;

  const SelectMechanicScreen({
    super.key,
    this.specialtyFilter,
    this.vehicleTypeFilter,
  });

  @override
  State<SelectMechanicScreen> createState() => _SelectMechanicScreenState();
}

class _SelectMechanicScreenState extends State<SelectMechanicScreen> {
  bool _isLoadingMechanics = true;
  List<Map<String, dynamic>> _mechanics = [];
  Position? _currentPosition;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchMechanicsFromFirestore();
    _checkAndRequestLocationPermission();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAndRequestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      // Try last known location first
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        setState(() {
          _currentPosition = lastKnown;
        });
        _sortMechanicsByDistance();
      }

      // Try fresh GPS position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );
      setState(() {
        _currentPosition = position;
      });
      _sortMechanicsByDistance();
    } catch (e) {
      debugPrint("Error resolving location: $e");
    }
  }

  Future<void> _fetchMechanicsFromFirestore() async {
    setState(() => _isLoadingMechanics = true);
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('job_posts')
          .orderBy('createdAt', descending: true)
          .get();

      final List<Map<String, dynamic>> loadedMechs = [];
      for (final doc in querySnapshot.docs) {
        final data = doc.data();

        // Filter by vehicle type if provided
        if (widget.vehicleTypeFilter != null) {
          final postVehicleCategory = data['vehicleCategory'] as String? ?? 'car';
          if (postVehicleCategory.toLowerCase() != widget.vehicleTypeFilter!.toLowerCase()) {
            continue;
          }
        }

        // Filter by specialty if provided
        final categories = (data['categories'] as List<dynamic>?)?.map((c) => c.toString()).toList() ?? [];
        if (widget.specialtyFilter != null) {
          if (!categories.contains(widget.specialtyFilter)) {
            continue;
          }
        }

        final specializationRates = Map<String, int>.from(
          (data['specializationRates'] as Map<String, dynamic>? ?? {}).map(
            (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
          ),
        );

        loadedMechs.add({
          'id': doc.id,
          'mechanicId': data['mechanicId'] as String?,
          'title': data['title'] as String? ?? 'Specialist Mechanic',
          'name': data['mechanicName'] as String? ?? 'Specialist Mechanic',
          'experience': data['experience'] as String? ?? 'Experienced Mechanic',
          'rating': (data['rating'] as num?)?.toDouble() ?? 4.8,
          'rate': data['rate'] as String? ?? '₹30/hr',
          'location': data['location'] as String? ?? 'Bengaluru',
          'desc': data['desc'] as String? ?? '"Expert vehicle mechanic."',
          'photo': data['mechanicPhotoUrl'] as String? ?? 'https://images.unsplash.com/photo-1566492031773-4f4e44671857?q=80&w=150',
          'categories': categories,
          'tags': (data['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ?? [],
          'latitude': (data['latitude'] as num?)?.toDouble(),
          'longitude': (data['longitude'] as num?)?.toDouble(),
          'specializationRates': specializationRates,
        });
      }

      setState(() {
        _mechanics = loadedMechs;
        _isLoadingMechanics = false;
      });

      if (_currentPosition != null) {
        _sortMechanicsByDistance();
      }
    } catch (e) {
      debugPrint("Error fetching mechanics: $e");
      setState(() => _isLoadingMechanics = false);
    }
  }

  void _sortMechanicsByDistance() {
    if (_currentPosition == null) return;
    setState(() {
      _mechanics.sort((a, b) {
        final aLat = a['latitude'] as double?;
        final aLon = a['longitude'] as double?;
        final bLat = b['latitude'] as double?;
        final bLon = b['longitude'] as double?;

        if (aLat == null || aLon == null) return 1;
        if (bLat == null || bLon == null) return -1;

        final distA = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          aLat,
          aLon,
        );
        final distB = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          bLat,
          bLon,
        );

        return distA.compareTo(distB);
      });
    });
  }

  List<Map<String, dynamic>> _getFilteredMechanics() {
    if (_searchQuery.isEmpty) return _mechanics;
    return _mechanics.where((mech) {
      final nameMatch = (mech['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
      final titleMatch = (mech['title'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
      return nameMatch || titleMatch;
    }).toList();
  }

  String _getMechanicRateDisplay(Map<String, dynamic> mech, AppState appState) {
    final specRates = Map<String, int>.from(mech['specializationRates'] ?? {});
    
    // 1. If we have a specialty filter
    if (widget.specialtyFilter != null) {
      final rate = specRates[widget.specialtyFilter];
      if (rate != null && rate > 0) {
        return '₹$rate';
      }
    }
    
    // 2. If we have selected services in AppState
    final selected = appState.selectedServices;
    if (selected.isNotEmpty) {
      double totalRate = 0;
      bool foundAny = false;
      for (final service in selected) {
        final rate = specRates[service.category] ?? specRates[service.name];
        if (rate != null && rate > 0) {
          totalRate += rate;
          foundAny = true;
        } else {
          totalRate += service.price;
        }
      }
      if (foundAny) {
        return '₹${totalRate.toStringAsFixed(0)}';
      }
    }
    
    // 3. Fallback: range from specializationRates
    if (specRates.isNotEmpty) {
      final values = specRates.values.where((v) => v > 0).toList();
      if (values.isNotEmpty) {
        values.sort();
        if (values.first == values.last) {
          return '₹${values.first}';
        }
        return '₹${values.first} - ₹${values.last}';
      }
    }
    
    return '₹30/hr';
  }

  void _handleBookNow(Map<String, dynamic> mechanic) {
    final appState = context.read<AppState>();
    final currentUserId = appState.user?.uid;
    final mechanicId = mechanic['mechanicId'] as String?;

    if (mechanicId != null && mechanicId == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You cannot book your own service."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Apply mechanic rates to selected services in AppState
    final specRates = Map<String, int>.from(mechanic['specializationRates'] ?? {});
    appState.applyMechanicRates(specRates);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingSummaryScreen(
          mechanicId: mechanicId,
          mechanicName: mechanic['name'] as String?,
        ),
      ),
    );
  }

  void _showMechanicDetails(Map<String, dynamic> mech) {
    final appState = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161426),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final cats = (mech['categories'] as List<dynamic>?)?.map((e) => e.toString()).where((c) => c != 'All').toList() ?? [];
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mechanic Details',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundImage: NetworkImage(mech['photo']),
                    backgroundColor: const Color(0xFF0D0B18),
                    child: mech['photo'] == null
                        ? const Icon(Icons.person, color: Color(0xFF00E676), size: 36)
                        : null,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mech['name'],
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mech['title'],
                          style: GoogleFonts.inter(color: const Color(0xFF00E676), fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailRow('Experience', mech['experience']),
              _buildDetailRow('Base Rate', _getMechanicRateDisplay(mech, appState)),
              _buildDetailRow('Location', mech['location']),
              const SizedBox(height: 16),
              Text(
                'About Mechanic:',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                mech['desc'],
                style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 13, height: 1.4),
              ),
              if (cats.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Specialties:',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cats.map((cat) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF08693F).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      cat,
                      style: GoogleFonts.inter(color: const Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  )).toList(),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _handleBookNow(mech);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: const Color(0xFF0D0B18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Confirm & Book Now',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 13)),
          Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredMechanics();
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161426),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search mechanic by name...',
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 16),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              )
            : Text(
                widget.specialtyFilter != null
                    ? '${widget.specialtyFilter}'
                    : 'Select Mechanic',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, color: Colors.white),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = '';
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
      ),
      body: _isLoadingMechanics
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : filtered.isEmpty
              ? Center(
                  child: Text(
                    'No mechanics found.',
                    style: GoogleFonts.inter(color: const Color(0xFF8B88A5)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24.0),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final mech = filtered[index];
                    final distanceInMeters = _currentPosition != null && mech['latitude'] != null && mech['longitude'] != null
                        ? Geolocator.distanceBetween(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                            mech['latitude'] as double,
                            mech['longitude'] as double,
                          )
                        : null;
                    final distanceStr = distanceInMeters != null
                        ? (distanceInMeters >= 1000
                            ? '${(distanceInMeters / 1000).toStringAsFixed(1)} km away'
                            : '${distanceInMeters.toStringAsFixed(0)} m away')
                        : 'Location unknown';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161426),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF302B53).withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundImage: NetworkImage(mech['photo']),
                                  backgroundColor: const Color(0xFF0D0B18),
                                  child: mech['photo'] == null
                                      ? const Icon(Icons.person, color: Color(0xFF00E676), size: 24)
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              mech['name'],
                                              style: GoogleFonts.outfit(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00E676).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _getMechanicRateDisplay(mech, appState),
                                              style: GoogleFonts.outfit(
                                                color: const Color(0xFF00E676),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        mech['title'],
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF00E676),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 4,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.work_outline_rounded, color: Color(0xFF8B88A5), size: 13),
                                              const SizedBox(width: 4),
                                              Text(
                                                mech['experience'],
                                                style: GoogleFonts.inter(
                                                  color: const Color(0xFF8B88A5),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.location_on_outlined, color: Color(0xFF8B88A5), size: 13),
                                              const SizedBox(width: 4),
                                              Text(
                                                distanceStr,
                                                style: GoogleFonts.inter(
                                                  color: const Color(0xFF8B88A5),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => _showMechanicDetails(mech),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: const Color(0xFF0D0B18),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: const BorderSide(color: Color(0xFF302B53)),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: Text(
                                      'Show',
                                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _handleBookNow(mech),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00E676),
                                      foregroundColor: const Color(0xFF0D0B18),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      'Book',
                                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

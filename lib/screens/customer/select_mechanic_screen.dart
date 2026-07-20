import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/app_state.dart';
import 'mechanic_profile_details_screen.dart';
import '../../utils/location_helper.dart';

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
    try {
      context.read<AppState>().resetSelectionRatesToDefault();
    } catch (e) {
      debugPrint("Error resetting rates in SelectMechanicScreen dispose: $e");
    }
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
        if (!mounted) return;
        permission =
            await LocationHelper.requestLocationPermissionWithDisclosure(
              context,
            );
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

      if (!mounted) return;
      final List<Map<String, dynamic>> loadedMechs = [];
      final appState = Provider.of<AppState>(context, listen: false);
      final customerModel = appState.selectedVehicleModel;
      final customerType = appState.selectedVehicleType;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final postVehicleCategory = data['vehicleCategory'] as String? ?? 'car';

        // Filter by vehicle type if provided, else filter by customer type
        if (widget.vehicleTypeFilter != null) {
          if (postVehicleCategory.toLowerCase() !=
              widget.vehicleTypeFilter!.toLowerCase()) {
            continue;
          }
        } else if (customerType != null) {
          if (postVehicleCategory.toLowerCase() !=
              customerType.name.toLowerCase()) {
            continue;
          }
        }

        // Filter by vehicle model if the post specifies a model
        final postVehicleModel = data['vehicleModel'] as String?;
        if (postVehicleModel != null && postVehicleModel.isNotEmpty) {
          if (customerModel == null ||
              customerModel.toLowerCase() != postVehicleModel.toLowerCase()) {
            continue;
          }
        }

        // Filter by specialty if provided
        final categories =
            (data['categories'] as List<dynamic>?)
                ?.map((c) => c.toString())
                .toList() ??
            [];
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

        // Filter: Mechanic must offer and have a rate for ALL selected sub-categories/services
        if (appState.selectedServices.isNotEmpty) {
          bool offersAll = true;
          for (final service in appState.selectedServices) {
            final rate =
                specializationRates[service.name] ??
                specializationRates[service.category];
            if (rate == null || rate <= 0) {
              offersAll = false;
              break;
            }
          }
          if (!offersAll) {
            continue;
          }
        }

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
          'photo':
              data['mechanicPhotoUrl'] as String? ??
              'https://images.unsplash.com/photo-1566492031773-4f4e44671857?q=80&w=150',
          'categories': categories,
          'tags':
              (data['tags'] as List<dynamic>?)
                  ?.map((t) => t.toString())
                  .toList() ??
              [],
          'latitude': (data['latitude'] as num?)?.toDouble(),
          'longitude': (data['longitude'] as num?)?.toDouble(),
          'specializationRates': specializationRates,
          'vehicleCategory': postVehicleCategory,
          'vehicleModel': postVehicleModel,
        });
      }

      if (!mounted) return;
      setState(() {
        _mechanics = loadedMechs;
        _isLoadingMechanics = false;
      });

      if (_currentPosition != null) {
        _sortMechanicsByDistance();
      }
    } catch (e) {
      debugPrint("Error fetching mechanics: $e");
      if (mounted) {
        setState(() => _isLoadingMechanics = false);
      }
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
      final nameMatch = (mech['name'] as String).toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final titleMatch = (mech['title'] as String).toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      return nameMatch || titleMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredMechanics();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161426),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search mechanic by name...',
                  hintStyle: GoogleFonts.inter(
                    color: const Color(0xFF8B88A5),
                    fontSize: 16,
                  ),
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
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              color: Colors.white,
            ),
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
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            )
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
                final isLast = index == filtered.length - 1;
                final distanceInMeters =
                    _currentPosition != null &&
                        mech['latitude'] != null &&
                        mech['longitude'] != null
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
                    : '';

                var rawLoc = mech['location'] as String? ?? '';
                if (rawLoc.startsWith('Works in ')) {
                  rawLoc = rawLoc.substring(9);
                }
                final locLabel = rawLoc.isNotEmpty
                    ? (distanceStr.isNotEmpty
                          ? '$rawLoc • $distanceStr'
                          : rawLoc)
                    : (distanceStr.isNotEmpty
                          ? distanceStr
                          : 'Location unknown');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MechanicProfileDetailsScreen(
                              mechanic: mech,
                              currentPosition: _currentPosition,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.0,
                          vertical: 14.0,
                        ),
                        decoration: BoxDecoration(
                          border: isLast
                              ? null
                              : const Border(
                                  bottom: BorderSide(
                                    color: Color(0xFF302B53),
                                    width: 0.8,
                                  ),
                                ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundImage: NetworkImage(mech['photo']),
                              backgroundColor: const Color(0xFF161426),
                              child: mech['photo'] == null
                                  ? const Icon(
                                      Icons.person,
                                      color: Color(0xFF00E676),
                                      size: 24,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mech['title'] != null &&
                                            (mech['title'] as String).isNotEmpty
                                        ? '${mech['title']} by ${mech['name']}'
                                        : 'by ${mech['name']}',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        color: Color(0xFF8B88A5),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          locLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF8B88A5),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF535072),
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

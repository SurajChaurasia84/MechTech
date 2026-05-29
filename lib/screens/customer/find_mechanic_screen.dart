import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/service_model.dart';
import '../../services/app_state.dart';
import '../chat/chat_detail_screen.dart';
import 'booking_summary_screen.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/booking_utils.dart';

class FindMechanicScreen extends StatefulWidget {
  final String? initialFilter;

  const FindMechanicScreen({super.key, this.initialFilter});

  @override
  State<FindMechanicScreen> createState() => _FindMechanicScreenState();
}

class _FindMechanicScreenState extends State<FindMechanicScreen> {
  late String _selectedCategory;
  bool _isLoadingMechanics = true;

  final List<String> _categories = ['All'];

  List<Map<String, dynamic>> _mechanics = [];
  Position? _currentPosition;
  bool _isLocationServiceEnabled = true;
  bool _isLocationPermissionGranted = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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

  Widget _buildLocationPromptBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFF161426),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFFB300).withOpacity(0.6),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.location_off_rounded, color: Color(0xFFFFB300), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Get Best Nearby Mechanics',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Please turn on your location services and permissions to find the closest and best mechanics near you.',
              style: GoogleFonts.inter(
                color: const Color(0xFF8B88A5),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _checkAndRequestLocationPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                foregroundColor: const Color(0xFF0D0B18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'Enable Location Services',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialFilter ?? 'All';
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

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    setState(() {
      _isLocationServiceEnabled = serviceEnabled;
    });
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location services are disabled. Please enable them to find the closest mechanics.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _isLocationPermissionGranted = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are denied. We will show mechanics by rating instead.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _isLocationPermissionGranted = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied. Please enable them in settings to see nearby mechanics.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    } 

    setState(() {
      _isLocationPermissionGranted = true;
    });

    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        debugPrint("Last known location resolved: ${lastKnown.latitude}, ${lastKnown.longitude}");
        setState(() {
          _currentPosition = lastKnown;
        });
        _sortMechanicsByDistance();
      }
    } catch (e) {
      debugPrint("Error fetching last known location: $e");
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );
      debugPrint("User location: ${position.latitude}, ${position.longitude}");
      
      setState(() {
        _currentPosition = position;
      });

      _sortMechanicsByDistance();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.gps_fixed, color: Color(0xFF00E676), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location resolved! Showing nearest mechanics first.',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF161426),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error fetching location: $e");
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
      final Set<String> dynamicCategories = {'All'};

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final mechCats = (data['categories'] as List<dynamic>?)?.map((c) => c.toString()).toList() ?? [];

        dynamicCategories.addAll(mechCats);

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
          'categories': (data['categories'] as List<dynamic>?)?.map((c) => c.toString()).toList() ?? ['All'],
          'tags': (data['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ?? [],
          'latitude': (data['latitude'] as num?)?.toDouble(),
          'longitude': (data['longitude'] as num?)?.toDouble(),
        });
      }

      setState(() {
        _mechanics = loadedMechs;
        _categories.clear();
        _categories.addAll(dynamicCategories);
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

  List<Map<String, dynamic>> _getFilteredMechanics() {
    return _mechanics.where((mech) {
      final categoryMatch = _selectedCategory == 'All' ||
          (mech['categories'] as List<String>).contains(_selectedCategory);
      final nameMatch = _searchQuery.isEmpty ||
          (mech['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (mech['title'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
      return categoryMatch && nameMatch;
    }).toList();
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
    
    // Check if the customer already has vehicle type and services selected
    if (appState.selectedVehicleType != null && appState.selectedServices.isNotEmpty) {
      // Direct booking summary
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookingSummaryScreen(
            mechanicId: mechanic['mechanicId'] as String?,
            mechanicName: mechanic['name'] as String?,
          ),
        ),
      );
    } else {
      // Need selection - show quick booking sheet
      _showQuickBookingSheet(mechanic);
    }
  }

  void _showQuickBookingSheet(Map<String, dynamic> mechanic) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161426),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return QuickBookingSheet(mechanic: mechanic);
      },
    );
  }

  void _handleMessageMechanic(Map<String, dynamic> mech) async {
    final appState = context.read<AppState>();
    final currentUserId = appState.user?.uid;
    if (currentUserId == null) return;

    final mechanicId = mech['mechanicId'];
    if (mechanicId == null) return;

    if (mechanicId == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You cannot message yourself."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show loading spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E676)),
      ),
    );

    try {
      // 1. Abuse Prevention: Query global bookings to check if any booking exists
      final querySnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('customerId', isEqualTo: currentUserId)
          .where('mechanicId', isEqualTo: mechanicId)
          .limit(1)
          .get();

      // Dismiss loading spinner
      if (mounted) Navigator.of(context).pop();

      if (querySnapshot.docs.isEmpty) {
        // No booking exists! Show error dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                backgroundColor: const Color(0xFF161426),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFF302B53), width: 1.5),
                ),
                title: Text(
                  'Messaging Blocked',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                content: Text(
                  'To prevent spam and misuse, you can only message a mechanic once you have requested a service booking with them.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8B88A5),
                    height: 1.4,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Got it',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF00E676),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        }
        return;
      }

      // 2. Booking exists! Resolve roomId deterministically
      final roomId = currentUserId.compareTo(mechanicId) < 0
          ? '${currentUserId}_$mechanicId'
          : '${mechanicId}_$currentUserId';

      // 3. Ensure the chat room document exists in Firestore (create if missing)
      final chatDocRef = FirebaseFirestore.instance.collection('chats').doc(roomId);
      final chatDoc = await chatDocRef.get();
      if (!chatDoc.exists) {
        await chatDocRef.set({
          'id': roomId,
          'customerId': currentUserId,
          'customerName': appState.currentCustomerName ?? 'Customer',
          'customerPhotoUrl': appState.currentCustomerPhotoUrl ?? '',
          'mechanicId': mechanicId,
          'mechanicName': mech['name'] ?? 'Mechanic',
          'mechanicPhotoUrl': mech['photo'] ?? '',
          'lastMessage': '',
          'lastSenderId': '',
          'timestamp': FieldValue.serverTimestamp(),
          'unreadByCustomer': false,
          'unreadByMechanic': false,
        });
      }

      // 4. Open Chat Detail Screen
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              roomId: roomId,
              recipientId: mechanicId,
              recipientName: mech['name'] ?? 'Mechanic',
              recipientPhotoUrl: mech['photo'] ?? '',
              recipientRole: 'Mechanic Specialist',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // dismiss loading
      debugPrint("Error checking/creating chat: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredMechanics = _getFilteredMechanics();

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
            : null,
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
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Screen Title
                if (!_isSearching)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Find a\n',
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          TextSpan(
                            text: 'Mechanic',
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF00E676),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Categories Horizontal List (Image 2 style)
                if (!_isSearching) ...[
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10.0),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: const Color(0xFFFFB300), // Yellow-orange selected chip
                            disabledColor: const Color(0xFF161426),
                            backgroundColor: const Color(0xFF161426),
                            labelStyle: GoogleFonts.inter(
                              color: isSelected ? const Color(0xFF0D0B18) : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected ? const Color(0xFFFFB300) : const Color(0xFF302B53),
                                width: 1.2,
                              ),
                            ),
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = cat;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 16),
                ],

                // Mechanics Vertical List
                Expanded(
                  child: filteredMechanics.isEmpty
                      ? Center(
                          child: Text(
                            'No mechanics found matching filters.',
                            style: GoogleFonts.inter(color: const Color(0xFF8B88A5)),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          itemCount: filteredMechanics.length + ((!_isLocationServiceEnabled || !_isLocationPermissionGranted) ? 1 : 0),
                          itemBuilder: (context, index) {
                            if ((!_isLocationServiceEnabled || !_isLocationPermissionGranted) && index == 0) {
                              return _buildLocationPromptBanner();
                            }
                            final mechIndex = (!_isLocationServiceEnabled || !_isLocationPermissionGranted) ? index - 1 : index;
                            final mech = filteredMechanics[mechIndex];
                            return _buildMechanicCard(mech);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildMechanicCard(Map<String, dynamic> mech) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFF161426),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF08693F).withOpacity(0.4), // Premium green border glow
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mechanic Photo
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    mech['photo'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFF0D0B18),
                        child: const Icon(Icons.person, color: Color(0xFF00E676), size: 24),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name/Title row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              mech['title'] ?? mech['name'],
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF00E676),
                            size: 16,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'by ${mech['name']} • ${mech['experience']}',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF8B88A5),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Rating & Rate Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E676).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              mech['rate'],
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF00E676),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Builder(
                            builder: (context) {
                              final aLat = mech['latitude'] as double?;
                              final aLon = mech['longitude'] as double?;
                              if (_currentPosition != null && aLat != null && aLon != null) {
                                final distanceInMeters = Geolocator.distanceBetween(
                                  _currentPosition!.latitude,
                                  _currentPosition!.longitude,
                                  aLat,
                                  aLon,
                                );
                                String distanceStr = '';
                                if (distanceInMeters >= 1000) {
                                  distanceStr = '${(distanceInMeters / 1000).toStringAsFixed(1)} km away';
                                } else {
                                  distanceStr = '${distanceInMeters.toStringAsFixed(0)} m away';
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00B0FF).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      distanceStr,
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF00B0FF),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Location
            Row(
              children: [
                const Icon(Icons.home_outlined, color: Color(0xFF8B88A5), size: 14),
                const SizedBox(width: 6),
                Text(
                  mech['location'],
                  style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Quote description
            Text(
              mech['desc'],
              style: GoogleFonts.inter(
                color: const Color(0xFF8B88A5).withOpacity(0.8),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            // Categories & Tags Wrap
            Builder(
              builder: (context) {
                final cats = (mech['categories'] as List<dynamic>?)?.map((e) => e.toString()).where((c) => c != 'All').toList() ?? [];
                if (cats.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...cats.map((cat) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF08693F).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF00E676).withOpacity(0.6),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              cat,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF00E676),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF302B53)),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _handleMessageMechanic(mech),
                        child: Center(
                          child: Text(
                            'Message',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF161426),
                      border: Border.all(color: const Color(0xFF00E676), width: 1.2),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _handleBookNow(mech),
                        child: Center(
                          child: Text(
                            'Book Now',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF00E676),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class QuickBookingSheet extends StatefulWidget {
  final Map<String, dynamic> mechanic;

  const QuickBookingSheet({super.key, required this.mechanic});

  @override
  State<QuickBookingSheet> createState() => _QuickBookingSheetState();
}

class _QuickBookingSheetState extends State<QuickBookingSheet> {
  VehicleType _selectedType = VehicleType.car;
  String? _selectedModel;
  final List<ServiceItem> _selectedServices = [];
  bool _isBooking = false;

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final models = appState.getModelsForType(_selectedType);
    final mechanicCats = (widget.mechanic['categories'] as List<dynamic>?)?.map((c) => c.toString()).toList() ?? [];
    final services = appState.getServicesForType(_selectedType).where((s) {
      return mechanicCats.contains(s.category);
    }).toList();

    final subtotal = _selectedServices.fold<double>(0.0, (sum, item) => sum + item.price);
    final total = subtotal * 1.18; // plus 18% tax

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Book ${widget.mechanic['name']}',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Vehicle Type Selector Row
          Row(
            children: [
              _buildTypeButton('Car', VehicleType.car),
              const SizedBox(width: 8),
              _buildTypeButton('Bike', VehicleType.bike),
              const SizedBox(width: 8),
              _buildTypeButton('EV', VehicleType.ev),
            ],
          ),
          const SizedBox(height: 16),
          // Model Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0B18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF302B53)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                dropdownColor: const Color(0xFF161426),
                value: _selectedModel,
                hint: Text('Select Model', style: GoogleFonts.inter(color: const Color(0xFF8B88A5))),
                isExpanded: true,
                style: GoogleFonts.inter(color: Colors.white),
                items: models.map((model) {
                  return DropdownMenuItem<String>(
                    value: model.name,
                    child: Text(model.name),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedModel = val;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Services selector header
          Text(
            'Select Services:',
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          // Service list
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: services.length,
              itemBuilder: (context, index) {
                final s = services[index];
                final isSelected = _selectedServices.contains(s);
                return CheckboxListTile(
                  title: Text(s.name, style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                  subtitle: Text('₹${s.price.toStringAsFixed(0)}', style: GoogleFonts.inter(color: const Color(0xFF00E676))),
                  value: isSelected,
                  activeColor: const Color(0xFF00E676),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedServices.add(s);
                      } else {
                        _selectedServices.remove(s);
                      }
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Total Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total (inc. tax)', style: GoogleFonts.inter(color: const Color(0xFF8B88A5))),
              Text('₹${total.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 18, color: const Color(0xFF00E676), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          // Confirm booking button
          Container(
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: _selectedModel != null && _selectedServices.isNotEmpty && !_isBooking
                    ? [const Color(0xFF00E676), const Color(0xFF00B0FF)]
                    : [const Color(0xFF302B53), const Color(0xFF302B53)],
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _selectedModel != null && _selectedServices.isNotEmpty && !_isBooking
                    ? () async {
                        setState(() => _isBooking = true);
                        
                        // Call helper to check phone number and fetch location
                        final prepResult = await BookingUtils.prepareForBooking(context);
                        if (!prepResult.success) {
                          if (mounted) {
                            setState(() => _isBooking = false);
                          }
                          return;
                        }

                        // Setup the AppState selections so submitBooking registers it
                        appState.selectVehicleType(_selectedType);
                        appState.selectVehicleModel(_selectedModel!);
                        appState.clearServiceSelection();
                        for (final s in _selectedServices) {
                          appState.toggleServiceSelection(s);
                        }

                        // Submit booking
                        final booking = await appState.submitBooking(
                          latitude: prepResult.position?.latitude,
                          longitude: prepResult.position?.longitude,
                          bookingLocation: prepResult.address,
                          mechanicId: widget.mechanic['mechanicId'] as String?,
                          mechanicName: widget.mechanic['name'] as String?,
                        );
                        
                        if (mounted) {
                          Navigator.of(context).pop(); // close sheet
                          if (booking != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Booking ${booking.id} created successfully with ${widget.mechanic['name']}!'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: const Color(0xFF00E676),
                              ),
                            );
                          }
                        }
                      }
                    : null,
                child: Center(
                  child: _isBooking
                      ? const CircularProgressIndicator(color: Color(0xFF0D0B18))
                      : Text(
                          'Confirm & Book Now',
                          style: GoogleFonts.outfit(color: const Color(0xFF0D0B18), fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String title, VehicleType type) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            _selectedModel = null;
            _selectedServices.clear();
          });
        },
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF08693F) : const Color(0xFF0D0B18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF00E676) : const Color(0xFF302B53),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: GoogleFonts.outfit(
              color: isSelected ? Colors.white : const Color(0xFF8B88A5),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

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
import 'widgets/vehicle_selection_sheet.dart';

class FindMechanicScreen extends StatefulWidget {
  final String? initialFilter;
  final String? initialVehicleCategory;

  const FindMechanicScreen({
    super.key,
    this.initialFilter,
    this.initialVehicleCategory,
  });

  @override
  State<FindMechanicScreen> createState() => _FindMechanicScreenState();
}

class _FindMechanicScreenState extends State<FindMechanicScreen> with TickerProviderStateMixin {
  late String _selectedCategory;
  late String _selectedVehicleCategory;
  late TabController _tabController;
  bool _isLoadingMechanics = true;

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
            color: const Color(0xFFFFB300).withValues(alpha: 0.6),
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
    _selectedVehicleCategory = widget.initialVehicleCategory ?? 'car';
    final initialIndex = _selectedVehicleCategory == 'bike' ? 1 : (_selectedVehicleCategory == 'ev' ? 2 : 0);
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          final types = ['car', 'bike', 'ev'];
          _selectedVehicleCategory = types[_tabController.index];
          _selectedCategory = 'All';
        });
      }
    });
    _selectedCategory = widget.initialFilter ?? 'All';
    _fetchMechanicsFromFirestore();
    _checkAndRequestLocationPermission();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
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
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF161426),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF302B53), width: 1),
            ),
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
          'categories': (data['categories'] as List<dynamic>?)?.map((c) => c.toString()).toList() ?? ['All'],
          'tags': (data['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ?? [],
          'latitude': (data['latitude'] as num?)?.toDouble(),
          'longitude': (data['longitude'] as num?)?.toDouble(),
          'specializationRates': specializationRates,
          'vehicleCategory': data['vehicleCategory'] as String? ?? 'car',
          'vehicleModel': data['vehicleModel'] as String?,
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

  List<String> _getCategoryChips() {
    final appState = context.read<AppState>();
    final customerModel = appState.selectedVehicleModel;
    final customerType = appState.selectedVehicleType;
    final Set<String> cats = {'All'};
    for (final mech in _mechanics) {
      final vehicleMatch = (mech['vehicleCategory'] as String? ?? 'car').toLowerCase() == _selectedVehicleCategory.toLowerCase();
      
      final postVehicleModel = mech['vehicleModel'] as String?;
      bool modelMatch = true;
      if (postVehicleModel != null && postVehicleModel.isNotEmpty) {
        if (customerType != null && customerType.name.toLowerCase() == _selectedVehicleCategory.toLowerCase()) {
          if (customerModel == null || customerModel.toLowerCase() != postVehicleModel.toLowerCase()) {
            modelMatch = false;
          }
        } else {
          modelMatch = false;
        }
      }

      if (vehicleMatch && modelMatch) {
        final mechCats = (mech['categories'] as List<dynamic>?)?.map((c) => c.toString()) ?? [];
        cats.addAll(mechCats);
      }
    }
    return cats.toList();
  }

  Widget _buildMechanicsList(String vehicleCategory) {
    final appState = context.read<AppState>();
    final customerModel = appState.selectedVehicleModel;
    final customerType = appState.selectedVehicleType;

    // Filter the mechanics list for this category specifically
    final filtered = _mechanics.where((mech) {
      final vehicleMatch = (mech['vehicleCategory'] as String? ?? 'car').toLowerCase() == vehicleCategory.toLowerCase();
      
      final postVehicleModel = mech['vehicleModel'] as String?;
      bool modelMatch = true;
      if (postVehicleModel != null && postVehicleModel.isNotEmpty) {
        if (customerType != null && customerType.name.toLowerCase() == vehicleCategory.toLowerCase()) {
          if (customerModel == null || customerModel.toLowerCase() != postVehicleModel.toLowerCase()) {
            modelMatch = false;
          }
        } else {
          modelMatch = false;
        }
      }

      final categoryMatch = _selectedCategory == 'All' ||
          (mech['categories'] as List<String>).contains(_selectedCategory);
      final nameMatch = _searchQuery.isEmpty ||
          (mech['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (mech['title'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
      return vehicleMatch && modelMatch && categoryMatch && nameMatch;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No mechanics found matching filters.',
          style: GoogleFonts.inter(color: const Color(0xFF8B88A5)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: filtered.length + ((!_isLocationServiceEnabled || !_isLocationPermissionGranted) ? 1 : 0),
      itemBuilder: (context, index) {
        if ((!_isLocationServiceEnabled || !_isLocationPermissionGranted) && index == 0) {
          return _buildLocationPromptBanner();
        }
        final mechIndex = (!_isLocationServiceEnabled || !_isLocationPermissionGranted) ? index - 1 : index;
        final mech = filtered[mechIndex];
        return _buildMechanicCard(mech);
      },
    );
  }

  String _getMechanicRateDisplay(Map<String, dynamic> mech, AppState appState) {
    final specRates = Map<String, int>.from(mech['specializationRates'] ?? {});
    
    // 1. If we have a category selected that is not 'All'
    if (_selectedCategory != 'All') {
      final rate = specRates[_selectedCategory];
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
    
    // Check if the customer already has vehicle type and services selected
    if (appState.selectedVehicleType != null && appState.selectedServices.isNotEmpty) {
      // Apply mechanic rates to selected services in AppState
      final specRates = Map<String, int>.from(mechanic['specializationRates'] ?? {});
      appState.applyMechanicRates(specRates);

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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: true,
          builder: (context, scrollController) {
            return QuickBookingSheet(
              mechanic: mechanic,
              scrollController: scrollController,
            );
          },
        );
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
    context.watch<AppState>();

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
          if (!_isSearching)
            Consumer<AppState>(
              builder: (context, appState, _) {
                final hasVehicle = appState.selectedVehicleModel != null;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Center(
                    child: GestureDetector(
                      onTap: () => showVehicleSelectionBottomSheet(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: hasVehicle ? const Color(0xFF00E676).withValues(alpha: 0.12) : const Color(0xFF302B53),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: hasVehicle ? const Color(0xFF00E676) : const Color(0xFF8B88A5),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasVehicle
                                  ? (appState.selectedVehicleType == VehicleType.car
                                      ? Icons.directions_car_rounded
                                      : appState.selectedVehicleType == VehicleType.bike
                                          ? Icons.motorcycle_rounded
                                          : Icons.electric_car_rounded)
                                  : Icons.add_rounded,
                              size: 14,
                              color: hasVehicle ? const Color(0xFF00E676) : const Color(0xFF8B88A5),
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: Text(
                                hasVehicle ? appState.selectedVehicleModel! : 'Add Vehicle',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: hasVehicle ? Colors.white : const Color(0xFF8B88A5),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
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

                // Vehicle selection TabBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF161426),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: const Color(0xFF00E676),
                      indicatorWeight: 3,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                      unselectedLabelStyle: GoogleFonts.outfit(fontSize: 14),
                      labelColor: const Color(0xFF00E676),
                      unselectedLabelColor: const Color(0xFF8B88A5),
                      tabs: const [
                        Tab(text: '🚗  Car'),
                        Tab(text: '🏍  Bike'),
                        Tab(text: '⚡  EV'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Categories Horizontal List
                if (!_isSearching) ...[
                  Builder(
                    builder: (context) {
                      final chips = _getCategoryChips();
                      
                      // Safety check: if _selectedCategory is not in chips, reset it to 'All'
                      if (!chips.contains(_selectedCategory)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              _selectedCategory = 'All';
                            });
                          }
                        });
                      }

                      return SizedBox(
                        height: 40,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: chips.length,
                          itemBuilder: (context, index) {
                            final cat = chips[index];
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
                      );
                    }
                  ),
                  const SizedBox(height: 16),
                ],

                // Mechanics Vertical List with TabBarView for swiping
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMechanicsList('car'),
                      _buildMechanicsList('bike'),
                      _buildMechanicsList('ev'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMechanicCard(Map<String, dynamic> mech) {
    final appState = context.read<AppState>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFF161426),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF08693F).withValues(alpha: 0.4), // Premium green border glow
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
                                      color: const Color(0xFF00B0FF).withValues(alpha: 0.12),
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
                color: const Color(0xFF8B88A5).withValues(alpha: 0.8),
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
                              color: const Color(0xFF08693F).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF00E676).withValues(alpha: 0.6),
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
  final ScrollController? scrollController;

  const QuickBookingSheet({
    super.key,
    required this.mechanic,
    this.scrollController,
  });

  @override
  State<QuickBookingSheet> createState() => _QuickBookingSheetState();
}

class _QuickBookingSheetState extends State<QuickBookingSheet> {
  VehicleType _selectedType = VehicleType.car;
  String? _selectedModel;
  final List<ServiceItem> _selectedServices = [];
  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    if (appState.selectedVehicleType != null) {
      _selectedType = appState.selectedVehicleType!;
      _selectedModel = appState.selectedVehicleModel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final models = appState.getModelsForType(_selectedType);
    final services = appState.getServicesForType(_selectedType);

    final total = _selectedServices.fold<double>(0.0, (prev, item) {
      final specRates = Map<String, int>.from(widget.mechanic['specializationRates'] ?? {});
      final customRate = specRates[item.category] ?? specRates[item.name];
      final price = (customRate != null && customRate > 0) ? customRate.toDouble() : item.price;
      return prev + price;
    });

    final hasPreselectedVehicle = appState.selectedVehicleType != null && appState.selectedVehicleModel != null;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161426),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
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
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                if (hasPreselectedVehicle) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0B18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF302B53),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedType == VehicleType.car
                              ? Icons.directions_car_outlined
                              : _selectedType == VehicleType.bike
                                  ? Icons.two_wheeler_outlined
                                  : Icons.electric_car_outlined,
                          color: const Color(0xFF00E676),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vehicle Details',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF8B88A5),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$_selectedModel (${_selectedType.displayName})',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
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
                ],
                // Services selector header
                Text(
                  'Select Services:',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                ...services.map((s) {
                  final isSelected = _selectedServices.contains(s);
                  final specRates = Map<String, int>.from(widget.mechanic['specializationRates'] ?? {});
                  final customRate = specRates[s.category] ?? specRates[s.name];
                  final priceToShow = (customRate != null && customRate > 0) ? customRate.toDouble() : s.price;
                  return CheckboxListTile(
                    title: Text(s.name, style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                    subtitle: Text('₹${priceToShow.toStringAsFixed(0)}', style: GoogleFonts.inter(color: const Color(0xFF00E676))),
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
                }),
              ],
            ),
          ),
          // Fixed Bottom Bar
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Color(0xFF302B53),
                  width: 1.2,
                ),
              ),
            ),
            padding: const EdgeInsets.only(left: 24, right: 24, top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Total Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Amount', style: GoogleFonts.inter(color: const Color(0xFF8B88A5))),
                    Text('₹${total.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 18, color: const Color(0xFF00E676), fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
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

                              // Apply mechanic rates to selected services in AppState
                              final specRates = Map<String, int>.from(widget.mechanic['specializationRates'] ?? {});
                              appState.applyMechanicRates(specRates);

                              // Submit booking
                              final booking = await appState.submitBooking(
                                latitude: prepResult.position?.latitude,
                                longitude: prepResult.position?.longitude,
                                bookingLocation: prepResult.address,
                                mechanicId: widget.mechanic['mechanicId'] as String?,
                                mechanicName: widget.mechanic['name'] as String?,
                              );
                              
                              if (context.mounted) {
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

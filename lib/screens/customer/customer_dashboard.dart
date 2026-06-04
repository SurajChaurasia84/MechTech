import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/app_state.dart';
import '../../models/service_model.dart';
import 'tabs/home_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/messages_tab.dart';
import 'widgets/vehicle_selection_sheet.dart';
import '../../utils/location_helper.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  // Vehicle type tabs
  late TabController _vehicleTabController;

  // Location state
  static String? _cachedLocation;
  String _locationLabel = 'Fetching location...';
  bool _locationFetching = true;

  @override
  void initState() {
    super.initState();
    _vehicleTabController = TabController(length: 3, vsync: this);
    if (_cachedLocation != null) {
      _locationLabel = _cachedLocation!;
      _locationFetching = false;
    } else {
      _fetchLocation();
    }
  }

  @override
  void dispose() {
    _vehicleTabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        permission = await LocationHelper.requestLocationPermissionWithDisclosure(context);
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _locationLabel = 'Location unavailable';
            _locationFetching = false;
          });
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );

      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final locality = p.subLocality?.isNotEmpty == true ? p.subLocality! : p.locality ?? '';
        final city = p.locality ?? p.administrativeArea ?? '';
        final label = locality.isNotEmpty && locality != city
            ? '$locality, $city'
            : city.isNotEmpty ? city : 'Location found';
        _cachedLocation = label;
        if (mounted) setState(() { _locationLabel = label; _locationFetching = false; });
      } else {
        if (mounted) setState(() { _locationLabel = 'Location unavailable'; _locationFetching = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _locationLabel = 'Location unavailable'; _locationFetching = false; });
    }
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0: return 'MechTech';
      case 1: return 'Booking History';
      case 2: return 'Messages';
      case 3: return 'My Profile';
      default: return 'MechTech';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0B18),
        appBar: AppBar(
          backgroundColor: const Color(0xFF161426),
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              if (_currentIndex == 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset('assets/icon.png', height: 28, width: 28),
                ),
                const SizedBox(width: 10),
              ],
              if (_currentIndex == 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getAppBarTitle(),
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_locationFetching)
                          const SizedBox(
                            width: 9, height: 9,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF00E676)),
                          )
                        else
                          const Icon(Icons.location_on_rounded, size: 11, color: Color(0xFF00E676)),
                        const SizedBox(width: 3),
                        Text(
                          _locationLabel,
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8B88A5), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Text(
                  _getAppBarTitle(),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
                ),
            ],
          ),
          actions: [
            if (_currentIndex == 0)
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
            if (_currentIndex == 3)
              IconButton(
                icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
                tooltip: 'Switch Profile Role',
                onPressed: () => _showRoleSwitchDialog(context),
              ),
          ],
          // Car / Bike / EV tabs — only on Home tab
          bottom: _currentIndex == 0
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(44),
                  child: Container(
                    color: const Color(0xFF161426),
                    child: TabBar(
                      controller: _vehicleTabController,
                      indicatorColor: const Color(0xFF00E676),
                      indicatorWeight: 3,
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
                )
              : null,
        ),
        body: _currentIndex == 0
            ? TabBarView(
                controller: _vehicleTabController,
                children: const [
                  HomeTab(vehicleType: 'car'),
                  HomeTab(vehicleType: 'bike'),
                  HomeTab(vehicleType: 'ev'),
                ],
              )
            : _buildBody(),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: const Color(0xFF302B53).withValues(alpha: 0.6), width: 1.5),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            backgroundColor: const Color(0xFF161426),
            selectedItemColor: const Color(0xFF00E676),
            unselectedItemColor: const Color(0xFF8B88A5),
            selectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
            type: BottomNavigationBarType.fixed,
            onTap: (index) => setState(() => _currentIndex = index),
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.assignment_turned_in_outlined),
                activeIcon: Icon(Icons.assignment_turned_in_rounded),
                label: 'Bookings',
              ),
              BottomNavigationBarItem(
                icon: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .where('customerId', isEqualTo: appState.user?.uid)
                      .where('unreadByCustomer', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.forum_outlined),
                        if (hasUnread)
                          Positioned(
                            top: -2, right: -2,
                            child: Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                activeIcon: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .where('customerId', isEqualTo: appState.user?.uid)
                      .where('unreadByCustomer', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.forum_rounded),
                        if (hasUnread)
                          Positioned(
                            top: -2, right: -2,
                            child: Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                label: 'Messages',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 1: return const HistoryTab();
      case 2: return const MessagesTab();
      case 3: return const ProfileTab();
      default: return const SizedBox.shrink();
    }
  }

  void _showRoleSwitchDialog(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    final currentRole = appState.userRole ?? 'customer';
    String tempSelectedRole = currentRole;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161426),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF302B53), width: 1.5),
              ),
              title: Text('Switch Profile Role',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Select which panel role you want to switch to:',
                      style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 13)),
                  const SizedBox(height: 16),
                  _roleCard(context, setDialogState, tempSelectedRole, 'customer',
                      Icons.person_rounded, const Color(0xFF00E676),
                      'Customer Panel', 'Book services and find mechanics.',
                      (r) => tempSelectedRole = r),
                  const SizedBox(height: 12),
                  _roleCard(context, setDialogState, tempSelectedRole, 'mechanic',
                      Icons.build_rounded, const Color(0xFF00B0FF),
                      'Mechanic Panel', 'Manage bookings and view earnings.',
                      (r) => tempSelectedRole = r),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontWeight: FontWeight.w600)),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    if (tempSelectedRole != currentRole) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Row(children: [
                          SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                          SizedBox(width: 12),
                          Text('Switching roles...'),
                        ]),
                        behavior: SnackBarBehavior.floating,
                      ));
                      await appState.switchUserRole(tempSelectedRole);
                      if (context.mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    }
                  },
                  child: Text('Switch',
                      style: GoogleFonts.inter(
                        color: tempSelectedRole == 'customer' ? const Color(0xFF00E676) : const Color(0xFF00B0FF),
                        fontWeight: FontWeight.bold,
                      )),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _roleCard(
    BuildContext ctx,
    StateSetter setDialogState,
    String selectedRole,
    String roleKey,
    IconData icon,
    Color color,
    String title,
    String subtitle,
    Function(String) onSelect,
  ) {
    final isSelected = selectedRole == roleKey;
    return InkWell(
      onTap: () => setDialogState(() => onSelect(roleKey)),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : const Color(0xFF0D0B18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : const Color(0xFF302B53), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : const Color(0xFF8B88A5)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                  Text(subtitle, style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 11)),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle_rounded, color: color),
          ],
        ),
      ),
    );
  }
}

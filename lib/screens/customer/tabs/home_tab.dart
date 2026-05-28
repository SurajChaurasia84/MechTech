import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/service_model.dart';
import '../../../services/app_state.dart';
import '../service_selection_screen.dart';
import '../find_mechanic_screen.dart';
import '../booking_summary_screen.dart';
import 'history_tab.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String? _selectedModel;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _popularServices = [];
  final List<Map<String, dynamic>> _serviceCategories = [];

  final Map<String, Map<String, dynamic>> _categoryMeta = {
    'Oil Change': {
      'icon': Icons.opacity_rounded,
      'desc': 'Engine oil and filter change',
      'price': '₹199/hr',
      'image': 'https://images.unsplash.com/photo-1607860108855-64acf2078ed9?q=80&w=300'
    },
    'Tyre': {
      'icon': Icons.adjust_rounded,
      'desc': 'Rotation, balancing & alignment',
      'price': '₹199/hr',
      'image': 'https://images.unsplash.com/photo-1486006920555-c77dce18193b?q=80&w=300'
    },
    'Electrical': {
      'icon': Icons.bolt_rounded,
      'desc': 'Battery and wiring diagnostics',
      'price': '₹399/hr',
      'image': 'https://images.unsplash.com/photo-1517524206127-48bbd363f3d7?q=80&w=300'
    },
    'Engine': {
      'icon': Icons.handyman_rounded,
      'desc': 'Diagnostics and engine overhauls',
      'price': '₹499/hr',
      'image': 'https://images.unsplash.com/photo-1517524206127-48bbd363f3d7?q=80&w=300'
    },
    'Brakes': {
      'icon': Icons.album_rounded,
      'desc': 'Pads, rotors, and fluid flush',
      'price': '₹349/hr',
      'image': 'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?q=80&w=300'
    },
    'AC': {
      'icon': Icons.ac_unit_rounded,
      'desc': 'AC gas refill and servicing',
      'price': '₹299/hr',
      'image': 'https://images.unsplash.com/photo-1607860108855-64acf2078ed9?q=80&w=300'
    },
  };

  @override
  void initState() {
    super.initState();
    _loadActiveCategories();
  }

  Future<void> _loadActiveCategories() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'mechanic')
          .get();

      final Set<String> activeCats = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final cats = (data['categories'] as List<dynamic>?)?.map((c) => c.toString()).toList() ?? [];
        activeCats.addAll(cats.where((c) => c != 'All'));
      }

      final List<Map<String, dynamic>> newPopular = [];
      final List<Map<String, dynamic>> newCategories = [];

      for (final cat in activeCats) {
        final meta = _categoryMeta[cat] ?? {
          'icon': Icons.handyman_rounded,
          'desc': 'General vehicle service',
          'price': '₹299/hr',
          'image': 'https://images.unsplash.com/photo-1607860108855-64acf2078ed9?q=80&w=300'
        };

        newPopular.add({
          'name': cat,
          'icon': meta['icon'] as IconData,
          'filter': cat,
        });

        newCategories.add({
          'name': cat,
          'price': meta['price'] as String,
          'desc': meta['desc'] as String,
          'image': meta['image'] as String,
          'filter': cat,
        });
      }

      setState(() {
        _popularServices.clear();
        _popularServices.addAll(newPopular);
        _serviceCategories.clear();
        _serviceCategories.addAll(newCategories);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading categories: $e");
      setState(() => _isLoading = false);
    }
  }

  Widget _buildNoServicesPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161426),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF302B53), width: 1.2),
      ),
      child: Column(
        children: [
          const Icon(Icons.build_circle_outlined, color: Color(0xFF00B0FF), size: 40),
          const SizedBox(height: 12),
          Text(
            'No Registered Mechanics Yet',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Active mechanics have not registered any specialties. Switch to the Mechanic panel to register a service profile and post specialties!',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFF8B88A5),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final selectedType = appState.selectedVehicleType;
    final models = selectedType != null ? appState.getModelsForType(selectedType) : <VehicleModel>[];

    Color accentColor = const Color(0xFF00E676);
    if (selectedType == VehicleType.car) {
      accentColor = const Color(0xFF9C27B0);
    } else if (selectedType == VehicleType.ev) {
      accentColor = const Color(0xFF00B0FF);
    }

    final customerName = appState.currentCustomerName ?? 'Valued Customer';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 16.0, bottom: 100.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161426),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF302B53).withOpacity(0.5),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF0D0B18),
                    backgroundImage: appState.currentCustomerPhotoUrl != null
                        ? NetworkImage(appState.currentCustomerPhotoUrl!)
                        : null,
                    child: appState.currentCustomerPhotoUrl == null
                        ? const Icon(Icons.person, color: Color(0xFF00E676), size: 24)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF8B88A5),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          customerName,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Popular Services Section (Image 3 mockup style)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Popular Services',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FindMechanicScreen()),
                    );
                  },
                  child: Text(
                    'View all',
                    style: GoogleFonts.inter(color: const Color(0xFF00E676), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Horizontal list of services
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
                : _popularServices.isEmpty
                    ? _buildNoServicesPlaceholder()
                    : SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _popularServices.length,
                          itemBuilder: (context, index) {
                            final service = _popularServices[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 16.0),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => FindMechanicScreen(initialFilter: service['filter']),
                                    ),
                                  );
                                },
                                child: Column(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF161426),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFF302B53), width: 1.2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          )
                                        ],
                                      ),
                                      child: Icon(service['icon'], color: const Color(0xFF00E676), size: 24),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      service['name'],
                                      style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
            const SizedBox(height: 16),

            // Service Categories Grid (Image 3 mockup style)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Service Categories',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FindMechanicScreen()),
                    );
                  },
                  child: Text(
                    'View all',
                    style: GoogleFonts.inter(color: const Color(0xFF00E676), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Grid of categories
            _isLoading || _serviceCategories.isEmpty
                ? const SizedBox.shrink()
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: _serviceCategories.length,
                    itemBuilder: (context, index) {
                      final cat = _serviceCategories[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FindMechanicScreen(initialFilter: cat['filter']),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF161426),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF302B53), width: 1.2),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Image part
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      cat['image'],
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: const Color(0xFF0D0B18),
                                          child: const Icon(Icons.image_outlined, color: Color(0xFF8B88A5)),
                                        );
                                      },
                                    ),
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00E676),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          cat['price'],
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFF0D0B18),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              // Label part
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cat['name'],
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      cat['desc'],
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: const Color(0xFF8B88A5),
                                      ),
                                    )
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 36),

            // Vehicle Selector Card (Preserved functional booking selector)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161426),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF302B53), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Quick Vehicle Booking',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select vehicle details to view tailored services chart',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF8B88A5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Vehicle category cards row
                  Row(
                    children: [
                      Expanded(
                        child: _buildCategoryCard(
                          title: 'Car',
                          icon: Icons.directions_car_outlined,
                          type: VehicleType.car,
                          isSelected: selectedType == VehicleType.car,
                          activeColor: const Color(0xFF9C27B0),
                          appState: appState,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCategoryCard(
                          title: 'Bike',
                          icon: Icons.two_wheeler_outlined,
                          type: VehicleType.bike,
                          isSelected: selectedType == VehicleType.bike,
                          activeColor: const Color(0xFF00E676),
                          appState: appState,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCategoryCard(
                          title: 'EV',
                          icon: Icons.electric_car_outlined,
                          type: VehicleType.ev,
                          isSelected: selectedType == VehicleType.ev,
                          activeColor: const Color(0xFF00B0FF),
                          appState: appState,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Model dropdown
                  if (selectedType != null) ...[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0B18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedModel != null ? accentColor : const Color(0xFF302B53),
                          width: 1.5,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          dropdownColor: const Color(0xFF161426),
                          borderRadius: BorderRadius.circular(16),
                          value: _selectedModel,
                          hint: Row(
                            children: [
                              Icon(
                                selectedType == VehicleType.car
                                    ? Icons.directions_car_outlined
                                    : selectedType == VehicleType.bike
                                        ? Icons.two_wheeler_outlined
                                        : Icons.electric_car_outlined,
                                color: const Color(0xFF8B88A5),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Select Model',
                                style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 13),
                              ),
                            ],
                          ),
                          icon: Icon(Icons.keyboard_arrow_down_rounded, color: accentColor),
                          isExpanded: true,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
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
                            if (val != null) {
                              appState.selectVehicleModel(val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Explore Button
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _selectedModel != null ? 1.0 : 0.4,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: _selectedModel != null
                                ? [const Color(0xFF00E676), const Color(0xFF00B0FF)]
                                : [const Color(0xFF302B53), const Color(0xFF302B53)],
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _selectedModel != null
                                ? () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const ServiceSelectionScreen(),
                                      ),
                                    );
                                  }
                                : null,
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Explore Services Chart',
                                    style: GoogleFonts.outfit(
                                      color: _selectedModel != null ? const Color(0xFF0D0B18) : const Color(0xFF8B88A5),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 16,
                                    color: _selectedModel != null ? const Color(0xFF0D0B18) : const Color(0xFF8B88A5),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Recent Bookings Header with "View All" Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Bookings',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to history tab/screen
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BookingHistoryScreen(),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        'View All',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF00E676),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Color(0xFF00E676),
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Preview card of the most recent bookings (max 3)
            if (appState.bookings.isNotEmpty) ...[
              ...appState.bookings.reversed.take(3).map((booking) {
                Color statusColor = const Color(0xFFFF9100);
                if (booking.status == 'In Progress') {
                  statusColor = const Color(0xFF00B0FF);
                } else if (booking.status == 'Completed') {
                  statusColor = const Color(0xFF00E676);
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161426),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF302B53).withOpacity(0.8),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              booking.id,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: statusColor.withOpacity(0.5), width: 1),
                              ),
                              child: Text(
                                booking.status,
                                style: GoogleFonts.inter(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              booking.vehicleType == VehicleType.car
                                  ? Icons.directions_car_outlined
                                  : booking.vehicleType == VehicleType.bike
                                      ? Icons.two_wheeler_outlined
                                      : Icons.electric_car_outlined,
                              color: const Color(0xFF8B88A5),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              booking.vehicleModel,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '₹${(booking.totalAmount * 1.18).toStringAsFixed(0)}',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF00E676),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No booking history',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8B88A5),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required IconData icon,
    required VehicleType type,
    required bool isSelected,
    required Color activeColor,
    required AppState appState,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedModel = null;
        });
        appState.selectVehicleType(type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.15) : const Color(0xFF0D0B18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFF302B53),
            width: isSelected ? 2.0 : 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? activeColor : const Color(0xFF8B88A5),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF8B88A5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

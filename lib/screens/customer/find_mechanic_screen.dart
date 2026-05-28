import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/service_model.dart';
import '../../services/app_state.dart';
import '../chat/chat_detail_screen.dart';
import 'booking_summary_screen.dart';

class FindMechanicScreen extends StatefulWidget {
  final String? initialFilter;

  const FindMechanicScreen({super.key, this.initialFilter});

  @override
  State<FindMechanicScreen> createState() => _FindMechanicScreenState();
}

class _FindMechanicScreenState extends State<FindMechanicScreen> {
  late String _selectedCategory;
  String _selectedTag = 'All';
  bool _isLoadingMechanics = true;

  final List<String> _categories = ['All', 'Oil Change', 'Engine', 'Brakes', 'Tyre'];
  final List<String> _tags = ['All', '#petrol', '#diesel', '#ev', '#4x4', '#suv'];

  List<Map<String, dynamic>> _mechanics = [];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialFilter ?? 'All';
    _fetchMechanicsFromFirestore();
  }

  Future<void> _fetchMechanicsFromFirestore() async {
    setState(() => _isLoadingMechanics = true);
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'mechanic')
          .get();

      if (querySnapshot.docs.isEmpty) {
        // Seed default mechanics to Firestore so data is present!
        final List<Map<String, dynamic>> defaultMechs = [
          {
            'uid': 'mech_arjun_mock',
            'name': 'Arjun Mehta',
            'email': 'arjun.mehta@example.com',
            'role': 'mechanic',
            'experience': '6 years of experience',
            'rating': 4.7,
            'rate': '₹40/hr',
            'location': 'Works in Koramangala, Bengaluru',
            'desc': '"I specialise in engine overhauls and diagnostics. Own full toolkit and spares."',
            'photoUrl': 'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?q=80&w=150',
            'categories': ['Engine', 'Oil Change'],
            'tags': ['#petrol', '#diesel', '#suv'],
          },
          {
            'uid': 'mech_priya_mock',
            'name': 'Priya Nair',
            'email': 'priya.nair@example.com',
            'role': 'mechanic',
            'experience': '4 years of experience',
            'rating': 4.5,
            'rate': '₹35/hr',
            'location': 'Works in Indiranagar, Bengaluru',
            'desc': '"Electrical systems and AC diagnosis are my forte. Fast turnaround guaranteed."',
            'photoUrl': 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?q=80&w=150',
            'categories': ['Electrical', 'Tyre'],
            'tags': ['#ev', '#petrol'],
          },
          {
            'uid': 'mech_rohan_mock',
            'name': 'Rohan Sharma',
            'email': 'rohan.sharma@example.com',
            'role': 'mechanic',
            'experience': '5 years of experience',
            'rating': 4.8,
            'rate': '₹30/hr',
            'location': 'Works in HSR Layout, Bengaluru',
            'desc': '"Brake service and general maintenance. Premium brake pad installations and adjustments."',
            'photoUrl': 'https://images.unsplash.com/photo-1566492031773-4f4e44671857?q=80&w=150',
            'categories': ['Brakes', 'Oil Change'],
            'tags': ['#petrol', '#diesel', '#4x4'],
          },
          {
            'uid': 'mech_vikram_mock',
            'name': 'Vikram Singh',
            'email': 'vikram.singh@example.com',
            'role': 'mechanic',
            'experience': '7 years of experience',
            'rating': 4.9,
            'rate': '₹45/hr',
            'location': 'Works in Whitefield, Bengaluru',
            'desc': '"Tire alignment, balancing, and puncture repair. Available for fast roadside assistance."',
            'photoUrl': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=150',
            'categories': ['Tyre', 'Brakes'],
            'tags': ['#suv', '#ev'],
          },
        ];

        for (final mech in defaultMechs) {
          await FirebaseFirestore.instance.collection('users').doc(mech['uid']).set(mech);
        }
        
        // Fetch again after seeding
        _fetchMechanicsFromFirestore();
        return;
      }

      final List<Map<String, dynamic>> loadedMechs = [];
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        loadedMechs.add({
          'id': doc.id,
          'name': data['name'] as String? ?? 'Specialist Mechanic',
          'experience': data['experience'] as String? ?? 'Experienced Mechanic',
          'rating': (data['rating'] as num?)?.toDouble() ?? 4.8,
          'rate': data['rate'] as String? ?? '₹30/hr',
          'location': data['location'] as String? ?? 'Bengaluru',
          'desc': data['desc'] as String? ?? '"Expert vehicle mechanic."',
          'photo': data['photoUrl'] as String? ?? 'https://images.unsplash.com/photo-1566492031773-4f4e44671857?q=80&w=150',
          'categories': (data['categories'] as List<dynamic>?)?.map((c) => c.toString()).toList() ?? ['All'],
          'tags': (data['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ?? [],
        });
      }

      setState(() {
        _mechanics = loadedMechs;
        _isLoadingMechanics = false;
      });
    } catch (e) {
      debugPrint("Error fetching mechanics: $e");
      setState(() => _isLoadingMechanics = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredMechanics() {
    return _mechanics.where((mech) {
      final categoryMatch = _selectedCategory == 'All' ||
          (mech['categories'] as List<String>).contains(_selectedCategory);
      final tagMatch = _selectedTag == 'All' ||
          (mech['tags'] as List<String>).contains(_selectedTag);
      return categoryMatch && tagMatch;
    }).toList();
  }

  void _handleBookNow(Map<String, dynamic> mechanic) {
    final appState = context.read<AppState>();
    
    // Check if the customer already has vehicle type and services selected
    if (appState.selectedVehicleType != null && appState.selectedServices.isNotEmpty) {
      // Direct booking summary
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const BookingSummaryScreen(),
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

    final mechanicId = mech['id'];
    if (mechanicId == null) return;

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
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Advanced filters opening...')),
              );
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

                // Tags Horizontal List (Image 2 style)
                SizedBox(
                  height: 34,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _tags.length,
                    itemBuilder: (context, index) {
                      final tag = _tags[index];
                      final isSelected = _selectedTag == tag;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedTag = tag;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF161426) : const Color(0xFF161426).withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF00E676) : const Color(0xFF302B53).withOpacity(0.6),
                                width: 1.2,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: GoogleFonts.inter(
                                color: isSelected ? const Color(0xFF00E676) : const Color(0xFF8B88A5),
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

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
                          itemCount: filteredMechanics.length,
                          itemBuilder: (context, index) {
                            final mech = filteredMechanics[index];
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
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    mech['photo'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFF0D0B18),
                        child: const Icon(Icons.person, color: Color(0xFF00E676), size: 36),
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
                      // Name row
                      Row(
                        children: [
                          Text(
                            mech['name'],
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
                        mech['experience'],
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
                              color: const Color(0xFF08693F),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  mech['rating'].toString(),
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
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
            const SizedBox(height: 16),
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
    final services = appState.getServicesForType(_selectedType);

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
                        
                        // Setup the AppState selections so submitBooking registers it
                        appState.selectVehicleType(_selectedType);
                        appState.selectVehicleModel(_selectedModel!);
                        appState.clearServiceSelection();
                        for (final s in _selectedServices) {
                          appState.toggleServiceSelection(s);
                        }

                        // Submit booking
                        final booking = await appState.submitBooking();
                        
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

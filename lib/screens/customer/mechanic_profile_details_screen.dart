import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../models/service_model.dart';
import '../chat/chat_detail_screen.dart';
import 'booking_summary_screen.dart';

class MechanicProfileDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> mechanic;
  final Position? currentPosition;
  final String? initialCategory;

  const MechanicProfileDetailsScreen({
    super.key,
    required this.mechanic,
    this.currentPosition,
    this.initialCategory,
  });

  @override
  State<MechanicProfileDetailsScreen> createState() => _MechanicProfileDetailsScreenState();
}

class _MechanicProfileDetailsScreenState extends State<MechanicProfileDetailsScreen> {
  bool _isLoadingPosts = true;
  String _selectedCategory = 'All';
  final List<ServiceItem> _selectedServices = [];

  Map<String, List<ServiceItem>> _categorizedServices = {};
  List<String> _categoriesList = ['All'];

  @override
  void initState() {
    super.initState();
    _fetchMechanicJobPosts();
  }

  Future<void> _fetchMechanicJobPosts() async {
    final mechanicId = widget.mechanic['mechanicId'] as String?;
    if (mechanicId == null || mechanicId.isEmpty) {
      _processPosts([]);
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('job_posts')
          .where('mechanicId', isEqualTo: mechanicId)
          .get();

      final List<Map<String, dynamic>> loaded = [];
      for (final doc in snap.docs) {
        final data = doc.data();
        loaded.add({
          'id': doc.id,
          'mechanicId': data['mechanicId'],
          'title': data['title'] ?? 'Specialist Mechanic',
          'mechanicName': data['mechanicName'] ?? widget.mechanic['name'],
          'photo': data['mechanicPhotoUrl'] ?? widget.mechanic['photo'],
          'vehicleCategory': (data['vehicleCategory'] as String? ?? 'car').toLowerCase(),
          'vehicleModel': data['vehicleModel'] as String?,
          'categories': (data['categories'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
          'specializationRates': Map<String, int>.from(data['specializationRates'] ?? {}),
          'specializationSubCategories': Map<String, List<dynamic>>.from(data['specializationSubCategories'] ?? {}),
          'desc': data['desc'] ?? '',
          'experience': data['experience'] ?? '',
          'location': data['location'] ?? '',
        });
      }

      _processPosts(loaded);
    } catch (e) {
      debugPrint("Error fetching mechanic job posts: $e");
      _processPosts([]);
    }
  }

  static const Set<String> _knownMainCategories = {
    'Periodic Services',
    'Periodic Service',
    'Spa & Detailing',
    'Tyres & Wheel',
    'Tyres & Wheel Care',
    'Batteries',
    'Battery Diagnostics',
    'Brake & Suspension',
    'Brake Check',
    'Brakes',
    'Brake Services',
    'Clutch & Body',
    'Clutch & Trans.',
    'Motor Service',
    'Lights & Mirror',
    'Lights & Wiring',
    'Denting & Paint',
    'Custom Repair',
    'Charging Fix',
    'Car Inspection',
    'Accessories',
    'Insurance',
    'Body Parts',
    'Body Panels',
    'Electrical',
    'General Repair',
  };

  void _processPosts(List<Map<String, dynamic>> posts) {
    final Map<String, List<ServiceItem>> catMap = {};
    final Set<String> mainCatsSet = {'All'};

    final displayPosts = posts.isNotEmpty ? posts : [widget.mechanic];

    for (final post in displayPosts) {
      final specSubCats = Map<String, List<dynamic>>.from(post['specializationSubCategories'] ?? {});
      final specRates = Map<String, int>.from(post['specializationRates'] ?? {});
      final postCats = (post['categories'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

      // 1. Process explicit sub-categories from specializationSubCategories
      specSubCats.forEach((parentCatName, subList) {
        if (parentCatName == 'All') return;
        mainCatsSet.add(parentCatName);
        catMap.putIfAbsent(parentCatName, () => []);

        for (final sub in subList) {
          final sName = sub['name'] as String? ?? '';
          final sPrice = (sub['price'] as num?)?.toDouble() ?? 0.0;
          if (sName.isNotEmpty && sPrice > 0) {
            final service = ServiceItem(
              id: '${post['id'] ?? 'post'}_${parentCatName}_$sName',
              name: sName,
              category: parentCatName,
              price: sPrice,
              description: sName,
              vehicleType: VehicleType.car,
            );
            if (!catMap[parentCatName]!.any((s) => s.name == sName && s.price == sPrice)) {
              catMap[parentCatName]!.add(service);
            }
          }
        }
      });

      // 2. Process rate fallbacks: place under matching parent category
      specRates.forEach((itemKey, rate) {
        if (itemKey == 'All' || rate <= 0) return;

        bool alreadyAdded = false;
        catMap.forEach((parentCat, list) {
          if (list.any((s) => s.name == itemKey)) {
            alreadyAdded = true;
          }
        });

        if (!alreadyAdded) {
          final bool isMainCat = specSubCats.containsKey(itemKey) ||
              _knownMainCategories.any((k) => k.toLowerCase() == itemKey.toLowerCase());

          final targetCat = isMainCat
              ? itemKey
              : (mainCatsSet.length > 1 ? mainCatsSet.elementAt(1) : 'General Repair');

          if (isMainCat) {
            mainCatsSet.add(targetCat);
          }
          catMap.putIfAbsent(targetCat, () => []);

          final service = ServiceItem(
            id: '${post['id'] ?? 'post'}_${targetCat}_$itemKey',
            name: isMainCat ? '$itemKey Service' : itemKey,
            category: targetCat,
            price: rate.toDouble(),
            description: itemKey,
            vehicleType: VehicleType.car,
          );
          if (!catMap[targetCat]!.any((s) => s.name == service.name)) {
            catMap[targetCat]!.add(service);
          }
        }
      });

      // 3. Process main category entries from post['categories']
      for (final c in postCats) {
        if (c != 'All') {
          final bool isMainCat = specSubCats.containsKey(c) ||
              _knownMainCategories.any((k) => k.toLowerCase() == c.toLowerCase());
          if (isMainCat) {
            mainCatsSet.add(c);
          }
        }
      }
    }

    setState(() {
      _categorizedServices = catMap;
      _categoriesList = mainCatsSet.toList();
      if (widget.initialCategory != null) {
        final match = _categoriesList.firstWhere(
          (cat) => cat.toLowerCase() == widget.initialCategory!.toLowerCase(),
          orElse: () => '',
        );
        if (match.isNotEmpty) {
          _selectedCategory = match;
        }
      }
      _isLoadingPosts = false;
    });
  }



  double get _totalAmount {
    return _selectedServices.fold(0.0, (acc, item) => acc + item.price);
  }

  void _toggleServiceSelection(ServiceItem service) {
    setState(() {
      final index = _selectedServices.indexWhere((s) => s.id == service.id);
      if (index >= 0) {
        _selectedServices.removeAt(index);
      } else {
        _selectedServices.add(service);
      }
    });
  }

  void _proceedToBooking() {
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least one sub-category to proceed."),
          backgroundColor: Colors.amber,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final appState = context.read<AppState>();
    
    // Set selected services in AppState
    appState.setSelectedServices(_selectedServices);

    final mechanicId = widget.mechanic['mechanicId'] as String?;
    final mechanicName = widget.mechanic['name'] as String?;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingSummaryScreen(
          mechanicId: mechanicId,
          mechanicName: mechanicName,
        ),
      ),
    );
  }

  void _handleMessageMechanic() async {
    final appState = context.read<AppState>();
    final currentUserId = appState.user?.uid;
    if (currentUserId == null) return;

    final mechanicId = widget.mechanic['mechanicId'] as String?;
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E676)),
      ),
    );

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('customerId', isEqualTo: currentUserId)
          .where('mechanicId', isEqualTo: mechanicId)
          .limit(1)
          .get();

      if (mounted) Navigator.of(context).pop();

      if (querySnapshot.docs.isEmpty) {
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

      final roomId = currentUserId.compareTo(mechanicId) < 0
          ? '${currentUserId}_$mechanicId'
          : '${mechanicId}_$currentUserId';

      final chatDocRef = FirebaseFirestore.instance.collection('chats').doc(roomId);
      final chatDoc = await chatDocRef.get();
      if (!chatDoc.exists) {
        await chatDocRef.set({
          'id': roomId,
          'customerId': currentUserId,
          'customerName': appState.currentCustomerName ?? 'Customer',
          'customerPhotoUrl': appState.currentCustomerPhotoUrl ?? '',
          'mechanicId': mechanicId,
          'mechanicName': widget.mechanic['name'] ?? 'Mechanic',
          'mechanicPhotoUrl': widget.mechanic['photo'] ?? '',
          'lastMessage': '',
          'lastSenderId': '',
          'timestamp': FieldValue.serverTimestamp(),
          'unreadByCustomer': false,
          'unreadByMechanic': false,
        });
      }

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              roomId: roomId,
              recipientId: mechanicId,
              recipientName: widget.mechanic['name'] ?? 'Mechanic',
              recipientPhotoUrl: widget.mechanic['photo'] ?? '',
              recipientRole: 'Mechanic Specialist',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      debugPrint("Error creating chat: $e");
    }
  }

  void _showMechanicInfoModal() {
    final mech = widget.mechanic;
    final cats = (mech['categories'] as List<dynamic>?)?.map((e) => e.toString()).where((c) => c != 'All').toList() ?? [];

    var rawLoc = mech['location'] as String? ?? '';
    if (rawLoc.startsWith('Works in ')) {
      rawLoc = rawLoc.substring(9);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161426),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
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
                    'Mechanic Info',
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
                    radius: 32,
                    backgroundImage: NetworkImage(mech['photo']),
                    backgroundColor: const Color(0xFF0D0B18),
                    child: mech['photo'] == null
                        ? const Icon(Icons.person, color: Color(0xFF00E676), size: 32)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mech['name'] ?? 'Mechanic',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mech['title'] ?? 'Specialist Mechanic',
                          style: GoogleFonts.inter(color: const Color(0xFF00E676), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDetailRow('Experience', mech['experience'] ?? 'Experienced'),
              _buildDetailRow('Location', rawLoc.isNotEmpty ? rawLoc : 'Not specified'),
              const SizedBox(height: 16),
              Text(
                'About:',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                mech['desc'] ?? 'No bio provided.',
                style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 13, height: 1.4),
              ),
              if (cats.isNotEmpty) ...[
                const SizedBox(height: 16),
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
              const SizedBox(height: 24),
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
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161426),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(widget.mechanic['photo']),
              backgroundColor: const Color(0xFF0D0B18),
              child: widget.mechanic['photo'] == null
                  ? const Icon(Icons.person, color: Color(0xFF00E676), size: 18)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.mechanic['title'] ?? 'Mechanic Specialist',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'by ${widget.mechanic['name'] ?? 'Mechanic'}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF00E676),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
            onPressed: _handleMessageMechanic,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
            onPressed: _showMechanicInfoModal,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoadingPosts
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : Column(
              children: [
                // Service Category Tabs Bar
                Container(
                  color: const Color(0xFF161426),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _categoriesList.length,
                      itemBuilder: (context, index) {
                        final cat = _categoriesList[index];
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: const Color(0xFFFFB300),
                            disabledColor: const Color(0xFF0D0B18),
                            backgroundColor: const Color(0xFF0D0B18),
                            labelStyle: GoogleFonts.inter(
                              color: isSelected ? const Color(0xFF0D0B18) : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
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
                ),

                // Services & Sub-Categories List Body
                Expanded(
                  child: _buildServicesListBody(),
                ),

                // Fixed Bottom Checkout / Booking Bar
                if (_selectedServices.isNotEmpty) _buildBottomBookingBar(),
              ],
            ),
    );
  }

  Widget _buildServicesListBody() {
    List<ServiceItem> itemsToDisplay = [];

    if (_selectedCategory == 'All') {
      itemsToDisplay = _categorizedServices.values.expand((element) => element).toList();
    } else {
      itemsToDisplay = _categorizedServices[_selectedCategory] ?? [];
    }

    if (itemsToDisplay.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.work_off_outlined, color: Color(0xFF8B88A5), size: 48),
              const SizedBox(height: 12),
              Text(
                'No sub-categories posted for $_selectedCategory.',
                style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: itemsToDisplay.length,
      itemBuilder: (context, index) {
        final service = itemsToDisplay[index];
        final isSelected = _selectedServices.any((s) => s.id == service.id);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleServiceSelection(service),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF08693F).withValues(alpha: 0.15)
                      : const Color(0xFF161426),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF00E676) : const Color(0xFF302B53),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    // Checkbox Indicator
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? const Color(0xFF00E676) : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? const Color(0xFF00E676) : const Color(0xFF8B88A5),
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded, color: Color(0xFF0D0B18), size: 14)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    // Icon & Category Tag
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.name,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Price tag
                    Text(
                      '₹${service.price.toStringAsFixed(0)}',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF00E676),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBookingBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF161426),
        border: Border(
          top: BorderSide(color: Color(0xFF302B53), width: 1.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_selectedServices.length} ${_selectedServices.length == 1 ? "service" : "services"} selected',
                style: GoogleFonts.inter(color: const Color(0xFF8B88A5), fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                '₹${_totalAmount.toStringAsFixed(0)}',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF00E676),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: _proceedToBooking,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: const Color(0xFF0D0B18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            child: Text(
              'Proceed to Booking',
              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

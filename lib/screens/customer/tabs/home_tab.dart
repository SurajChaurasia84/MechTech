import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/app_state.dart';
import '../../../models/service_model.dart';
import '../find_mechanic_screen.dart';
import '../select_mechanic_screen.dart';
import '../referral_screen.dart';
import '../widgets/vehicle_selection_sheet.dart';

class HomeTab extends StatelessWidget {
  final String vehicleType; // 'car' | 'bike' | 'ev'

  const HomeTab({super.key, required this.vehicleType});

  // ── Data ─────────────────────────────────────────────────────────────────────

  static const Map<String, _VehicleData> _data = {
    'car': _VehicleData(
      bannerImage: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=800&q=80',
      bannerTitle: 'Car Service',
      bannerSubtitle: 'Starting at ₹1799',
      bannerBadges: ['3 Months Warranty', '100% Genuine Spare Parts', 'Free Pick-Up & Drop'],
      bannerColor: Color(0xFF9C27B0),
      smallServices: [
        _SmallService('Periodic Services', 'assets/service.png'),
        _SmallService('Spa & Detailing', 'assets/car-wash.png'),
        _SmallService('Tyres & Wheel', 'assets/car-tyre.png'),
        _SmallService('Batteries', 'assets/battery.png'),
        _SmallService('Brake & Suspension', 'assets/brake.png'),
        _SmallService('Clutch & Body', 'assets/clutch.png'),
        _SmallService('Lights & Mirror', 'assets/mirror.png'),
        _SmallService('Denting & Paint', 'assets/denting.png'),
        _SmallService('Custom Repair', 'assets/repair.png'),
        _SmallService('Car Inspection', 'assets/suspension.png'),
        _SmallService('Insurance', 'assets/insurance.png'),
        _SmallService('Electrical', 'assets/electrical.png'),
      ],
    ),
    'bike': _VehicleData(
      bannerImage: 'https://images.unsplash.com/photo-1558981806-ec527fa84c39?w=800&q=80',
      bannerTitle: '2-Wheeler Service',
      bannerSubtitle: 'Starting at ₹299',
      bannerBadges: ['Doorstep Service', 'Trained Mechanics', 'Quality Guaranteed'],
      bannerColor: Color(0xFFFF6B35),
      smallServices: [
        _SmallService('Periodic Services', 'assets/service.png'),
        _SmallService('Spa & Detailing', 'assets/spa.png'),
        _SmallService('Tyres & Wheel Care', 'assets/bike-tyre.png'),
        _SmallService('Batteries', 'assets/battery.png'),
        _SmallService('Brake & Suspension', 'assets/brake.png'),
        _SmallService('Clutch & Trans.', 'assets/clutch.png'),
        _SmallService('Lights & Mirror', 'assets/mirror.png'),
        _SmallService('Denting & Paint', 'assets/denting.png'),
        _SmallService('Custom Repair', 'assets/repair.png'),
        _SmallService('Accessories', 'assets/accessories.png'),
        _SmallService('Electrical', 'assets/electrical.png'),
        _SmallService('Body Parts', 'assets/suspension.png'),
      ],
    ),
    'ev': _VehicleData(
      bannerImage: 'https://images.unsplash.com/photo-1593941707882-a5bba14938c7?w=800&q=80',
      bannerTitle: 'EV Service',
      bannerSubtitle: 'Starting at ₹999',
      bannerBadges: ['Certified EV Mechanics', 'Battery Health Check', 'Software Diagnostics'],
      bannerColor: Color(0xFF00B0FF),
      smallServices: [
        _SmallService('Periodic Services', 'assets/service.png'),
        _SmallService('Tyres & Wheel Care', 'assets/car-tyre.png'),
        _SmallService('Battery Diagnostics', 'assets/ev-battery.png'),
        _SmallService('Brake Check', 'assets/brake.png'),
        _SmallService('Motor Service', 'assets/clutch.png'),
        _SmallService('Lights & Wiring', 'assets/electrical.png'),
        _SmallService('Body Panels', 'assets/suspension.png'),
        _SmallService('Charging Fix', 'assets/repair.png'),
        _SmallService('Accessories', 'assets/accessories.png'),
      ],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final vehicle = _data[vehicleType]!;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ReferralBannerPopup(),
          // ── Banner ──────────────────────────────────────────────────────────
          _Banner(vehicle: vehicle),

          const SizedBox(height: 20),

          // ── Section header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'More Services',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),

          // ── Small 4-col Service Grid ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: const Color(0xFFE5E7EB), // Divider line color
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: vehicle.smallServices.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: vehicleType == 'ev' ? 3 : 4,
                    crossAxisSpacing: 1, // 1px thin grid separator
                    mainAxisSpacing: 1,
                    childAspectRatio: vehicleType == 'ev' ? 1.05 : 0.9,
                  ),
                  itemBuilder: (ctx, i) {
                    final item = vehicle.smallServices[i];
                    return GestureDetector(
                      onTap: () => _handleServiceTap(ctx, item.name),
                      child: _SmallServiceCard(item: item),
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Find Mechanic CTA ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: appState,
                  child: FindMechanicScreen(initialVehicleCategory: vehicleType),
                ),
              )),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Find a\n',
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1.1,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Mechanic',
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF00E676),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'Browse mechanics near you',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF8B88A5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFF8B88A5),
                                size: 16,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Image.asset(
                      'assets/mechanic.png',
                      width: 70,
                      height: 70,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.engineering_rounded,
                        color: Color(0xFF00E676),
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _handleServiceTap(BuildContext context, String specialtyName) async {
    final appState = context.read<AppState>();
    
    VehicleType typeEnum = VehicleType.car;
    if (vehicleType == 'bike') {
      typeEnum = VehicleType.bike;
    }
    if (vehicleType == 'ev') {
      typeEnum = VehicleType.ev;
    }

    Future<void> proceedToBookingFlow() async {
      appState.clearServiceSelection();
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: appState,
          child: SelectMechanicScreen(
            specialtyFilter: specialtyName,
            vehicleTypeFilter: vehicleType,
          ),
        ),
      ));
    }

    if (appState.selectedVehicleType != typeEnum || appState.selectedVehicleModel == null) {
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF161426),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (sheetCtx) {
          return VehicleSelectionSheet(initialType: typeEnum);
        },
      ).then((selectedModel) {
        if (selectedModel != null && context.mounted) {
          proceedToBookingFlow();
        }
      });
    } else {
      await proceedToBookingFlow();
    }
  }
}

// ── Banner Widget ─────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  final _VehicleData vehicle;
  const _Banner({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: vehicle.bannerColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            Image.network(
              vehicle.bannerImage,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : Container(color: const Color(0xFF161426)),
              errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF161426)),
            ),
            // Dark gradient overlay
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.black.withValues(alpha: 0.2),
                  ],
                ),
              ),
            ),
            // Text content
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    vehicle.bannerTitle.toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      vehicle.bannerSubtitle,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...vehicle.bannerBadges.map((badge) => Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 12, color: vehicle.bannerColor),
                            const SizedBox(width: 5),
                            Text(badge, style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}



// ── Small Service Card (4-col) ────────────────────────────────────────────────

class _SmallServiceCard extends StatelessWidget {
  final _SmallService item;
  const _SmallServiceCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            item.assetPath,
            width: 44,
            height: 44,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 44,
              height: 44,
              color: const Color(0xFFF3F4F6),
              child: const Icon(Icons.broken_image, size: 20, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFF1F2937),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data Models ───────────────────────────────────────────────────────────────

class _VehicleData {
  final String bannerImage;
  final String bannerTitle;
  final String bannerSubtitle;
  final List<String> bannerBadges;
  final Color bannerColor;
  final List<_SmallService> smallServices;

  const _VehicleData({
    required this.bannerImage,
    required this.bannerTitle,
    required this.bannerSubtitle,
    required this.bannerBadges,
    required this.bannerColor,
    required this.smallServices,
  });
}



class _SmallService {
  final String name;
  final String assetPath;
  const _SmallService(this.name, this.assetPath);
}

class _ReferralBannerPopup extends StatefulWidget {
  const _ReferralBannerPopup();

  @override
  State<_ReferralBannerPopup> createState() => _ReferralBannerPopupState();
}

class _ReferralBannerPopupState extends State<_ReferralBannerPopup> {
  bool _isDismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    final appState = context.watch<AppState>();
    final user = appState.user;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final isDismissedFromDb = data?['referralBannerDismissed'] as bool? ?? false;
        final redeemed = data?['referralCodeUsed'] as String? ?? data?['referredBy'] as String?;

        // If user already redeemed or dismissed referral code, hide popup container forever!
        if (isDismissedFromDb || (redeemed != null && redeemed.isNotEmpty)) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1F1C38), Color(0xFF161426)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF00E676).withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E676).withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.card_giftcard_rounded,
                          color: Color(0xFF00E676),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Have a Referral Code? 🎁',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () async {
                      setState(() {
                        _isDismissed = true;
                      });
                      try {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .set({'referralBannerDismissed': true}, SetOptions(merge: true));
                      } catch (e) {
                        debugPrint("Error saving banner dismiss state: $e");
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Redeem now to get instant ₹60 (600 S-Coins) credited to your wallet!',
                style: GoogleFonts.inter(
                  color: const Color(0xFFB0ACC9),
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: const Color(0xFF0D0B18),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ReferralScreen(),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Redeem Now',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

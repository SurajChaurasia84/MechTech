import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/app_state.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  String? _referralCode;
  String? _redeemedCode;
  bool _isLoadingCode = true;
  bool _isRedeeming = false;
  Stream<QuerySnapshot>? _referralStream;
  final TextEditingController _inputCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadOrCreateReferralCode();
  }

  @override
  void dispose() {
    _inputCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadOrCreateReferralCode() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final user = appState.user;
    if (user == null) {
      if (mounted) setState(() => _isLoadingCode = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      String code = doc.data()?['referralCode'] as String? ?? '';
      final redeemed = doc.data()?['referralCodeUsed'] as String? ?? doc.data()?['referredBy'] as String?;

      if (code.isEmpty) {
        // Generate unique code: MT-{8 character mix of letters and digits}
        final cleanUid = user.uid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
        String suffix = '';
        if (cleanUid.length >= 8) {
          suffix = cleanUid.substring(cleanUid.length - 8);
        } else {
          suffix = (cleanUid + '8X9K2M4P').substring(0, 8);
        }
        code = 'MT-$suffix';

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'referralCode': code,
        }, SetOptions(merge: true));
      }

      if (mounted) {
        setState(() {
          _referralCode = code;
          _redeemedCode = redeemed;
          _referralStream = FirebaseFirestore.instance
              .collection('users')
              .where(Filter.or(
                Filter('referredBy', isEqualTo: code),
                Filter('referralCodeUsed', isEqualTo: code),
              ))
              .snapshots();
          _isLoadingCode = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading referral code: $e");
      if (mounted) setState(() => _isLoadingCode = false);
    }
  }

  Future<void> _redeemCode() async {
    final inputCode = _inputCodeController.text.trim().toUpperCase();
    if (inputCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a referral code.'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (inputCode == _referralCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You cannot redeem your own referral code.'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isRedeeming = true);

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('referralCode', isEqualTo: inputCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        if (mounted) {
          setState(() => _isRedeeming = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Invalid Referral Code. Please check and try again.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }

      final appState = Provider.of<AppState>(context, listen: false);
      final user = appState.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'referredBy': inputCode,
          'referralCodeUsed': inputCode,
        }, SetOptions(merge: true));

        await appState.addSCoins(
          600,
          'Referral Code Redeemed (₹60 Credit)',
          subtitle: 'Applied referral code $inputCode',
        );

        if (mounted) {
          setState(() {
            _redeemedCode = inputCode;
            _isRedeeming = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Referral code $inputCode applied! ₹60 (600 S-Coins) credited to your wallet 🎉',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF00E676),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error redeeming code: $e");
      if (mounted) {
        setState(() => _isRedeeming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Something went wrong. Please try again.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _copyCode() {
    if (_referralCode == null) return;
    Clipboard.setData(ClipboardData(text: _referralCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              'Referral Code Copied: $_referralCode',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF00E676),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _shareCode() {
    if (_referralCode == null) return;
    final message =
        'Hey! Use my referral code *$_referralCode* on MechTech app to get an instant ₹60 discount on your first vehicle service booking! 🚗🏍️⚡\n\nDownload MechTech now: https://play.google.com/store/apps/details?id=com.mechtech.mechanic.apps';
    Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    final displayCode = _referralCode ?? 'MT-8X9K2M4P';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161426),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          'Refer & Earn ₹60',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Simple Clean Hero Header (No outer border/background)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: Column(
                children: [
                  const Icon(
                    Icons.card_giftcard_rounded,
                    color: Color(0xFF00E676),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Invite Friends, Earn ₹60!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share your referral code. Your friend gets ₹60 discount on 1st booking, and you get ₹60 wallet credit when they complete their booking!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF8B88A5),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Referral Code Box
            Text(
              'Your Referral Code',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF161426),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF00E676).withValues(alpha: 0.6),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _isLoadingCode
                        ? const Text('Generating code...', style: TextStyle(color: Colors.grey))
                        : Text(
                            displayCode,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF00E676),
                              letterSpacing: 1.2,
                            ),
                          ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: _copyCode,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(6.0),
                          child: Icon(Icons.copy_rounded, color: Color(0xFF00E676), size: 20),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: _shareCode,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(6.0),
                          child: Icon(Icons.share_rounded, color: Color(0xFF00E676), size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildRedeemSection(),
            const SizedBox(height: 24),

            // 3-Step Guide
            Text(
              'How It Works',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161426),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF302B53).withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                children: [
                  _buildStepRow(
                    stepNum: '1',
                    title: 'Share Code or Link',
                    subtitle: 'Send your referral code to your friends on WhatsApp, SMS or Social Media.',
                  ),
                  const Divider(color: Color(0xFF302B53), height: 24),
                  _buildStepRow(
                    stepNum: '2',
                    title: 'Friend Signs Up & Gets ₹60 Discount',
                    subtitle: 'Your friend uses code during Sign-up or Booking to get ₹60 instant discount.',
                  ),
                  const Divider(color: Color(0xFF302B53), height: 24),
                  _buildStepRow(
                    stepNum: '3',
                    title: 'Service Completed → You Get ₹60',
                    subtitle: 'When your friend completes their first service booking with payment, ₹60 wallet credit (600 S-Coins) is added to your account!',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Referral Stats
            Text(
              'My Referral Activity',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
               if (_referralStream != null)
              StreamBuilder<QuerySnapshot>(
                stream: _referralStream,
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  final totalReferred = docs.length;
                  final rewardedDocs = docs.where((d) => (d.data() as Map<String, dynamic>)['referralRewarded'] == true).toList();
                  final totalEarned = rewardedDocs.length * 60;

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: 'Friends Joined',
                              value: '$totalReferred',
                              icon: Icons.people_alt_rounded,
                              color: const Color(0xFF00B0FF),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              title: 'Total Earned',
                              value: '₹$totalEarned',
                              icon: Icons.account_balance_wallet_rounded,
                              color: const Color(0xFF00E676),
                            ),
                          ),
                        ],
                      ),
                      if (docs.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: docs.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            final name = data['name'] as String? ?? 'Friend';
                            final isRewarded = data['referralRewarded'] == true;

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161426),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isRewarded ? const Color(0xFF00E676).withValues(alpha: 0.4) : const Color(0xFF302B53),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: isRewarded ? const Color(0xFF00E676).withValues(alpha: 0.15) : const Color(0xFF302B53),
                                    child: Icon(
                                      isRewarded ? Icons.check_circle_rounded : Icons.person,
                                      color: const Color(0xFF00E676),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          isRewarded ? '1st service completed 🎉' : 'Signed up with your code',
                                          style: GoogleFonts.inter(
                                            color: isRewarded ? const Color(0xFF00E676) : const Color(0xFF8B88A5),
                                            fontSize: 12,
                                            fontWeight: isRewarded ? FontWeight.w500 : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    isRewarded ? '+₹60 Credited' : '+₹60 Pending',
                                    style: GoogleFonts.outfit(
                                      color: isRewarded ? const Color(0xFF00E676) : const Color(0xFFFFD700),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  );
                },
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Friends Joined',
                      value: '0',
                      icon: Icons.people_alt_rounded,
                      color: const Color(0xFF00B0FF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Total Earned',
                      value: '₹0',
                      icon: Icons.account_balance_wallet_rounded,
                      color: const Color(0xFF00E676),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required String stepNum,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF00E676),
          ),
          alignment: Alignment.center,
          child: Text(
            stepNum,
            style: GoogleFonts.outfit(
              color: const Color(0xFF0D0B18),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: const Color(0xFF8B88A5),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161426),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF302B53)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0xFF8B88A5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedeemSection() {
    if (_redeemedCode != null && _redeemedCode!.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF00E676).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF00E676).withValues(alpha: 0.5),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Referral Code Applied: $_redeemedCode',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF00E676),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'You redeemed ₹60 welcome bonus!',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8B88A5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Have a Referral Code?',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: TextField(
                  controller: _inputCodeController,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter Code (e.g. MT-XXXXXX)',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF535072),
                      fontSize: 13,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    filled: true,
                    fillColor: const Color(0xFF161426),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF302B53)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF302B53)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF00E676)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: const Color(0xFF0D0B18),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: _isRedeeming ? null : _redeemCode,
                child: _isRedeeming
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0D0B18),
                        ),
                      )
                    : Text(
                        'Redeem',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/app_state.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final coins = appState.sCoins;
    final rupeeValue = appState.sCoinsRupeeValue;
    final currentUser = appState.user;

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
          'S-Coin Wallet',
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
            // Simple Clean Balance Section (No outer border / background)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/coin.png',
                        width: 48,
                        height: 48,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.monetization_on_rounded,
                          color: Color(0xFFFFD700),
                          size: 48,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$coins S-Coins',
                              style: GoogleFonts.outfit(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFFD700),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '≈ ₹${rupeeValue.toStringAsFixed(2)} Rupees',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF00E676),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF8B88A5), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '100 S-Coins = ₹10 Rupees',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF8B88A5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // How to Earn Coins Card
            Text(
              'How to Earn S-Coins',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF161426),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF302B53).withValues(alpha: 0.6),
                  width: 1.2,
                ),
              ),
              child: Column(
                children: [
                  _buildEarningRow(
                    icon: Icons.two_wheeler_rounded,
                    title: 'Bike Service Completed',
                    coins: '50 - 100 S-Coins',
                    color: const Color(0xFF00B0FF),
                  ),
                  const Divider(color: Color(0xFF302B53), height: 20),
                  _buildEarningRow(
                    icon: Icons.directions_car_rounded,
                    title: 'Car Service Completed',
                    coins: '300 - 500 S-Coins',
                    color: const Color(0xFF00E676),
                  ),
                  const Divider(color: Color(0xFF302B53), height: 20),
                  _buildEarningRow(
                    icon: Icons.electric_car_rounded,
                    title: 'EV Service Completed',
                    coins: '200 - 400 S-Coins',
                    color: const Color(0xFFFFD700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Wallet Activity / Transaction History Header
            Text(
              'Transaction History',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            // Firestore Stream for Wallet Transactions
            if (currentUser != null)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .collection('wallet_transactions')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(color: Color(0xFF00E676)),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return _buildDefaultTransactionList();
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final title = data['title'] as String? ?? 'Wallet Transaction';
                      final subtitle = data['subtitle'] as String? ?? '';
                      final amount = (data['amount'] as num?)?.toInt() ?? 0;
                      final isCredit = amount >= 0;

                      return _buildTransactionCard(
                        title: title,
                        subtitle: subtitle,
                        amountStr: isCredit ? '+$amount S-Coins' : '$amount S-Coins',
                        isCredit: isCredit,
                      );
                    },
                  );
                },
              )
            else
              _buildDefaultTransactionList(),
          ],
        ),
      ),
    );
  }


  Widget _buildEarningRow({
    required IconData icon,
    required String title,
    required String coins,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
          ),
          child: Text(
            coins,
            style: GoogleFonts.outfit(
              color: const Color(0xFFFFD700),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultTransactionList() {
    return Padding(
      padding: const EdgeInsets.only(top: 30.0, bottom: 24.0),
      child: Center(
        child: Text(
          'No transaction yet',
          style: GoogleFonts.inter(
            color: const Color(0xFF8B88A5),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard({
    required String title,
    required String subtitle,
    required String amountStr,
    required bool isCredit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161426),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF302B53).withValues(alpha: 0.5),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCredit
                  ? const Color(0xFF00E676).withValues(alpha: 0.15)
                  : Colors.redAccent.withValues(alpha: 0.15),
            ),
            child: Icon(
              isCredit ? Icons.add_rounded : Icons.remove_rounded,
              color: isCredit ? const Color(0xFF00E676) : Colors.redAccent,
              size: 20,
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
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8B88A5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            amountStr,
            style: GoogleFonts.outfit(
              color: isCredit ? const Color(0xFF00E676) : Colors.redAccent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

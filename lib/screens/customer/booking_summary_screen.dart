import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/service_model.dart';
import '../../services/app_state.dart';
import '../../utils/booking_utils.dart';
import '../../utils/payment_config.dart';
import 'booking_success_screen.dart';

class BookingSummaryScreen extends StatefulWidget {
  final String? mechanicId;
  final String? mechanicName;
  final ServiceBooking? bookingResult;

  const BookingSummaryScreen({
    super.key,
    this.mechanicId,
    this.mechanicName,
    this.bookingResult,
  });

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  bool _isLoading = false;
  late Razorpay _razorpay;
  BookingPrepResult? _cachedPrepResult;

  @override
  void initState() {
    super.initState();
    if (widget.bookingResult != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => BookingSuccessScreen(
                isSuccess: true,
                booking: widget.bookingResult!,
              ),
            ),
          );
        }
      });
    }
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final prep = _cachedPrepResult;
      final token = await appState.user?.getIdToken();

      // 1. Verify payment signature on the backend securely & write booking
      final verificationUrl = Uri.parse('${PaymentConfig.backendBaseUrl}/api/verify-payment');
      final verifyResponse = await http.post(
        verificationUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'orderId': response.orderId,
          'paymentId': response.paymentId,
          'signature': response.signature,
          'mechanicId': widget.mechanicId,
          'vehicleModel': appState.selectedVehicleModel ?? '',
          'vehicleType': appState.selectedVehicleType?.name ?? 'car',
          'services': appState.selectedServices.map((s) => s.name).toList(),
          'latitude': prep?.position?.latitude,
          'longitude': prep?.position?.longitude,
          'bookingLocation': prep?.address,
        }),
      );

      if (verifyResponse.statusCode != 200) {
        throw Exception("Server verification rejected payment signature: ${verifyResponse.body}");
      }

      final verificationData = jsonDecode(verifyResponse.body);
      final isVerified = verificationData['verified'] as bool? ?? false;
      final serverBookingId = verificationData['bookingId'] as String?;

      if (!isVerified || serverBookingId == null) {
        throw Exception("Signature verification failed.");
      }

      // 2. Refresh local bookings list to pull the backend-written record
      await appState.refreshBookings();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Resolve the booking from local list matching the new booking ID
        final result = appState.bookings.firstWhere(
          (b) => b.id == serverBookingId,
          orElse: () => throw Exception("Failed to find verified booking record locally."),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BookingSuccessScreen(
              isSuccess: true,
              booking: result,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error handling payment success: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BookingSuccessScreen(
              isSuccess: false,
              errorMessage: 'Security verification failed: $e',
            ),
          ),
        );
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    
    // Redirect directly to failed status screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BookingSuccessScreen(
          isSuccess: false,
          errorMessage: response.message ?? "Transaction cancelled or failed.",
        ),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("External Wallet Selected: ${response.walletName}");
  }

  Future<void> _bookService(AppState appState) async {
    setState(() => _isLoading = true);

    try {
      // Call helper to check phone number and fetch location
      final prepResult = await BookingUtils.prepareForBooking(context);
      if (!prepResult.success) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      _cachedPrepResult = prepResult;

      final token = await appState.user?.getIdToken();

      // Create Razorpay Order on Vercel Backend securely
      final orderCreationUrl = Uri.parse('${PaymentConfig.backendBaseUrl}/api/create-order');
      final orderResponse = await http.post(
        orderCreationUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'mechanicId': widget.mechanicId,
          'vehicleModel': appState.selectedVehicleModel ?? '',
          'vehicleType': appState.selectedVehicleType?.name ?? 'car',
          'services': appState.selectedServices.map((s) => s.name).toList(),
        }),
      );

      if (orderResponse.statusCode != 200) {
        throw Exception("Failed to generate order ID from backend: ${orderResponse.body}");
      }

      final orderData = jsonDecode(orderResponse.body);
      final orderId = orderData['orderId'] as String?;
      final serverAmount = orderData['amount'] as num?;

      if (orderId == null || orderId.isEmpty || serverAmount == null) {
        throw Exception("Generated Order ID or amount is null or empty.");
      }

      final options = {
        'key': PaymentConfig.razorpayKeyId,
        'amount': serverAmount,
        'name': 'MechTech Services',
        'description': 'Booking Service Payment',
        'order_id': orderId,
        'timeout': 300,
        'prefill': {
          'contact': appState.currentCustomerPhone ?? '',
          'email': appState.currentCustomerEmail ?? '',
        },
        'theme': {
          'color': '#00E676',
        }
      };

      _razorpay.open(options);
    } catch (e) {
      debugPrint("Error starting booking service payment: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BookingSuccessScreen(
              isSuccess: false,
              errorMessage: 'Could not configure payment order: $e',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final vehicleType = appState.selectedVehicleType;
    final vehicleModel = appState.selectedVehicleModel ?? '';
    final selectedServices = appState.selectedServices;

    // Prices calculation
    final serviceTotal = selectedServices.fold<double>(0.0, (sum, item) => sum + item.price);
    const platformFee = PaymentConfig.platformFee;
    final total = serviceTotal + platformFee;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161426),
        elevation: 0,
        title: Text(
          'Confirm Booking',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Background soft glows
          Positioned(
            bottom: 100,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00B0FF).withOpacity(0.06),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00B0FF).withOpacity(0.06),
                    blurRadius: 60,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Vehicle Card
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161426),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF302B53), width: 1.2),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D0B18),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  vehicleType == VehicleType.car
                                      ? Icons.directions_car_outlined
                                      : vehicleType == VehicleType.bike
                                          ? Icons.two_wheeler_outlined
                                          : Icons.electric_car_outlined,
                                  color: const Color(0xFF00E676),
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vehicleModel,
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    vehicleType?.displayName ?? '',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: const Color(0xFF8B88A5),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (widget.mechanicName != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF161426),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF00B0FF).withOpacity(0.4), width: 1.2),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00B0FF).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.person_outline_rounded,
                                    color: Color(0xFF00B0FF),
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.mechanicName!,
                                        style: GoogleFonts.outfit(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Assigned Mechanic Specialist',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: const Color(0xFF8B88A5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Selected Services Header
                        Text(
                          'Services Summary',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Service Items List
                        ...selectedServices.map((service) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161426).withOpacity(0.6),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      service.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '₹${service.price.toStringAsFixed(0)}',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 24),

                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161426),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF302B53), width: 1.2),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Service Charges',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: const Color(0xFF8B88A5),
                                    ),
                                  ),
                                  Text(
                                    '₹${serviceTotal.toStringAsFixed(2)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Platform Charges',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: const Color(0xFF8B88A5),
                                    ),
                                  ),
                                  Text(
                                    '₹${platformFee.toStringAsFixed(2)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(color: Color(0xFF302B53), height: 24, thickness: 1.2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Amount',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '₹${total.toStringAsFixed(2)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF00E676),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Book Button
                Padding(
                  padding: const EdgeInsets.only(left: 24, right: 24, bottom: 32, top: 12),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: _isLoading
                            ? [const Color(0xFF444444), const Color(0xFF444444)]
                            : [const Color(0xFF00E676), const Color(0xFF00B0FF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E676).withOpacity(_isLoading ? 0 : 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _isLoading ? null : () => _bookService(appState),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Pay & Book Now',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF0D0B18),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
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
}

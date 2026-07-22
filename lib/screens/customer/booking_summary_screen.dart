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
  bool _useSCoins = false;
  late Razorpay _razorpay;
  BookingPrepResult? _cachedPrepResult;
  String? _lastOrderId;
  String _selectedPaymentMethod = 'Online';

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
          'orderId': response.orderId ?? _lastOrderId,
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

      // 2. Parse the verified booking directly from the backend response payload
      final bookingMap = verificationData['booking'] as Map<String, dynamic>?;
      if (bookingMap == null) {
        throw Exception("Verification response did not contain booking details.");
      }

      // Resolve services by parsing the returned services list
      final rawServices = (bookingMap['services'] as List<dynamic>?) ?? [];
      List<ServiceItem> resolvedServices = [];
      if (rawServices.isNotEmpty) {
        resolvedServices = rawServices.map((s) {
          if (s is Map<String, dynamic>) {
            final name = s['name'] as String? ?? '';
            final price = (s['price'] as num?)?.toDouble() ?? 0.0;
            return ServiceItem(
              id: s['id'] as String? ?? name,
              name: name,
              price: price,
              description: 'Professional $name services.',
              vehicleType: appState.selectedVehicleType ?? VehicleType.car,
              category: name,
            );
          } else {
            final name = s.toString();
            return appState.selectedServices.firstWhere(
              (item) => item.name.toLowerCase() == name.toLowerCase(),
              orElse: () => ServiceItem(
                id: name,
                name: name,
                price: 0.0,
                description: 'Professional $name services.',
                vehicleType: appState.selectedVehicleType ?? VehicleType.car,
                category: name,
              ),
            );
          }
        }).toList();
      }

      if (resolvedServices.isEmpty || resolvedServices.every((s) => s.price == 0.0)) {
        resolvedServices = List.from(appState.selectedServices);
      }

      final parsedBooking = ServiceBooking(
        id: bookingMap['id'] as String? ?? serverBookingId,
        customerName: bookingMap['customerName'] as String? ?? '',
        customerId: bookingMap['customerId'] as String?,
        customerPhone: bookingMap['customerPhone'] as String?,
        customerEmail: bookingMap['customerEmail'] as String?,
        vehicleType: appState.selectedVehicleType ?? VehicleType.car,
        vehicleModel: bookingMap['vehicleModel'] as String? ?? '',
        selectedServices: resolvedServices,
        bookingDate: DateTime.now(),
        status: bookingMap['status'] as String? ?? 'Pending',
        mechanicId: bookingMap['mechanicId'] as String?,
        mechanicName: bookingMap['mechanicName'] as String?,
        latitude: (bookingMap['latitude'] as num?)?.toDouble(),
        longitude: (bookingMap['longitude'] as num?)?.toDouble(),
        bookingLocation: bookingMap['bookingLocation'] as String?,
        paymentId: bookingMap['paymentId'] as String?,
        paymentStatus: bookingMap['paymentStatus'] as String?,
        discount: (bookingMap['discount'] as num?)?.toDouble() ?? (_useSCoins ? ((appState.sCoins / 100.0) * 10.0) : 0.0),
      );

      // 3. Deduct S-Coins if discount was used
      if (_useSCoins) {
        final availableCoins = appState.sCoins;
        final maxRupeeDiscount = (availableCoins / 100.0) * 10.0;
        final serviceTotal = appState.selectedServices.fold<double>(0.0, (sum, item) => sum + item.price);
        final coinDiscount = (maxRupeeDiscount > serviceTotal ? serviceTotal : maxRupeeDiscount);
        final coinsToRedeem = ((coinDiscount / 10.0) * 100).round();
        if (coinsToRedeem > 0) {
          await appState.redeemSCoins(
            coinsToRedeem,
            'Booking Discount Redemption',
            subtitle: 'Redeemed S-Coins on service booking',
          );
        }
      }

      // 4. Trigger a background local list update
      appState.refreshBookings();
      appState.clearServiceSelection();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BookingSuccessScreen(
              isSuccess: true,
              booking: parsedBooking,
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

      // Calculate prices and coin discount
      final serviceTotal = appState.selectedServices.fold<double>(0.0, (sum, item) => sum + item.price);
      const platformFee = PaymentConfig.platformFee;
      final availableCoins = appState.sCoins;
      final maxRupeeDiscount = (availableCoins / 100.0) * 10.0;
      final coinDiscount = _useSCoins ? (maxRupeeDiscount > serviceTotal ? serviceTotal : maxRupeeDiscount) : 0.0;
      final finalAmount = (serviceTotal + platformFee - coinDiscount).clamp(0.0, double.infinity);
      final coinsToRedeem = _useSCoins ? ((coinDiscount / 10.0) * 100).round() : 0;
      final payableAmountInPaise = (finalAmount * 100).round();

      final token = await appState.user?.getIdToken();

      // Create Razorpay Order on Vercel Backend securely
      final orderCreationUrl = Uri.parse('${PaymentConfig.backendBaseUrl}/api/create-order');
      http.Response orderResponse = await http.post(
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
          'serviceObjects': appState.selectedServices.map((s) => {'name': s.name, 'price': s.price}).toList(),
          'discount': coinDiscount,
          'coinDiscount': coinDiscount,
          'useSCoins': _useSCoins,
          'coinsToRedeem': coinsToRedeem,
          'amount': payableAmountInPaise,
          'finalAmount': finalAmount,
          'payableAmount': finalAmount,
        }),
      );

      // If backend fails due to mechanic service mismatch, retry general order without mechanicId
      if (orderResponse.statusCode != 200 && widget.mechanicId != null) {
        orderResponse = await http.post(
          orderCreationUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'vehicleModel': appState.selectedVehicleModel ?? '',
            'vehicleType': appState.selectedVehicleType?.name ?? 'car',
            'services': appState.selectedServices.map((s) => s.name).toList(),
            'serviceObjects': appState.selectedServices.map((s) => {'name': s.name, 'price': s.price}).toList(),
            'discount': coinDiscount,
            'coinDiscount': coinDiscount,
            'useSCoins': _useSCoins,
            'coinsToRedeem': coinsToRedeem,
            'amount': payableAmountInPaise,
            'finalAmount': finalAmount,
            'payableAmount': finalAmount,
          }),
        );
      }

      if (orderResponse.statusCode != 200) {
        throw Exception("Failed to generate order ID from backend: ${orderResponse.body}");
      }

      final orderData = jsonDecode(orderResponse.body);
      final orderId = orderData['orderId'] as String?;
      _lastOrderId = orderId;

      final Map<String, dynamic> options = {
        'key': PaymentConfig.razorpayKeyId,
        'amount': payableAmountInPaise,
        'name': 'MechTech Services',
        'description': _useSCoins
            ? 'Booking Service Payment (S-Coins Applied)'
            : 'Booking Service Payment',
        'timeout': 300,
        'prefill': {
          'contact': appState.currentCustomerPhone ?? '',
          'email': appState.currentCustomerEmail ?? '',
        },
        'theme': {
          'color': '#00E676',
        }
      };

      if (!_useSCoins && orderId != null && orderId.isNotEmpty) {
        options['order_id'] = orderId;
      }

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

  Future<void> _bookServiceWithCOD(AppState appState) async {
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

      final token = await appState.user?.getIdToken();

      // Calculate discount and coins to redeem
      final serviceTotal = appState.selectedServices.fold<double>(0.0, (sum, item) => sum + item.price);
      final availableCoins = appState.sCoins;
      final maxRupeeDiscount = (availableCoins / 100.0) * 10.0;
      final coinDiscount = _useSCoins ? (maxRupeeDiscount > serviceTotal ? serviceTotal : maxRupeeDiscount) : 0.0;
      final coinsToRedeem = _useSCoins ? ((coinDiscount / 10.0) * 100).round() : 0;

      // Call new secure Vercel API for COD booking
      final codUrl = Uri.parse('${PaymentConfig.backendBaseUrl}/api/create-cod-booking');
      final response = await http.post(
        codUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'mechanicId': widget.mechanicId,
          'vehicleModel': appState.selectedVehicleModel ?? '',
          'vehicleType': appState.selectedVehicleType?.name ?? 'car',
          'services': appState.selectedServices.map((s) => s.name).toList(),
          'serviceObjects': appState.selectedServices.map((s) => {'name': s.name, 'price': s.price}).toList(),
          'latitude': prepResult.position?.latitude,
          'longitude': prepResult.position?.longitude,
          'bookingLocation': prepResult.address,
          'discount': coinDiscount,
          'useSCoins': _useSCoins,
          'coinsToRedeem': coinsToRedeem,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to create COD booking: ${response.body}");
      }

      final responseData = jsonDecode(response.body);
      final bookingMap = responseData['booking'] as Map<String, dynamic>?;
      if (bookingMap == null) {
        throw Exception("Server did not return booking details.");
      }

      // Parse booking and resolve service prices
      final rawServices = (bookingMap['services'] as List<dynamic>?) ?? [];
      List<ServiceItem> resolvedServices = [];
      if (rawServices.isNotEmpty) {
        resolvedServices = rawServices.map((s) {
          if (s is Map<String, dynamic>) {
            final name = s['name'] as String? ?? '';
            final price = (s['price'] as num?)?.toDouble() ?? 0.0;
            return ServiceItem(
              id: s['id'] as String? ?? name,
              name: name,
              price: price,
              description: 'Professional $name services.',
              vehicleType: appState.selectedVehicleType ?? VehicleType.car,
              category: name,
            );
          } else {
            final name = s.toString();
            return appState.selectedServices.firstWhere(
              (item) => item.name.toLowerCase() == name.toLowerCase(),
              orElse: () => ServiceItem(
                id: name,
                name: name,
                price: 0.0,
                description: 'Professional $name services.',
                vehicleType: appState.selectedVehicleType ?? VehicleType.car,
                category: name,
              ),
            );
          }
        }).toList();
      }

      if (resolvedServices.isEmpty || resolvedServices.every((s) => s.price == 0.0)) {
        resolvedServices = List.from(appState.selectedServices);
      }

      final parsedBooking = ServiceBooking(
        id: bookingMap['id'] as String? ?? '',
        customerName: bookingMap['customerName'] as String? ?? '',
        customerId: bookingMap['customerId'] as String?,
        customerPhone: bookingMap['customerPhone'] as String?,
        customerEmail: bookingMap['customerEmail'] as String?,
        vehicleType: appState.selectedVehicleType ?? VehicleType.car,
        vehicleModel: bookingMap['vehicleModel'] as String? ?? '',
        selectedServices: resolvedServices,
        bookingDate: DateTime.now(),
        status: bookingMap['status'] as String? ?? 'Pending',
        mechanicId: bookingMap['mechanicId'] as String?,
        mechanicName: bookingMap['mechanicName'] as String?,
        latitude: (bookingMap['latitude'] as num?)?.toDouble(),
        longitude: (bookingMap['longitude'] as num?)?.toDouble(),
        bookingLocation: bookingMap['bookingLocation'] as String?,
        paymentId: bookingMap['paymentId'] as String?,
        paymentStatus: bookingMap['paymentStatus'] as String?,
        discount: (bookingMap['discount'] as num?)?.toDouble() ?? coinDiscount,
      );

      // Deduct S-Coins if used
      if (_useSCoins && coinsToRedeem > 0) {
        await appState.redeemSCoins(
          coinsToRedeem,
          'Booking Discount Redemption (COD)',
          subtitle: 'Redeemed S-Coins on COD service booking',
        );
      }

      // Trigger local list updates
      appState.refreshBookings();
      appState.clearServiceSelection();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BookingSuccessScreen(
              isSuccess: true,
              booking: parsedBooking,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error creating COD booking: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BookingSuccessScreen(
              isSuccess: false,
              errorMessage: 'Could not complete booking: $e',
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
    final availableCoins = appState.sCoins;
    final maxRupeeDiscount = (availableCoins / 100.0) * 10.0;
    final coinDiscount = _useSCoins ? (maxRupeeDiscount > serviceTotal ? serviceTotal : maxRupeeDiscount) : 0.0;
    final total = (serviceTotal + platformFee - coinDiscount).clamp(0.0, double.infinity);

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

                        if (appState.sCoins > 0) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Image.asset(
                                  'assets/coin.png',
                                  width: 28,
                                  height: 28,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.monetization_on_rounded,
                                    color: Color(0xFFFFD700),
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Use S-Coins',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFFFFD700),
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Use ${appState.sCoins} S-Coins for ₹${maxRupeeDiscount.toStringAsFixed(2)} off',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF8B88A5),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _useSCoins,
                                  activeColor: const Color(0xFFFFD700),
                                  onChanged: (val) => setState(() => _useSCoins = val),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

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
                              if (_useSCoins && coinDiscount > 0) ...[
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'S-Coin Discount',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: const Color(0xFFFFD700),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '-₹${coinDiscount.toStringAsFixed(2)}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        color: const Color(0xFFFFD700),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
                        const SizedBox(height: 24),
                        // Payment Method Selection
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161426),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF302B53), width: 1.2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Payment Method',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Pay Online (Razorpay)
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedPaymentMethod = 'Online';
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _selectedPaymentMethod == 'Online'
                                        ? const Color(0xFF00E676).withOpacity(0.08)
                                        : const Color(0xFF0D0B18),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _selectedPaymentMethod == 'Online'
                                          ? const Color(0xFF00E676)
                                          : const Color(0xFF302B53),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.payment_rounded,
                                        color: _selectedPaymentMethod == 'Online'
                                            ? const Color(0xFF00E676)
                                            : const Color(0xFF8B88A5),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Pay Online',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Pay securely via UPI, Cards, or NetBanking',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: const Color(0xFF8B88A5),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Radio<String>(
                                        value: 'Online',
                                        groupValue: _selectedPaymentMethod,
                                        activeColor: const Color(0xFF00E676),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _selectedPaymentMethod = val;
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Cash on Delivery (COD)
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedPaymentMethod = 'COD';
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _selectedPaymentMethod == 'COD'
                                        ? const Color(0xFF00E676).withOpacity(0.08)
                                        : const Color(0xFF0D0B18),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _selectedPaymentMethod == 'COD'
                                          ? const Color(0xFF00E676)
                                          : const Color(0xFF302B53),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.payments_rounded,
                                        color: _selectedPaymentMethod == 'COD'
                                            ? const Color(0xFF00E676)
                                            : const Color(0xFF8B88A5),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Cash on Delivery (COD)',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Pay in cash after the service is completed',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: const Color(0xFF8B88A5),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Radio<String>(
                                        value: 'COD',
                                        groupValue: _selectedPaymentMethod,
                                        activeColor: const Color(0xFF00E676),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _selectedPaymentMethod = val;
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
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
                        onTap: _isLoading
                            ? null
                            : () => _selectedPaymentMethod == 'COD'
                                ? _bookServiceWithCOD(appState)
                                : _bookService(appState),
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
                                  _selectedPaymentMethod == 'COD'
                                      ? 'Confirm & Book Now'
                                      : 'Pay & Book Now',
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

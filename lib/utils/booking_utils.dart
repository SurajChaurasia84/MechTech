import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../screens/customer/edit_profile_screen.dart';
import '../screens/customer/add_address_screen.dart';

class BookingPrepResult {
  final bool success;
  final Position? position;
  final String? address;

  BookingPrepResult({
    required this.success,
    this.position,
    this.address,
  });
}

class BookingUtils {
  /// Verifies if a user has a phone number set. If not, navigates them to EditProfileScreen.
  /// Then fetches the current GPS location. If GPS fails/denied, checks for a saved address,
  /// and if missing, navigates them to AddAddressScreen.
  static Future<BookingPrepResult> prepareForBooking(BuildContext context) async {
    final appState = context.read<AppState>();

    // 1. Enforce Mobile Number
    var currentPhone = appState.currentCustomerPhone;
    if (currentPhone == null || currentPhone.trim().isEmpty) {
      // Navigate to EditProfileScreen to enter mobile number
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
      );

      if (!context.mounted) return BookingPrepResult(success: false);

      // Check again after popping back
      currentPhone = appState.currentCustomerPhone;
      if (currentPhone == null || currentPhone.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking aborted: Mobile number is required.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return BookingPrepResult(success: false);
      }
    }

    if (!context.mounted) return BookingPrepResult(success: false);

    // 2. Fetch GPS Location
    final position = await _fetchLocation(context);
    
    if (!context.mounted) return BookingPrepResult(success: false);

    if (position != null) {
      String resolvedAddress = '';
      try {
        final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final street = p.street ?? '';
          final subLocality = p.subLocality ?? '';
          final city = p.locality ?? p.administrativeArea ?? '';
          final postalCode = p.postalCode ?? '';
          
          final parts = [
            if (street.isNotEmpty && street != subLocality) street,
            if (subLocality.isNotEmpty) subLocality,
            if (city.isNotEmpty && city != subLocality) city,
            if (postalCode.isNotEmpty) postalCode,
          ];
          resolvedAddress = parts.join(', ');
        }
      } catch (e) {
        debugPrint("Geocoding failed in BookingUtils: $e");
      }

      if (resolvedAddress.isEmpty) {
        resolvedAddress = 'GPS Coordinates (${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)})';
      }

      return BookingPrepResult(
        success: true,
        position: position,
        address: resolvedAddress,
      );
    }

    // 3. Fallback: If GPS failed/denied, check profile address
    var currentAddress = appState.customerAddress;
    if (currentAddress == null || currentAddress.trim().isEmpty) {
      // Navigate to AddAddressScreen to enter address manually
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AddAddressScreen()),
      );

      if (!context.mounted) return BookingPrepResult(success: false);

      // Check again after popping back
      currentAddress = appState.customerAddress;
      if (currentAddress == null || currentAddress.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking aborted: Service location address is required.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return BookingPrepResult(success: false);
      }
    }

    return BookingPrepResult(
      success: true,
      address: currentAddress,
    );
  }

  static Future<Position?> _fetchLocation(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    if (!context.mounted) return null;
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Check last known location first (very fast fallback)
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return lastKnown;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E676)),
              ),
              const SizedBox(width: 12),
              Text(
                'Fetching your current location...',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF161426),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Perform position lookup with 10 second timeout and medium accuracy
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint("Error fetching location: $e");
      return null;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

class LocationHelper {
  /// Shows a prominent disclosure dialog to the user before requesting location permission.
  /// If the user accepts, it calls Geolocator.requestPermission().
  /// Otherwise, it returns LocationPermission.denied.
  static Future<LocationPermission> requestLocationPermissionWithDisclosure(BuildContext context) async {
    // 1. Check if permission is already granted
    final currentPermission = await Geolocator.checkPermission();
    if (currentPermission == LocationPermission.always || currentPermission == LocationPermission.whileInUse) {
      return currentPermission;
    }

    // 2. If denied or unable to determine, show the disclosure dialog
    if (!context.mounted) return LocationPermission.denied;

    final bool? userAccepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161426),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF302B53), width: 1.5),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Beautiful Icon Header
              Container(
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFF00E676),
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                'Location Access Required',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              // Disclosure Message (Must explicitly state when location is accessed, why, and that it is used even when the app is in use)
              Text(
                'MechTech collects location data to find, show, and connect you with nearby auto mechanics. This data is used to calculate distances, recommend the closest help, and coordinate booking requests.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF8B88A5),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              // Buttons
              Row(
                children: [
                  // Cancel Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF302B53), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Not Now',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF8B88A5),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Accept Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: const Color(0xFF0D0B18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: Text(
                        'Continue',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (userAccepted == true) {
      return await Geolocator.requestPermission();
    } else {
      return LocationPermission.denied;
    }
  }
}

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminServiceCatalogService {
  static const String _prefKey = 'cached_admin_service_catalog';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cached in-memory catalog data
  // Structure: { 'car': { 'CategoryName': [ {'name': 'SubName', 'desc': 'SubDesc'} ] } }
  static Map<String, Map<String, List<Map<String, String>>>> _cachedCatalog = {};

  static Map<String, Map<String, List<Map<String, String>>>> get cachedCatalog => _cachedCatalog;

  /// Initializes the local cache from SharedPreferences on app startup,
  /// and listens to Firestore updates in real-time.
  static Future<void> init() async {
    await _loadFromLocalCache();
    _listenToFirestore();
  }

  static Future<void> _loadFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final rawMap = jsonDecode(jsonStr) as Map<String, dynamic>;
        _cachedCatalog = _parseRawMap(rawMap);
        debugPrint("Loaded Admin Service Catalog from local SharedPreferences cache.");
      }
    } catch (e) {
      debugPrint("Error reading local service catalog cache: $e");
    }
  }

  static void _listenToFirestore() {
    _firestore.collection('admin_service_catalog').snapshots().listen((snapshot) async {
      try {
        final Map<String, Map<String, List<Map<String, String>>>> freshCatalog = {
          'car': {},
          'bike': {},
          'ev': {},
        };

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final vehicleType = (data['vehicleType'] as String? ?? 'car').toLowerCase();
          final categoryName = data['category'] as String? ?? 'General';
          final rawSubs = data['subServices'] as List<dynamic>? ?? [];

          final List<Map<String, String>> subs = [];
          for (final item in rawSubs) {
            if (item is Map) {
              subs.add({
                'name': item['name'] as String? ?? '',
                'desc': item['desc'] as String? ?? '',
              });
            }
          }

          if (freshCatalog.containsKey(vehicleType)) {
            freshCatalog[vehicleType]!.putIfAbsent(categoryName, () => []).addAll(subs);
          }
        }

        _cachedCatalog = freshCatalog;
        await _saveToLocalCache(freshCatalog);
        debugPrint("Updated Admin Service Catalog from Firestore and refreshed SharedPreferences cache.");
      } catch (e) {
        debugPrint("Error syncing admin_service_catalog from Firestore: $e");
      }
    });
  }

  static Future<void> _saveToLocalCache(Map<String, Map<String, List<Map<String, String>>>> catalog) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(catalog);
      await prefs.setString(_prefKey, jsonStr);
    } catch (e) {
      debugPrint("Error saving service catalog to local cache: $e");
    }
  }

  static Map<String, Map<String, List<Map<String, String>>>> _parseRawMap(Map<String, dynamic> raw) {
    final Map<String, Map<String, List<Map<String, String>>>> result = {};
    raw.forEach((vType, catMap) {
      if (catMap is Map) {
        final Map<String, List<Map<String, String>>> cMap = {};
        catMap.forEach((cName, subList) {
          if (subList is List) {
            final List<Map<String, String>> sList = [];
            for (final sub in subList) {
              if (sub is Map) {
                sList.add({
                  'name': sub['name']?.toString() ?? '',
                  'desc': sub['desc']?.toString() ?? '',
                });
              }
            }
            cMap[cName.toString()] = sList;
          }
        });
        result[vType] = cMap;
      }
    });
    return result;
  }
}

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatImageCacheService {
  static const String _prefPrefix = 'cached_chat_img_';
  static SharedPreferences? _prefs;

  /// Ensures SharedPreferences instance is ready
  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Synchronously checks if a cached local file exists for [imageUrl].
  static String? getLocalPath(String imageUrl) {
    if (_prefs == null) return null;
    final key = '$_prefPrefix$imageUrl';
    final path = _prefs!.getString(key);
    if (path != null && File(path).existsSync()) {
      return path;
    }
    return null;
  }

  /// Async check ensuring SharedPreferences is initialized
  static Future<String?> getLocalPathAsync(String imageUrl) async {
    final prefs = await _getPrefs();
    final key = '$_prefPrefix$imageUrl';
    final path = prefs.getString(key);
    if (path != null && File(path).existsSync()) {
      return path;
    }
    return null;
  }

  /// Caches a local sender file into persistent app storage and updates SharedPreferences.
  static Future<String?> cacheLocalFile(String imageUrl, String sourceFilePath) async {
    try {
      final prefs = await _getPrefs();
      final appDir = await path_provider.getApplicationDocumentsDirectory();
      final dirPath = '${appDir.path}/chat_images';
      final dir = Directory(dirPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final ext = p.extension(sourceFilePath).isEmpty ? '.jpg' : p.extension(sourceFilePath);
      final fileName = '${imageUrl.hashCode}$ext';
      final targetPath = '$dirPath/$fileName';

      final sourceFile = File(sourceFilePath);
      if (sourceFile.existsSync()) {
        if (sourceFilePath != targetPath) {
          await sourceFile.copy(targetPath);
        }
        await prefs.setString('$_prefPrefix$imageUrl', targetPath);
        debugPrint('[ChatImageCache] Cached local sender image: $imageUrl -> $targetPath');
        return targetPath;
      }
      return null;
    } catch (e) {
      debugPrint('[ChatImageCache] Error caching local sender file: $e');
      return null;
    }
  }

  /// Downloads an image from [imageUrl], saves it locally, and stores mapping in SharedPreferences.
  static Future<String?> downloadAndCache(String imageUrl) async {
    try {
      final cachedPath = await getLocalPathAsync(imageUrl);
      if (cachedPath != null) return cachedPath;

      final prefs = await _getPrefs();
      final appDir = await path_provider.getApplicationDocumentsDirectory();
      final dirPath = '${appDir.path}/chat_images';
      final dir = Directory(dirPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final fileName = '${imageUrl.hashCode}.jpg';
      final targetPath = '$dirPath/$fileName';

      debugPrint('[ChatImageCache] Downloading image for local storage: $imageUrl');
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final file = File(targetPath);
        await file.writeAsBytes(response.bodyBytes);
        await prefs.setString('$_prefPrefix$imageUrl', targetPath);
        debugPrint('[ChatImageCache] Downloaded and cached to SharedPreferences: $targetPath');
        return targetPath;
      }
      return null;
    } catch (e) {
      debugPrint('[ChatImageCache] Error downloading image: $e');
      return null;
    }
  }
}

class ChatMessageCacheService {
  static const String _msgPrefix = 'cached_chat_msgs_v1_';
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Saves list of message maps for [roomId] to SharedPreferences.
  static Future<void> saveMessages(String roomId, List<Map<String, dynamic>> messages) async {
    try {
      final prefs = await _getPrefs();
      final List<Map<String, dynamic>> serializable = [];

      for (final msg in messages) {
        final map = Map<String, dynamic>.from(msg);
        final ts = map['timestamp'];
        if (ts is Timestamp) {
          map['timestamp'] = ts.millisecondsSinceEpoch;
        } else if (ts is DateTime) {
          map['timestamp'] = ts.millisecondsSinceEpoch;
        } else if (ts == null) {
          map['timestamp'] = DateTime.now().millisecondsSinceEpoch;
        }
        serializable.add(map);
      }

      final jsonStr = jsonEncode(serializable);
      await prefs.setString('$_msgPrefix$roomId', jsonStr);
    } catch (e) {
      debugPrint('[ChatMessageCache] Error saving messages: $e');
    }
  }

  /// Loads cached messages for [roomId] from SharedPreferences.
  static Future<List<Map<String, dynamic>>> loadMessages(String roomId) async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = prefs.getString('$_msgPrefix$roomId');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        final List<Map<String, dynamic>> result = [];
        for (final item in jsonList) {
          final map = Map<String, dynamic>.from(item as Map);
          final ts = map['timestamp'];
          if (ts is int) {
            map['timestamp'] = Timestamp.fromMillisecondsSinceEpoch(ts);
          }
          result.add(map);
        }
        return result;
      }
    } catch (e) {
      debugPrint('[ChatMessageCache] Error loading messages: $e');
    }
    return [];
  }
}

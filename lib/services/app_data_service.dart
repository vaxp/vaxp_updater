
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_data.dart';

class AppDataService {
  static const String boxName = 'apps';
  static const String indexUrl = 'https://raw.githubusercontent.com/vaxp/apps_index/main/apps.json';
  late Box<AppData> _box;
  Timer? _backgroundTimer;

  // Initialize Hive and open the box
  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(AppDataAdapter());
    _box = await Hive.openBox<AppData>(boxName);
    // Fetch initial data
    await _fetchRemoteIndex();
    // Start background fetching
    startBackgroundFetch();
  }

  // Start background fetch timer
  void startBackgroundFetch() {
    _backgroundTimer?.cancel();
    _backgroundTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchRemoteIndex();
    });
  }

  // Stop background fetch timer
  void stopBackgroundFetch() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
  }

  // Fetch remote index from GitHub
  Future<void> _fetchRemoteIndex() async {
    try {
      final client = HttpClient();
      final uri = Uri.parse(indexUrl);
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final jsonString = await response.transform(utf8.decoder).join();
        final List<dynamic> jsonList = json.decode(jsonString);
        final now = DateTime.now();
        for (var jsonApp in jsonList) {
          final package = jsonApp['package'];
          final existing = _box.get(package);
          if (existing == null) {
            // New app, not installed
            final app = AppData(
              name: jsonApp['name'],
              package: package,
              currentVersion: '',
              updateJsonUrl: jsonApp['update_json'],
              installed: false,
              lastIndexFetch: now,
            );
            await _box.put(package, app);
          } else {
            // Update index info, preserve installed/version
            existing.lastIndexFetch = now;
            await existing.save();
          }
        }
        // Remove apps not in index
        final indexPackages = jsonList.map((e) => e['package']).toSet();
        for (var app in _box.values) {
          if (!indexPackages.contains(app.package)) {
            await _box.delete(app.package);
          }
        }
      }
    } catch (e) {
      print('Error fetching remote index: $e');
    }
  }

  // Get all apps
  List<AppData> getAllApps() {
    return _box.values.toList();
  }

  // Fetch the remote index directly and return AppData list without using Hive.
  Future<List<AppData>> fetchIndexDirect() async {
    try {
      final client = HttpClient();
      final uri = Uri.parse(indexUrl);
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final jsonString = await response.transform(utf8.decoder).join();
        final List<dynamic> jsonList = json.decode(jsonString);
        final now = DateTime.now();
        final List<AppData> apps = [];
        for (var jsonApp in jsonList) {
          final app = AppData(
            name: jsonApp['name'],
            package: jsonApp['package'],
            currentVersion: '',
            updateJsonUrl: jsonApp['update_json'],
            installed: false,
            lastIndexFetch: now,
          );
          apps.add(app);
        }
        return apps;
      }
    } catch (e) {
      print('Error fetching remote index directly: $e');
    }
    return [];
  }

  // Update app version and mark as installed
  Future<void> updateAppVersion(String package, String newVersion) async {
    final app = _box.get(package);
    if (app != null) {
      app.updateVersion(newVersion);
      await app.save();
    }
  }

  // Mark app as installed
  Future<void> markAppInstalled(String package, String version) async {
    final app = _box.get(package);
    if (app != null) {
      app.markInstalled(version);
      await app.save();
    }
  }

  // Get app by package name
  AppData? getApp(String package) {
    return _box.get(package);
  }

  // Clean up resources
  void dispose() {
    stopBackgroundFetch();
    _box.close();
  }
}
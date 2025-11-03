import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_data.dart';

class AppDataService {
  static const String boxName = 'apps';
  late Box<AppData> _box;

  // Initialize Hive and open the box
  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(AppDataAdapter());
    _box = await Hive.openBox<AppData>(boxName);

    // If the box is empty, load initial data from assets
    if (_box.isEmpty) {
      await _loadInitialData();
    }
  }

  // Load initial data from assets/apps.json
  Future<void> _loadInitialData() async {
    final String jsonString = await rootBundle.loadString('assets/apps.json');
    final List<dynamic> jsonList = json.decode(jsonString);
    
    for (var jsonApp in jsonList) {
      final app = AppData.fromJson(jsonApp);
      await _box.put(app.package, app);
    }
  }

  // Get all apps
  List<AppData> getAllApps() {
    return _box.values.toList();
  }

  // Update app version
  Future<void> updateAppVersion(String package, String newVersion) async {
    final app = _box.get(package);
    if (app != null) {
      app.updateVersion(newVersion);
      await app.save();
    }
  }

  // Get app by package name
  AppData? getApp(String package) {
    return _box.get(package);
  }
}
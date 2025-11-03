import 'package:hive/hive.dart';

part 'app_data.g.dart';

@HiveType(typeId: 0)

class AppData extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String package;

  @HiveField(2)
  String currentVersion;

  @HiveField(3)
  final String updateJsonUrl;

  @HiveField(4)
  bool installed;

  @HiveField(5)
  DateTime? lastIndexFetch;

  AppData({
    required this.name,
    required this.package,
    required this.currentVersion,
    required this.updateJsonUrl,
    this.installed = false,
    this.lastIndexFetch,
  });

  factory AppData.fromJson(Map<String, dynamic> json) {
    return AppData(
      name: json['name'],
      package: json['package'],
      currentVersion: json['current_version'] ?? '',
      updateJsonUrl: json['update_json'],
      installed: json['installed'] ?? false,
      lastIndexFetch: json['lastIndexFetch'] != null
          ? DateTime.tryParse(json['lastIndexFetch'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'package': package,
      'current_version': currentVersion,
      'update_json': updateJsonUrl,
      'installed': installed,
      'lastIndexFetch': lastIndexFetch?.toIso8601String(),
    };
  }

  // Update the version and mark as installed
  void updateVersion(String newVersion) {
    currentVersion = newVersion;
    installed = true;
    save();
  }

  // Mark as installed
  void markInstalled(String version) {
    currentVersion = version;
    installed = true;
    save();
  }

  // Mark as uninstalled
  void markUninstalled() {
    installed = false;
    save();
  }
}
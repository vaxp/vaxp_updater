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

  AppData({
    required this.name,
    required this.package,
    required this.currentVersion,
    required this.updateJsonUrl,
  });

  factory AppData.fromJson(Map<String, dynamic> json) {
    return AppData(
      name: json['name'],
      package: json['package'],
      currentVersion: json['current_version'],
      updateJsonUrl: json['update_json'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'package': package,
      'current_version': currentVersion,
      'update_json': updateJsonUrl,
    };
  }

  // Update the version
  void updateVersion(String newVersion) {
    currentVersion = newVersion;
    save(); // This is provided by HiveObject to save changes
  }
}
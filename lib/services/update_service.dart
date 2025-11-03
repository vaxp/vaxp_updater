import 'dart:convert';
import 'dart:io';
import '../models/app_data.dart';
import 'app_data_service.dart';


// Model class for update information
class UpdateInfo {
  final String version;
  final String changelog;
  final String downloadUrl;

  UpdateInfo({
    required this.version,
    required this.changelog,
    required this.downloadUrl,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'],
      changelog: json['changelog'],
      downloadUrl: json['url'], // Changed from 'download_url' to 'url' to match GitHub's JSON structure
    );
  }
}




class UpdateService {
  final AppDataService _appDataService = AppDataService();

  // Initialize the service
  Future<void> init() async {
    await _appDataService.init();
  }

  // Load all apps (installed and not installed)
  List<AppData> loadApps() {
    return _appDataService.getAllApps();
  }

  // Check for updates for a specific app
  Future<UpdateInfo?> checkForUpdates(AppData app) async {
    try {
      print('Checking for updates for ${app.name}');
      print('Update URL: ${app.updateJsonUrl}');

      final client = HttpClient();
      final uri = Uri.parse(app.updateJsonUrl);
      final request = await client.getUrl(uri);
      final response = await request.close();

      print('Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonString = await response.transform(utf8.decoder).join();
        print('Received JSON: $jsonString');

        final updateInfo = UpdateInfo.fromJson(json.decode(jsonString));
        print('Parsed update info - Version: ${updateInfo.version}');

        if (!app.installed || _isNewerVersion(app.currentVersion, updateInfo.version)) {
          print('New version available: ${updateInfo.version}');
          return updateInfo;
        }
      } else {
        print('Failed to fetch update info: HTTP ${response.statusCode}');
      }

      return null;
    } catch (e, stackTrace) {
      print('Error checking for updates: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  // Download and install update or new app
  Future<bool> downloadAndInstall(AppData app, UpdateInfo updateInfo) async {
    try {
      print('Starting download from: ${updateInfo.downloadUrl}');

      // Download the .deb file
      final client = HttpClient();
      final uri = Uri.parse(updateInfo.downloadUrl);
      final request = await client.getUrl(uri);

      // Add headers for GitHub
      request.headers.add('Accept', 'application/octet-stream');

      print('Sending download request...');
      final response = await request.close();
      print('Download response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        print('Download failed with status: ${response.statusCode}');
        return false;
      }

      // Create temporary file
      final filename = uri.pathSegments.last;
      final file = File('/tmp/$filename');
      print('Downloading to: ${file.path}');

      // Track download progress
      int totalBytes = 0;
      final sink = file.openWrite();
      await for (final chunk in response) {
        sink.add(chunk);
        totalBytes += chunk.length;
        print('Downloaded: ${totalBytes ~/ 1024} KB');
      }
      await sink.close();
      print('Download completed: ${totalBytes ~/ 1024} KB total');

      // Verify file exists and has content
      if (!await file.exists()) {
        print('Error: Downloaded file does not exist');
        return false;
      }

      final fileSize = await file.length();
      print('Downloaded file size: ${fileSize ~/ 1024} KB');

      if (fileSize == 0) {
        print('Error: Downloaded file is empty');
        return false;
      }

      print('Installing package with pkexec...');
      // Install the package using pkexec
      final process = await Process.run(
        'pkexec',
        ['apt', 'install', '-y', file.path],
      );

      print('Installation complete. Exit code: ${process.exitCode}');
      print('stdout: ${process.stdout}');
      print('stderr: ${process.stderr}');

      // Clean up the temporary file
      await file.delete();
      print('Cleaned up temporary file');

      // If installation was successful, update the version in Hive and mark as installed
      if (process.exitCode == 0) {
        await _appDataService.markAppInstalled(app.package, updateInfo.version);
        print('Updated version in database to: ${updateInfo.version}');
      }

      return process.exitCode == 0;
    } catch (e) {
      print('Error installing update: $e');
      return false;
    }
  }

  // Compare version strings to check if remote version is newer
  bool _isNewerVersion(String current, String remote) {
    print('Comparing versions - Current: $current, Remote: $remote');
    final currentParts = current.split('.').map(int.parse).toList();
    final remoteParts = remote.split('.').map(int.parse).toList();

    for (var i = 0; i < 3; i++) {
      final currentPart = currentParts[i];
      final remotePart = remoteParts[i];

      if (remotePart > currentPart) {
        print('Update available: $remote is newer than $current');
        return true;
      } else if (remotePart < currentPart) {
        return false;
      }
    }

    return false;
  }
}
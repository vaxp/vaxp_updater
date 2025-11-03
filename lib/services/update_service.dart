import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
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
  Timer? _backgroundTimer;
  final Set<String> _notifiedUpdates = {};
  bool autoInstall = false;

  // Initialize the service
  Future<void> init() async {
    await _appDataService.init();
    // Start background index & update checks
    startBackgroundChecks();
  }

  // Start periodic background checks (every 10 seconds)
  void startBackgroundChecks() {
    // cancel existing timer if any
    _backgroundTimer?.cancel();
    _backgroundTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _backgroundCheck();
    });
  }

  /// Enable or disable automatic install when an update is found.
  void setAutoInstall(bool enabled) {
    autoInstall = enabled;
  }

  // Stop background checks
  void stopBackgroundChecks() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
  }

  Future<void> _backgroundCheck() async {
    try {
      final apps = await fetchApps();
      for (final app in apps) {
        final update = await checkForUpdates(app);
        if (update != null) {
          final key = '${app.package}@${update.version}';
          if (!_notifiedUpdates.contains(key)) {
            _notifiedUpdates.add(key);
            if (autoInstall) {
              // Attempt to auto-install in background
              final success = await downloadAndInstall(app, update);
              // Notify user of the result
              final title = success
                  ? '${app.name} updated to ${update.version}'
                  : 'Failed to install update for ${app.name}';
              final body = success
                  ? 'Installed version ${update.version} successfully.'
                  : 'Automatic installation failed for ${app.name}.';
              await Process.run('notify-send', [title, body]);
              if (success) {
                // Clear old notifications for this package
                _notifiedUpdates.removeWhere((k) => k.startsWith('${app.package}@'));
              }
            } else {
              await _notifyUser(app, update);
            }
          }
        }
      }
    } catch (e) {
      print('Background check error: $e');
    }
  }

  Future<void> _notifyUser(AppData app, UpdateInfo updateInfo) async {
    try {
      final title = '${app.name} update available';
      final body = 'Version ${updateInfo.version} available. ${updateInfo.changelog}';
      // Use notify-send on Linux for a simple desktop notification
      await Process.run('notify-send', [title, body]);
    } catch (e) {
      print('Failed to send notification: $e');
    }
  }

  // Load all apps (installed and not installed)
  // Fetch apps from remote index directly (avoids relying on local DB)
  Future<List<AppData>> fetchApps() async {
    return await _appDataService.fetchIndexDirect();
  }

  // Synchronous wrapper kept for backward compatibility (reads Hive copy)
  List<AppData> loadApps() {
    return _appDataService.getAllApps();
  }

  // Determine installed version of a package by asking the system (dpkg)
  Future<String> getInstalledVersion(String package) async {
    try {
      // Use dpkg-query to get the installed package version. Use raw string to avoid Dart interpolation.
      final result = await Process.run('dpkg-query', ['-W', r'-f=${Version}\n', package]);
      if (result.exitCode != 0) {
        return '';
      }
      final out = (result.stdout ?? '').toString();
      return out.trim();
    } catch (e) {
      print('Error checking installed version for $package: $e');
      return '';
    }
  }

  // Check for updates for a specific app
  Future<UpdateInfo?> checkForUpdates(AppData app) async {
    try {
      print('Checking for updates for ${app.name}');
      print('Update URL: ${app.updateJsonUrl}');

      // Check installed version from system rather than local DB
      final installedVersion = await getInstalledVersion(app.package);
      print('Installed version for ${app.package}: $installedVersion');

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

        // Compare remote version with installed version detected from system
        if (installedVersion.isEmpty || _isNewerVersion(installedVersion, updateInfo.version)) {
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
        // Verify the new version is actually installed
        final installedVersion = await getInstalledVersion(app.package);
        if (installedVersion.isNotEmpty) {
          // Update both the app data and mark as installed
          await _appDataService.updateAppVersion(app.package, installedVersion);
          await _appDataService.markAppInstalled(app.package, installedVersion);
          print('Updated version in database to: $installedVersion');
          // Clear any notifications recorded for this package (older versions)
          _notifiedUpdates.removeWhere((k) => k.startsWith('${app.package}@'));
          // Update the app object's status
          app.currentVersion = installedVersion;
          app.installed = true;
        }
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
    
    if (current.isEmpty) return true; // Empty current version means not installed
    
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final remoteParts = remote.split('.').map(int.parse).toList();

      // Pad shorter version with zeros to match length
      final maxLength = [currentParts.length, remoteParts.length].reduce(max);
      while (currentParts.length < maxLength) currentParts.add(0);
      while (remoteParts.length < maxLength) remoteParts.add(0);

      // Compare each version part
      for (var i = 0; i < maxLength; i++) {
        final currentPart = currentParts[i];
        final remotePart = remoteParts[i];

        if (remotePart > currentPart) {
          print('Update available: $remote is newer than $current');
          return true;
        } else if (remotePart < currentPart) {
          return false;
        }
      }
      
      return false; // Versions are equal
    } catch (e) {
      print('Error parsing version numbers: $e');
      return false; // On error, assume no update needed
    }
  }
}
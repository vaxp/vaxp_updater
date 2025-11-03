import 'package:flutter/material.dart';

import '../main.dart' show updateService;
import '../models/app_data.dart';
import '../services/update_service.dart' show UpdateInfo;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<AppData> _apps = [];
  Map<String, bool> _checkingStatus = {};
  Map<String, UpdateInfo> _pendingUpdates = {};

  @override
  void initState() {
    super.initState();
    _initializeAndCheck();
  }

  Future<void> _initializeAndCheck() async {
    await _loadApps();
    // Check all apps for updates
    for (final app in _apps) {
      if (!mounted) return;
      await _checkForUpdate(app, showUi: false);
    }
  }

  Future<void> _loadApps() async {
    final apps = updateService.loadApps();
    setState(() {
      _apps = apps;
      _checkingStatus = {
        for (var app in apps) app.package: false,
      };
    });
  }

  Future<void> _checkForUpdate(AppData app, {bool showUi = true}) async {
    setState(() {
      _checkingStatus[app.package] = true;
    });

    try {
      final updateInfo = await updateService.checkForUpdates(app);

      if (updateInfo != null && showUi) {
        if (!mounted) return;
        final bool? shouldProceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(app.installed
                ? 'Update Available for ${app.name}'
                : 'Install ${app.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Version: ${updateInfo.version}'),
                const SizedBox(height: 8),
                const Text('Changelog:'),
                const SizedBox(height: 4),
                Text(updateInfo.changelog),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(app.installed ? 'Update Now' : 'Install'),
              ),
            ],
          ),
        );

        if (shouldProceed == true) {
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Installing...'),
                ],
              ),
            ),
          );

          final success = await updateService.downloadAndInstall(app, updateInfo);

          if (!mounted) return;
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? (app.installed ? 'Update installed successfully!' : 'App installed successfully!')
                    : 'Failed to install',
              ),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
          await _loadApps();
        }
      } else if (updateInfo != null) {
        // Update available but UI is suppressed
        _pendingUpdates[app.package] = updateInfo;
        if (mounted) {
          setState(() {}); // Refresh UI to show notification indicator
        }
      } else if (showUi) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(app.installed
                ? '${app.name} is up to date'
                : 'No install info found'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _checkingStatus[app.package] = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(157, 0, 0, 0),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _apps.length,
        itemBuilder: (context, index) {
          final app = _apps[index];
          final isChecking = _checkingStatus[app.package] ?? false;

          final hasUpdate = _pendingUpdates.containsKey(app.package);
          return Stack(
            children: [
              Card(
                color: const Color.fromARGB(115, 105, 105, 105),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.name,
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          app.installed
                              ? 'Version: ${app.currentVersion}'
                              : 'Not installed',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: isChecking ? null : () => _checkForUpdate(app, showUi: true),
                    icon: isChecking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(app.installed ? Icons.refresh : Icons.download),
                    label: Text(isChecking
                        ? (app.installed ? 'Checking...' : 'Installing...')
                        : (app.installed ? 'Check for Update' : 'Install')),
                  ),
                ],
              ), ),
              ),
              if (hasUpdate)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
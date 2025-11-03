import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../main.dart' show updateService;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<App> _apps = [];
  Map<String, bool> _checkingStatus = {};

  @override
  void initState() {
    super.initState();
    _loadApps();
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

  Future<void> _checkForUpdate(App app) async {
    // Set checking status to true
    setState(() {
      _checkingStatus[app.package] = true;
    });

    try {
      final updateInfo = await updateService.checkForUpdates(app);

      if (updateInfo != null) {
        if (!mounted) return;
        
        // Show update dialog
        final bool? shouldUpdate = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Update Available for ${app.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New version: ${updateInfo.version}'),
                const SizedBox(height: 8),
                const Text('Changelog:'),
                const SizedBox(height: 4),
                Text(updateInfo.changelog),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Update Now'),
              ),
            ],
          ),
        );

        if (shouldUpdate == true) {
          if (!mounted) return;
          
          // Show installation progress
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Installing update...'),
                ],
              ),
            ),
          );

          // Install the update
          final success = await updateService.downloadAndInstall(app, updateInfo);
          
          if (!mounted) return;
          Navigator.pop(context); // Close progress dialog

          // Show result
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? 'Update installed successfully!'
                    : 'Failed to install update',
              ),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${app.name} is up to date'),
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

          return Card(
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
                          'Version: ${app.currentVersion}',
                          style: TextStyle(color: Colors.white70)
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: isChecking ? null : () => _checkForUpdate(app),
                    icon: isChecking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(isChecking ? 'Checking...' : 'Check for Update'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:vaxp_updater/services/update_service.dart';
import 'ui/home_page.dart';

late final UpdateService updateService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  updateService = UpdateService();
  await updateService.init();
  
  runApp(const VaxpUpdater());
}

class VaxpUpdater extends StatelessWidget {
  const VaxpUpdater({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VAXP Updater',
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

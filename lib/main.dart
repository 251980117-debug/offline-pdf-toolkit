import 'package:flutter/material.dart';

import 'app/app_services.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppServices.initialize();
  } catch (_) {
    runApp(const _StartupErrorApp());
    return;
  }
  runApp(const OfflinePdfToolkitApp());
}

class OfflinePdfToolkitApp extends StatelessWidget {
  const OfflinePdfToolkitApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Offline PDF Toolkit',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const HomeScreen(),
      );
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('The PDF engine could not start on this device. '
                  'Restart the app. If this continues, reinstall it.',
                  textAlign: TextAlign.center),
            ),
          ),
        ),
      );
}

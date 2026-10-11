import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/live/live_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Upside-down portrait is excluded: most Android phones won't rotate the UI
  // into it, which would leave preview and frame rotation out of step.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const ProviderScope(child: ErgoCamApp()));
}

class ErgoCamApp extends StatelessWidget {
  const ErgoCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ErgoCam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: const LiveScreen(),
    );
  }
}

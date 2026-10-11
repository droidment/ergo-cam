import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/live/live_screen.dart';

void main() {
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

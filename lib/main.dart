import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_driver/driver_extension.dart'; // ignore: depend_on_referenced_packages

import 'screens/dive_list_screen.dart';

void main() {
  if (const bool.fromEnvironment('ENABLE_FLUTTER_DRIVER')) {
    enableFlutterDriverExtension();
  }
  runApp(const ProviderScope(child: DeepLoggerApp()));
}

class DeepLoggerApp extends StatelessWidget {
  const DeepLoggerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeepLogger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const DiveListScreen(),
    );
  }
}

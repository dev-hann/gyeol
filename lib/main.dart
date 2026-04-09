import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/core/theme/app_theme.dart';
import 'package:gyeol/shared/widgets/app_shell.dart';

void main() {
  runApp(const ProviderScope(child: GyeolApp()));
}

class GyeolApp extends StatelessWidget {
  const GyeolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gyeol',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppShell(),
    );
  }
}

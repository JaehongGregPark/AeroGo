import 'package:flutter/material.dart';

import 'models/enums.dart';
import 'models/user_environment_settings.dart';
import 'screens/home_page.dart';

/// AeroGo's root widget: sets up the [MaterialApp] and hands off to
/// [AeroGoHomePage] with the settings loaded at startup.
class AeroGoApp extends StatelessWidget {
  const AeroGoApp({
    required this.initialEnvironmentSettings,
    super.key,
  });

  final Map<UserRole, UserEnvironmentSettings> initialEnvironmentSettings;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff355c3a),
    );
    return MaterialApp(
      title: 'AeroGo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: colorScheme.surface,
        visualDensity: VisualDensity.standard,
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 0,
          color: colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      home: AeroGoHomePage(
        initialEnvironmentSettings: initialEnvironmentSettings,
      ),
    );
  }
}

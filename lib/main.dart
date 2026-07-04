// Entry point only. Everything else used to live in this single file
// (enums, models, the Go engine, the AI, and every screen/widget -- over
// 2100 lines total). It has been split into lib/app.dart, lib/models/,
// lib/game/, lib/widgets/, and lib/screens/ for maintainability.
import 'package:flutter/material.dart';

import 'app.dart';
import 'models/user_environment_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initialEnvironmentSettings = await loadInitialEnvironmentSettings();
  runApp(
    AeroGoApp(initialEnvironmentSettings: initialEnvironmentSettings),
  );
}

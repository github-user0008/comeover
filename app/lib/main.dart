import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config.dart';
import 'data/prefs.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await Prefs.load();
  final config = AppConfig.load();
  final controller = AppController(baseConfig: config, prefs: prefs);
  runApp(ComeOverApp(controller: controller));
}

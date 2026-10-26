import 'package:flutter/material.dart';

import 'app.dart';
import 'data/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openAppDatabase();
  runApp(ReineApp(db: db));
}

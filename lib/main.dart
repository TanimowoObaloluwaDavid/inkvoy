import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/hive_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveStore.init();
  runApp(const ProviderScope(child: InkvoyApp()));
}
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Lightweight registry of Hive boxes, opened once during bootstrap.
class HiveStore {
  static const String settingsBox = 'settings';
  static const String savedBox = 'saved';
  static const String sessionsBox = 'sessions';
  static const String readerBox = 'reader';

  HiveStore._();

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(settingsBox);
    await Hive.openBox(savedBox);
    await Hive.openBox(sessionsBox);
    await Hive.openBox(readerBox);
  }

  static Box get settings => Hive.box(settingsBox);
  static Box get saved => Hive.box(savedBox);
  static Box get sessions => Hive.box(sessionsBox);
  static Box get reader => Hive.box(readerBox);
}

class Keys {
  static const onboardingDone = 'onboardingDone';
  static const themeMode = 'themeMode';
  static const genres = 'genres';
  static const dailyGoal = 'dailyGoal';
  static const readerPrefs = 'readerPrefs';
}

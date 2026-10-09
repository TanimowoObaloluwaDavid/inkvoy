import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:inkvoy/app.dart';
import 'package:inkvoy/core/storage/hive_store.dart';

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      (await Directory.systemTemp.createTemp('inkvoy_test')).path;

  @override
  Future<String?> getApplicationSupportPath() async =>
      (await Directory.systemTemp.createTemp('inkvoy_test_support')).path;

  @override
  Future<String?> getLibraryPath() async =>
      (await Directory.systemTemp.createTemp('inkvoy_test_lib')).path;

  @override
  Future<String?> getTemporaryPath() async =>
      (await Directory.systemTemp.createTemp('inkvoy_test_tmp')).path;
}

void main() {
  setUpAll(() async {
    PathProviderPlatform.instance = _FakePathProvider();
    TestWidgetsFlutterBinding.ensureInitialized();
    await Hive.initFlutter();
    await HiveStore.init();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  testWidgets('app boots through splash and onboarding without exceptions', (tester) async {
    // Widget tests stub the network; ignore the resulting image 400s, but crash
    // on any real widget/layout error.
    final onError = FlutterError.onError;
    FlutterError.onError = (details) {
      final msg = details.exceptionAsString();
      if (msg.contains('HTTP request failed') ||
          msg.contains('ImageCodec') ||
          msg.contains('Exception: 400') ||
          msg.contains('Invalid statusCode') ||
          msg.contains('failed to precache')) {
        return;
      }
      onError?.call(details);
    };

    await tester.pumpWidget(const ProviderScope(child: InkvoyApp()));
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(tester.takeException(), isNull);
  });
}
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Abstraction over device hardware controls used during Concert Mode.
/// Injectable for deterministic widget tests without platform channels.
abstract interface class ConcertHardwareController {
  Future<void> enableWakeLock();
  Future<void> disableWakeLock();
  Future<void> setAppBrightness(double brightness);
  Future<void> resetAppBrightness();
  Future<void> lockPortrait(bool locked);
}

/// Real device controller backed by `wakelock_plus` and `screen_brightness`.
class DeviceConcertHardwareController implements ConcertHardwareController {
  const DeviceConcertHardwareController();

  @override
  Future<void> enableWakeLock() async {
    try {
      await WakelockPlus.enable();
    } on Object {
      // Ignore on unsupported platforms or tests.
    }
  }

  @override
  Future<void> disableWakeLock() async {
    try {
      await WakelockPlus.disable();
    } on Object {
      // Ignore on unsupported platforms or tests.
    }
  }

  @override
  Future<void> setAppBrightness(double brightness) async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(
        brightness.clamp(0.01, 1.0),
      );
    } on Object {
      // Ignore on unsupported platforms or tests.
    }
  }

  @override
  Future<void> resetAppBrightness() async {
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } on Object {
      // Ignore on unsupported platforms or tests.
    }
  }

  @override
  Future<void> lockPortrait(bool locked) async {
    try {
      if (locked) {
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
        ]);
      } else {
        await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      }
    } on Object {
      // Ignore on unsupported platforms or tests.
    }
  }
}

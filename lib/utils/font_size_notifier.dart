import 'package:fluffychat/config/setting_keys.dart';
import 'package:flutter/foundation.dart';

/// Global notifier for font size factor changes.
/// Updated whenever the user changes font size via settings slider or Ctrl+Scroll.
final ValueNotifier<double> fontSizeNotifier = ValueNotifier<double>(
  AppSettings.fontSizeFactor.value,
);

/// Call this after SharedPreferences is available to sync initial value.
void initFontSizeNotifier() {
  fontSizeNotifier.value = AppSettings.fontSizeFactor.value;
}

/// Update the font size and persist to storage.
Future<void> updateFontSize(double factor) async {
  final clamped = factor.clamp(0.5, 2.5);
  await AppSettings.fontSizeFactor.setItem(clamped);
  fontSizeNotifier.value = clamped;
}

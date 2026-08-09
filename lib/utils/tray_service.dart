import 'dart:io';

import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart' as wm;

class TrayService with TrayListener {
  static final TrayService instance = TrayService._();
  TrayService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    if (!PlatformInfos.isDesktop) return;

    _initialized = true;

    // Init window manager (just ensure initialized, don't prevent close yet)
    await wm.windowManager.ensureInitialized();

    // Only set prevent close if explicitly enabled by user
    if (AppSettings.closeToTray.value) {
      await wm.windowManager.setPreventClose(true);
    }

    // Init tray icon.
    // On Windows, the exe's embedded icon is used by default when no icon is set.
    // We try to set a custom icon but fall back silently on failure.
    try {
      await trayManager.setIcon(
        'assets/logo/mini/logo_mini.png',
        isTemplate: Platform.isMacOS,
      );
    } catch (_) {
      // Ignore: tray will use default icon
    }

    final menu = Menu(
      items: [
        MenuItem(
          key: 'show_window',
          label: 'Show FluffyChat',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'quit',
          label: 'Quit',
        ),
      ],
    );

    await trayManager.setContextMenu(menu);
    await trayManager.setToolTip('FluffyChat');

    trayManager.addListener(this);
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        wm.windowManager.show();
        wm.windowManager.focus();
        break;
      case 'quit':
        trayManager.destroy();
        wm.windowManager.destroy();
        break;
    }
  }

  @override
  void onTrayIconMouseDown() {
    wm.windowManager.show();
    wm.windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  Future<void> setCloseToTray(bool enabled) async {
    await AppSettings.closeToTray.setItem(enabled);
    await wm.windowManager.setPreventClose(enabled);
  }

  Future<void> dispose() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
  }
}

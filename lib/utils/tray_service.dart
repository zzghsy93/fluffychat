import 'dart:io';

import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:flutter/services.dart';
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

    await wm.windowManager.ensureInitialized();

    // Always intercept close → hide to tray
    await wm.windowManager.setPreventClose(true);

    // Find tray icon: Windows requires .ico, macOS/Linux take .png
    String? iconPath;
    if (Platform.isWindows) {
      // Try multiple possible locations for the .ico file
      final candidates = [
        '${Directory.current.path}\\windows\\runner\\resources\\app_icon.ico',
        '${Directory.current.path}\\data\\flutter_assets\\windows\\runner\\resources\\app_icon.ico',
        '${Platform.resolvedExecutable}\\..\\data\\flutter_assets\\windows\\runner\\resources\\app_icon.ico',
      ];
      for (final p in candidates) {
        if (File(p).existsSync()) {
          iconPath = p;
          break;
        }
      }
    } else {
      iconPath = 'assets/logo/mini/logo_mini.png';
    }

    if (iconPath != null) {
      await trayManager.setIcon(iconPath, isTemplate: Platform.isMacOS);
    }

    final menu = Menu(
      items: [
        MenuItem(key: 'show', label: '打开主界面'),
        MenuItem(key: 'settings', label: '设置'),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: '退出'),
      ],
    );
    await trayManager.setContextMenu(menu);
    await trayManager.setToolTip('FluffyChat');

    trayManager.addListener(this);
  }

  // ── TrayListener callbacks ──────────────────────────

  @override
  void onTrayIconMouseDown() {
    // Single-click tray icon → restore window
    wm.windowManager.show();
    wm.windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        wm.windowManager.show();
        wm.windowManager.focus();
        break;
      case 'settings':
        wm.windowManager.show();
        wm.windowManager.focus();
        // Send a platform channel message or use a global key to navigate
        _navigateToSettings();
        break;
      case 'quit':
        trayManager.destroy();
        wm.windowManager.destroy();
        break;
    }
  }

  // ── Navigation helper ───────────────────────────────

  void _navigateToSettings() {
    // Use GoRouter via the app's navigatorKey
    try {
      final router = _appRouter;
      if (router != null) {
        router.go('/rooms/settings');
      }
    } catch (_) {}
  }

  // Set externally by FluffyChatApp after router is created
  static dynamic _appRouter;

  static void registerRouter(dynamic router) {
    _appRouter = router;
  }

  // ── Public API ──────────────────────────────────────

  Future<void> setCloseToTray(bool enabled) async {
    await AppSettings.closeToTray.setItem(enabled);
    await wm.windowManager.setPreventClose(enabled);
  }

  Future<void> dispose() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
  }
}

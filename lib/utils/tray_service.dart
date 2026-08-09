import 'dart:io';

import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayService with TrayListener, WindowListener {
  static final TrayService instance = TrayService._();
  TrayService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    if (!PlatformInfos.isDesktop) return;
    _initialized = true;

    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    _initTray();
  }

  Future<void> _initTray() async {
    // Windows requires .ico; macOS/Linux take .png
    if (Platform.isWindows) {
      // The .ico is bundled as a Flutter asset.
      // In release builds it lives under data/flutter_assets/assets/ relative to exe.
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final candidates = [
        '$exeDir\\data\\flutter_assets\\assets\\tray_icon.ico',
        '$exeDir\\data\\flutter_assets\\packages\\fluffychat\\assets\\tray_icon.ico',
        '${Directory.current.path}\\assets\\tray_icon.ico',
        '${Directory.current.path}\\windows\\runner\\resources\\app_icon.ico',
      ];
      for (final p in candidates) {
        if (File(p).existsSync()) {
          await trayManager.setIcon(p);
          break;
        }
      }
    } else {
      await trayManager.setIcon(
        'assets/logo/mini/logo_mini.png',
        isTemplate: Platform.isMacOS,
      );
    }

    await trayManager.setContextMenu(Menu(
      items: [
        MenuItem(key: 'show', label: '打开主界面'),
        MenuItem(key: 'settings', label: '设置'),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: '退出'),
      ],
    ));
    await trayManager.setToolTip('FluffyChat');
    trayManager.addListener(this);
  }

  // ── WindowListener ──────────────────────────────────

  @override
  void onWindowClose() {
    // Close button → hide to tray instead of exiting
    windowManager.hide();
  }

  // ── TrayListener ────────────────────────────────────

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        windowManager.show();
        windowManager.focus();
        break;
      case 'settings':
        windowManager.show();
        windowManager.focus();
        _navigateToSettings();
        break;
      case 'quit':
        _exit();
        break;
    }
  }

  void _navigateToSettings() {
    try {
      if (_appRouter != null) {
        _appRouter!.go('/rooms/settings');
      }
    } catch (_) {}
  }

  void _exit() {
    trayManager.destroy();
    windowManager.setPreventClose(false);
    windowManager.close();
    windowManager.destroy();
  }

  // ── Public API ──────────────────────────────────────

  static dynamic _appRouter;
  static void registerRouter(dynamic router) {
    _appRouter = router;
  }

  Future<void> setCloseToTray(bool enabled) async {
    await AppSettings.closeToTray.setItem(enabled);
    if (enabled) {
      await windowManager.setPreventClose(true);
    } else {
      await windowManager.setPreventClose(false);
    }
  }

  Future<void> dispose() async {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    await trayManager.destroy();
  }
}

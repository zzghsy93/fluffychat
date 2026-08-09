import 'dart:io';

import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart' as wm;

class TrayService with WidgetsBindingObserver {
  static final TrayService _instance = TrayService._();
  static TrayService get instance => _instance;
  TrayService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    if (!PlatformInfos.isDesktop) return;

    _initialized = true;

    // Init window manager for close-to-tray behavior
    await wm.windowManager.ensureInitialized();

    await wm.windowManager.setPreventClose(
      AppSettings.closeToTray.value,
    );

    wm.windowManager.setCloseInterceptor(() async {
      if (AppSettings.closeToTray.value) {
        await wm.windowManager.hide();
      } else {
        await wm.windowManager.destroy();
      }
    });

    // Init tray
    await trayManager.setIcon(
      Platform.isWindows
          ? 'assets/logo/mini/logo_mini.png'
          : '@mipmap/ic_launcher',
      isTemplate: Platform.isMacOS,
    );

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

    trayManager.addListener(_onTrayEvent);
  }

  void _onTrayEvent(TrayEvent event) {
    if (event is TrayMenuItemEvent) {
      switch (event.menuItem.key) {
        case 'show_window':
          wm.windowManager.show();
          wm.windowManager.focus();
          break;
        case 'quit':
          trayManager.destroy();
          wm.windowManager.destroy();
          break;
      }
    } else if (event is TrayTappedEvent) {
      wm.windowManager.show();
      wm.windowManager.focus();
    }
  }

  Future<void> setCloseToTray(bool enabled) async {
    await AppSettings.closeToTray.setItem(enabled);
    await wm.windowManager.setPreventClose(enabled);
  }

  Future<void> dispose() async {
    await trayManager.destroy();
  }
}

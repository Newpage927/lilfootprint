// 非 Web 平台的 Platform 檢測
import 'dart:io';

bool isDesktopPlatform() {
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}


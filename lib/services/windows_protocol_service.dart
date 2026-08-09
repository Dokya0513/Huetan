import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

/// Registers a custom URL scheme (`fuetan://`) in the Windows Registry so
/// the OS can hand off an OAuth redirect (opened in the system browser) back
/// to this app. Writes under HKEY_CURRENT_USER, which needs no admin
/// elevation. Safe/cheap to call on every launch — re-registers with the
/// current executable path each time, so it stays correct even if the
/// user moves the extracted app folder.
Future<void> registerWindowsProtocol(String scheme) async {
  if (!Platform.isWindows) return;

  final appPath = Platform.resolvedExecutable;
  final protocolRegKey = 'Software\\Classes\\$scheme';
  final regKey = Registry.currentUser.createKey(protocolRegKey);
  regKey.createValue(const RegistryValue.string('URL Protocol', ''));
  regKey
      .createKey('shell\\open\\command')
      .createValue(RegistryValue.string('', '"$appPath" "%1"'));
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/providers.dart';

/// Fire-and-forget cloud backup after a meaningful local change (adding a
/// word, finishing a review session) — these are reliable trigger points,
/// unlike "when the app closes" (see root_shell.dart's doc comment: on
/// Windows in particular, the process can exit before an in-flight async
/// upload finishes). Silently does nothing if signed out or if the upload
/// fails; the user's local data is never at risk either way, this only
/// keeps the cloud copy fresher.
Future<void> autoBackupIfSignedIn(WidgetRef ref) async {
  if (Supabase.instance.client.auth.currentUser == null) return;
  try {
    final db = ref.read(databaseProvider);
    final data = await ref.read(backupServiceProvider).buildExport(db);
    await ref.read(cloudBackupServiceProvider).upload(data);
    await ref.read(settingsServiceProvider).saveLastCloudSyncAt(DateTime.now());
  } catch (_) {
    // Best-effort — the user can still back up manually from Settings.
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads/downloads the same JSON shape BackupService produces, but to
/// Supabase Storage instead of a local file — the cloud counterpart of the
/// existing "export to file" / "import from file" flow, for a signed-in
/// user. Each user's backup lives at "{uid}/backup.json" in the private
/// "backups" bucket; every upload overwrites the previous one (see
/// supabase/backup_storage_setup.sql for the bucket + RLS policies that
/// make this safe to call with only the public anon key).
class CloudBackupService {
  static const _bucket = 'backups';
  static const _fileName = 'backup.json';

  String get _path {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('CloudBackupService requires a signed-in user.');
    }
    return '$uid/$_fileName';
  }

  Future<void> upload(Map<String, dynamic> data) async {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));
    await Supabase.instance.client.storage
        .from(_bucket)
        .uploadBinary(
          _path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/json',
            upsert: true,
          ),
        );
  }

  /// Returns null if the signed-in user has never uploaded a backup.
  Future<Map<String, dynamic>?> download() async {
    try {
      final bytes = await Supabase.instance.client.storage
          .from(_bucket)
          .download(_path);
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } on StorageException catch (e) {
      if (e.statusCode == '404') return null;
      rethrow;
    }
  }
}

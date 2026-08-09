import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Completes Google sign-in via a local loopback HTTP server instead of
/// the fuetan:// custom URL scheme (see windows_protocol_service.dart).
///
/// Chrome silently drops external-protocol handoffs (no prompt, no error)
/// when they happen at the end of an automatic redirect chain rather than
/// from a direct user click — which is exactly what an OAuth callback is,
/// so the custom-scheme approach never completed in practice even though
/// the OS-level protocol registration itself works fine (verified via
/// `Start-Process fuetan://test`). Redirecting to a plain
/// `http://127.0.0.1:<port>/callback` instead sidesteps that entirely:
/// browsers treat it as an ordinary same-machine page load, no external
/// app launch involved. This is the same pattern used by CLI tools like
/// `gh auth login`/`gcloud auth login` (RFC 8252's recommended approach
/// for native-app OAuth).
class OAuthLoopbackService {
  // Fixed rather than randomly chosen, so it can be registered once as a
  // static entry in Supabase's redirect URL allow list instead of needing
  // wildcard matching.
  static const port = 43117;
  static const _path = '/callback';
  static const redirectTo = 'http://127.0.0.1:$port$_path';

  /// Opens the system browser for Google sign-in and waits for the
  /// resulting redirect to land on the local server, then completes the
  /// session. Throws on timeout (5 minutes) or if the server can't bind.
  Future<void> signInWithGoogle() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
      );

      final request = await server
          .firstWhere((r) => r.uri.path == _path)
          .timeout(const Duration(minutes: 5));

      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write(
          '<html><body style="font-family: sans-serif; padding: 2rem;">'
          '<h2>ログインが完了しました</h2>'
          '<p>このタブを閉じてFuetanに戻ってください。</p>'
          '</body></html>',
        );
      await request.response.close();

      await Supabase.instance.client.auth.getSessionFromUrl(request.uri);
    } finally {
      await server.close(force: true);
    }
  }
}

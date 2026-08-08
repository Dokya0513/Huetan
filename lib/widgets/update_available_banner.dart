import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

/// Dismissible notice shown when a newer release exists on GitHub —
/// detection only, no auto-download/auto-install (see
/// update_check_service.dart). Self-hides when there's nothing to show or
/// once dismissed for this session; reappears next launch if still out of
/// date, so it isn't permanently silenced by a single dismissal.
class UpdateAvailableBanner extends ConsumerStatefulWidget {
  const UpdateAvailableBanner({super.key});

  @override
  ConsumerState<UpdateAvailableBanner> createState() =>
      _UpdateAvailableBannerState();
}

class _UpdateAvailableBannerState
    extends ConsumerState<UpdateAvailableBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final update = ref.watch(updateCheckProvider).value;
    if (update == null) return const SizedBox.shrink();

    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary, width: 2),
      ),
      child: Row(
        children: [
          Icon(Icons.system_update_alt, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.updateAvailableTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  l10n.updateAvailableMessage(update.latestVersion),
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => launchUrl(
                    Uri.parse(update.releaseUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(l10n.updateViewButton),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _dismissed = true),
          ),
        ],
      ),
    );
  }
}

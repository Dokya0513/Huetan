import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.read(databaseProvider);
    final backupService = ref.read(backupServiceProvider);
    final data = await backupService.buildExport(db);

    final today = DateTime.now().toIso8601String().split('T').first;
    final path = await FilePicker.platform.saveFile(
      dialogTitle: l10n.exportSaveDialogTitle,
      fileName: 'fuetan_backup_$today.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path == null) return; // user cancelled

    await backupService.saveToFile(path, data);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.exportedSnackbar(path))));
    }
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: l10n.importSelectDialogTitle,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.importConfirmTitle),
        content: Text(l10n.importConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.settingsImportButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final db = ref.read(databaseProvider);
      final backupService = ref.read(backupServiceProvider);
      final data = await backupService.readFromFile(path);
      await backupService.importAndReplace(db, data);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.importSuccessSnackbar)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importFailureSnackbar(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seVolume = ref.watch(seVolumeProvider);
    final voiceVolume = ref.watch(voiceVolumeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(l10n.settingsThemeSectionHeader),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              l10n.settingsDarkModeLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            value: themeMode == ThemeMode.dark,
            onChanged: (value) {
              ref.read(themeModeProvider.notifier).setDarkMode(value);
            },
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          _SectionHeader(l10n.settingsVolumeSectionHeader),
          Text(
            l10n.settingsSoundEffectLabel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.settingsSoundEffectDescription,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Row(
            children: [
              const Icon(Icons.volume_down_outlined),
              Expanded(
                child: Slider(
                  value: seVolume,
                  onChanged: (value) {
                    ref.read(seVolumeProvider.notifier).setVolume(value);
                  },
                ),
              ),
              const Icon(Icons.volume_up_outlined),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.settingsVoiceLabel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.settingsVoiceDescription,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Row(
            children: [
              const Icon(Icons.volume_down_outlined),
              Expanded(
                child: Slider(
                  value: voiceVolume,
                  onChanged: (value) {
                    ref.read(voiceVolumeProvider.notifier).setVolume(value);
                  },
                ),
              ),
              const Icon(Icons.volume_up_outlined),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          _SectionHeader(l10n.settingsDataSectionHeader),
          Text(
            l10n.settingsDataDescription,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportData(context, ref),
                  icon: const Icon(Icons.upload_outlined),
                  label: Text(l10n.settingsExportButton),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _importData(context, ref),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(l10n.settingsImportButton),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          _SectionHeader(l10n.settingsCreditsSectionHeader),
          Text(
            l10n.settingsCreditsCefrText,
            style: TextStyle(
              fontSize: 11,
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              final versionText = info == null ? '' : 'v${info.version}';
              return Text(
                versionText,
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.textSecondary,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: context.colors.primary,
        ),
      ),
    );
  }
}

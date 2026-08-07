import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final backupService = ref.read(backupServiceProvider);
    final data = await backupService.buildExport(db);

    final today = DateTime.now().toIso8601String().split('T').first;
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'バックアップの保存先を選択',
      fileName: 'fuetan_backup_$today.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path == null) return; // user cancelled

    await backupService.saveToFile(path, data);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('エクスポートしました: $path')));
    }
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'バックアップファイルを選択',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('インポートの確認'),
        content: const Text(
          '今のデータ（単語・復習履歴・アクティビティ履歴）はすべて削除され、選択したファイルの内容に置き換わります。よろしいですか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('インポート'),
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
        ).showSnackBar(const SnackBar(content: Text('インポートが完了しました')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('インポートに失敗しました: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seVolume = ref.watch(seVolumeProvider);
    final voiceVolume = ref.watch(voiceVolumeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('テーマ'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'ダークモード',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            value: themeMode == ThemeMode.dark,
            onChanged: (value) {
              ref.read(themeModeProvider.notifier).setDarkMode(value);
            },
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          _SectionHeader('音量'),
          const Text('効果音', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('正解時に鳴るチャイム音', style: Theme.of(context).textTheme.bodySmall),
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
          const Text('読み上げ音声', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            '単語の発音再生・読み上げ（TTS）の音量',
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
          _SectionHeader('データ'),
          Text(
            '単語・復習履歴・アクティビティ履歴をまとめてバックアップ／復元できます',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportData(context, ref),
                  icon: const Icon(Icons.upload_outlined),
                  label: const Text('エクスポート'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _importData(context, ref),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('インポート'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          _SectionHeader('クレジット'),
          Text(
            '『CEFR-J Wordlist Version 1.6』\n'
            '東京外国語大学投野由紀夫研究室\n'
            '(http://www.cefr-j.org/download.html より2026年8月ダウンロード)\n'
            '単語のCEFRレベル判定に使用',
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

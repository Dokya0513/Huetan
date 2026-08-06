import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seVolume = ref.watch(seVolumeProvider);
    final voiceVolume = ref.watch(voiceVolumeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 16),
            const Text('効果音の音量', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              '正解時に鳴るチャイム音',
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
            const SizedBox(height: 16),
            const Text('発音・読み上げの音量', style: TextStyle(fontWeight: FontWeight.w700)),
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
      ),
    );
  }
}

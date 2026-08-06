import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

class WeakWordsScreen extends ConsumerWidget {
  const WeakWordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weakWordsAsync = ref.watch(weakWordsProvider);

    return Scaffold(
      appBar: AppBar(title: const AppTitleRow(title: '苦手単語')),
      body: weakWordsAsync.when(
        data: (words) {
          if (words.isEmpty) {
            return const Center(child: Text('単語が登録されていません'));
          }
          return ListView.separated(
            itemCount: words.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final word = words[index];
              final condition = WordCondition.forBox(
                word.leitnerBox,
                context.colors,
              );
              return ListTile(
                leading: Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: condition.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    condition.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: condition.color,
                    ),
                  ),
                ),
                title: Text(
                  word.english,
                  style: const TextStyle(
                    fontFamily: englishDisplayFontFamily,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(word.japanese ?? '訳未入力'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('エラー: $error')),
      ),
    );
  }
}

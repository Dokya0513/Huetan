import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../providers/providers.dart';
import '../repositories/activity_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/character_card.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(activityLogsProvider);
    final streakAsync = ref.watch(streakProvider);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const AppTitleRow(title: '学習カレンダー')),
      body: logsAsync.when(
        data: (logs) {
          final appOpenDays = <DateTime>{};
          final flashcardDays = <DateTime>{};
          for (final log in logs) {
            final day = dateOnly(log.date);
            if (log.activityType == ActivityType.appOpen.value) {
              appOpenDays.add(day);
            } else if (log.activityType == ActivityType.flashcard.value) {
              flashcardDays.add(day);
            }
          }

          return Column(
            children: [
              streakAsync.when(
                data: (streak) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    streak > 0 ? '🔥 $streak日連続で学習中！' : 'まだ連続記録はありません',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                loading: () => const SizedBox(
                  height: 48,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => const SizedBox.shrink(),
              ),
              TableCalendar(
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 30)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: colors.cardBorder,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                  defaultTextStyle: TextStyle(color: colors.textPrimary),
                  weekendTextStyle: TextStyle(color: colors.textPrimary),
                  outsideTextStyle: TextStyle(color: colors.textSecondary),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleTextStyle: TextStyle(
                    fontFamily: 'Zen Maru Gothic',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: colors.textPrimary,
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: colors.textPrimary,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: colors.textPrimary,
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, events) {
                    final normalized = dateOnly(day);
                    final dots = <Widget>[];
                    if (appOpenDays.contains(normalized)) {
                      dots.add(_dot(colors.primary));
                    }
                    if (flashcardDays.contains(normalized)) {
                      dots.add(_dot(colors.secondary));
                    }
                    if (dots.isEmpty) return null;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: dots,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _legend(colors.primary, 'アプリを開いた日'),
                  const SizedBox(width: 24),
                  _legend(colors.secondary, '暗記カードをやった日'),
                ],
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CharacterCard(
                  adviceProvider: calendarAdviceCandidatesProvider,
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('エラー: $error')),
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      width: 6,
      height: 6,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(color),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

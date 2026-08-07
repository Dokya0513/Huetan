import 'package:drift/drift.dart';

import '../data/database.dart';

enum ActivityType {
  appOpen('app_open'),
  flashcard('flashcard');

  final String value;
  const ActivityType(this.value);
}

DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

class ActivityRepository {
  final AppDatabase db;
  ActivityRepository(this.db);

  /// Records that [type] happened today. Safe to call multiple times per
  /// day — only one row per (date, activityType) is kept.
  Future<void> recordActivity(ActivityType type) {
    return db
        .into(db.activityLogs)
        .insert(
          ActivityLogsCompanion.insert(
            date: dateOnly(DateTime.now()),
            activityType: type.value,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// All logged activity rows, used to drive the calendar view.
  Stream<List<ActivityLog>> watchActivityLogs() {
    return db.select(db.activityLogs).watch();
  }

  /// Number of consecutive days (ending today) that [type] was recorded.
  /// Defaults to counting flashcard study days, since that reflects actual
  /// learning practice rather than just opening the app.
  Future<int> currentStreak({
    ActivityType type = ActivityType.flashcard,
  }) async {
    final rows = await (db.select(
      db.activityLogs,
    )..where((t) => t.activityType.equals(type.value))).get();
    final activeDates = rows.map((r) => dateOnly(r.date)).toSet();

    var streak = 0;
    var day = dateOnly(DateTime.now());
    while (activeDates.contains(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

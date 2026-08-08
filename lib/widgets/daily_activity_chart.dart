import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../repositories/activity_repository.dart' show dateOnly;
import '../theme/app_theme.dart';

/// Two-series line chart (words added vs. distinct words reviewed) for the
/// last 7 days — a "did I put in effort today" view that's always framed
/// positively, since higher counts are simply better with no downside
/// (unlike an accuracy-rate metric, which can misleadingly read as bad on
/// days spent tackling new/hard words).
class DailyActivityChart extends ConsumerWidget {
  const DailyActivityChart({super.key});

  static const _chartHeight = 100.0;
  static const _yAxisWidth = 24.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(dailyActivityCountsProvider);
    final colors = context.colors;

    final maxValue = counts.fold<int>(
      1,
      (max, c) => [max, c.added, c.reviewed].reduce((a, b) => a > b ? a : b),
    );
    final today = dateOnly(DateTime.now());
    final l10n = AppLocalizations.of(context)!;
    final weekdayFormat = DateFormat.E(Localizations.localeOf(context).toString());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.cardBorder, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.last7DaysActivityTitle,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _yAxisWidth,
                height: _chartHeight,
                child: _YAxisLabels(maxValue: maxValue, colors: colors),
              ),
              Expanded(
                child: SizedBox(
                  height: _chartHeight,
                  child: CustomPaint(
                    painter: _LineChartPainter(
                      added: counts.map((c) => c.added).toList(),
                      reviewed: counts.map((c) => c.reviewed).toList(),
                      maxValue: maxValue,
                      addedColor: colors.primary,
                      reviewedColor: colors.secondary,
                      gridColor: colors.cardBorder,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(width: _yAxisWidth),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: counts.map((c) {
                    final isToday = c.day == today;
                    final weekdayLabel = weekdayFormat.format(c.day);
                    return Column(
                      children: [
                        Text(
                          '${c.day.month}/${c.day.day}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isToday
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: isToday
                                ? colors.primary
                                : colors.textSecondary,
                          ),
                        ),
                        Text(
                          '($weekdayLabel)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isToday
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: isToday
                                ? colors.primary
                                : colors.textSecondary,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(colors.primary, l10n.wordsAddedLegend, colors),
              const SizedBox(width: 16),
              _legend(colors.secondary, l10n.wordsReviewedLegend, colors),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label, AppColors colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _YAxisLabels extends StatelessWidget {
  final int maxValue;
  final AppColors colors;
  const _YAxisLabels({required this.maxValue, required this.colors});

  @override
  Widget build(BuildContext context) {
    final mid = (maxValue / 2).round();
    final style = TextStyle(fontSize: 10, color: colors.textSecondary);
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('$maxValue', style: style),
        Text('$mid', style: style),
        Text('0', style: style),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<int> added;
  final List<int> reviewed;
  final int maxValue;
  final Color addedColor;
  final Color reviewedColor;
  final Color gridColor;

  _LineChartPainter({
    required this.added,
    required this.reviewed,
    required this.maxValue,
    required this.addedColor,
    required this.reviewedColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Leave a little headroom so a max-value point's dot isn't clipped.
    const topPadding = 6.0;
    const bottomPadding = 6.0;
    final plotHeight = size.height - topPadding - bottomPadding;

    // Gridlines matching the 0 / mid / max Y-axis labels.
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (final fraction in [0.0, 0.5, 1.0]) {
      final y = topPadding + plotHeight * (1 - fraction);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    List<Offset> pointsFor(List<int> values) {
      final n = values.length;
      return List.generate(n, (i) {
        final x = n == 1 ? size.width / 2 : size.width * i / (n - 1);
        final y = topPadding + plotHeight - (values[i] / maxValue) * plotHeight;
        return Offset(x, y);
      });
    }

    void drawSeries(List<int> values, Color color) {
      final points = pointsFor(values);
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, linePaint);

      final dotPaint = Paint()..color = color;
      for (final point in points) {
        canvas.drawCircle(point, 3.5, dotPaint);
      }
    }

    drawSeries(added, addedColor);
    drawSeries(reviewed, reviewedColor);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.added != added ||
        oldDelegate.reviewed != reviewed ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.addedColor != addedColor ||
        oldDelegate.reviewedColor != reviewedColor;
  }
}

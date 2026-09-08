import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../core/app_state.dart';
import '../../core/journal.dart';
import '../../core/strings.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../ui/atmosphere.dart';
import '../../ui/glass.dart';
import '../counsellor/engine.dart';

/// Seven days of check-ins, in order, oldest first.
@immutable
class PulseWeek {
  const PulseWeek({required this.days, required this.untangles});

  /// One entry per day for the last seven, null where there was no check-in.
  final List<({DateTime day, DailyPulse? pulse})> days;

  /// Untangles saved in the same window, as a second signal alongside the
  /// scores — a bad week with three repairs in it is not the same shape as a
  /// bad week with none.
  final int untangles;

  List<int> get scores => [
        for (final d in days)
          if (d.pulse != null) d.pulse!.connection,
      ];

  List<String> get words => [
        for (final d in days)
          if (d.pulse != null && d.pulse!.word.trim().isNotEmpty)
            d.pulse!.word.trim(),
      ];

  int get checkInCount => scores.length;

  double? get average =>
      scores.isEmpty ? null : scores.reduce((a, b) => a + b) / scores.length;

  /// Enough of a week to say anything honest about. Two points is a line, not
  /// a trend, so the report waits for three.
  bool get isReportable => checkInCount >= 3;

  static PulseWeek from(AppState app, List<JournalEntry> journal) {
    final now = DateTime.now();
    final byDay = {for (final p in app.pulses) p.day: p};
    final days = [
      for (var i = 6; i >= 0; i--)
        (
          day: now.subtract(Duration(days: i)),
          pulse: byDay[AppState.dayKey(now.subtract(Duration(days: i)))],
        ),
    ];
    final cutoff = now.subtract(const Duration(days: 7));
    return PulseWeek(
      days: days,
      untangles: journal
          .where((e) =>
              (e.kind == JournalKind.untangle || e.kind == JournalKind.repair) &&
              e.createdAt.isAfter(cutoff))
          .length,
    );
  }
}

final pulseWeekProvider = Provider<PulseWeek>((ref) {
  return PulseWeek.from(
      ref.watch(appStateProvider), ref.watch(journalProvider));
});

final _reflectionProvider = FutureProvider.autoDispose<WeeklyReflection>((ref) {
  final week = ref.watch(pulseWeekProvider);
  final ctx = ref.watch(counsellorContextProvider);
  if (!week.isReportable) {
    throw const CounsellorException('not enough check-ins');
  }
  return ref.read(counsellorEngineProvider).weeklyReflection(
        scores: week.scores,
        words: week.words,
        untangles: week.untangles,
        ctx: ctx,
      );
});

/// The weekly report. Generated on the phone, from data that never left it.
class WeeklyPulseScreen extends ConsumerWidget {
  const WeeklyPulseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context, ref);
    final app = ref.watch(appStateProvider);
    final week = ref.watch(pulseWeekProvider);
    final t = Theme.of(context).textTheme;
    final surface = context.surface;

    return StageTheme(
      stage: ResolutionStage.calm,
      child: Scaffold(
        body: Atmosphere(
          background: Backgrounds.calm,
          child: Column(
            children: [
              GlassTopBar(
                title: s.weeklyPulse,
                onBack: () => context.pop(),
                trailing: StatusPill(
                  label: s.onThisPhoneOnly,
                  icon: Icons.lock_outline_rounded,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 40),
                  children: [
                    Text(s.weeklyPulseSub,
                        style: t.bodySmall
                            ?.copyWith(fontSize: 15, color: surface.ink2)),
                    const SizedBox(height: 18),
                    _Chart(week: week, s: s, language: app.language.code),
                    const SizedBox(height: 16),
                    if (!week.isReportable)
                      GlassPanel(
                        strong: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.weeklyPulseEmpty, style: t.bodyLarge),
                            const SizedBox(height: 14),
                            // A dead end before: it said "not enough
                            // check-ins" with nothing to tap.
                            GlassButton(
                              label: s.checkinLabel,
                              icon: Icons.favorite_border_rounded,
                              expand: false,
                              onPressed: () => context.go(Routes.today),
                            ),
                          ],
                        ),
                      )
                    else
                      _Reflection(s: s),
                    if (week.words.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      GlassPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Eyebrow(s.weeklyWords),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final w in week.words) GlassChip(label: w),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Reflection extends ConsumerWidget {
  const _Reflection({required this.s});

  final S s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final result = ref.watch(_reflectionProvider);

    return result.when(
      loading: () => GlassPanel(
        strong: true,
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.stage.accent,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                s.weeklyPulseWorking,
                style: t.bodyMedium?.copyWith(color: context.surface.ink2),
              ),
            ),
          ],
        ),
      ),
      error: (e, _) => GlassPanel(
        strong: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              e is CounsellorException
                  ? s.weeklyPulseEmpty
                  : s.counsellorFailed,
              style: t.bodyLarge,
            ),
            const SizedBox(height: 12),
            GlassChip(
              label: s.retry,
              icon: Icons.refresh_rounded,
              onTap: () => ref.invalidate(_reflectionProvider),
            ),
          ],
        ),
      ),
      data: (r) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassPanel(
            strong: true,
            child: Text(
              r.reflection,
              style: t.bodyLarge?.copyWith(fontSize: 17, height: 1.55),
            ),
          ),
          if (r.suggestion.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            TintPanel(
              label: s.weeklyOneThing,
              color: context.stage.accent,
              child: Text(r.suggestion),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GlassChip(
                  label: s.copy,
                  icon: Icons.copy_rounded,
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: r.suggestion));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(s.copied)));
                  },
                ),
                GlassChip(
                  label: s.learnSaveToJournal,
                  icon: Icons.bookmark_border_rounded,
                  onTap: () async {
                    await ref.read(journalProvider.notifier).add(
                          kind: JournalKind.note,
                          title: s.weeklyOneThing,
                          body: r.suggestion,
                        );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(s.saved)));
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Seven bars. No axes, no gridlines, no numbers on the bars — this is a shape
/// to recognise, not a dataset to read. Missing days are drawn as gaps rather
/// than as zeroes, because "did not check in" is not "felt nothing".
class _Chart extends StatelessWidget {
  const _Chart({required this.week, required this.s, required this.language});

  final PulseWeek week;
  final S s;
  final String language;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final surface = context.surface;
    final st = context.stage;
    final average = week.average;
    final dayFormat = DateFormat('EEE', language);

    return GlassPanel(
      strong: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Eyebrow(s.checkinsThisWeek(week.checkInCount))),
              if (average != null)
                Text(
                  s.weeklyAverage(average.toStringAsFixed(1)),
                  style: t.labelLarge?.copyWith(fontSize: 14, color: st.accent),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Bars and labels are laid out separately rather than sharing one
          // fixed height: at a larger text size the label grew and the whole
          // chart overflowed by a few pixels.
          SizedBox(
            height: 104,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in week.days)
                  Expanded(
                    child: Semantics(
                      label: d.pulse == null
                          ? dayFormat.format(d.day)
                          : '${dayFormat.format(d.day)}, ${d.pulse!.connection}',
                      excludeSemantics: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: d.pulse != null
                            ? Container(
                                height: 16 + (d.pulse!.connection - 1) * 22.0,
                                decoration: BoxDecoration(
                                  color: st.accent.withValues(
                                    alpha: 0.25 + d.pulse!.connection * 0.13,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              )
                            // A gap, not a zero: "did not check in" is not
                            // "felt nothing".
                            : Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: surface.hairline,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final d in week.days)
                Expanded(
                  child: Text(
                    dayFormat.format(d.day),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: t.bodySmall?.copyWith(
                      fontSize: 11,
                      color: surface.ink2,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

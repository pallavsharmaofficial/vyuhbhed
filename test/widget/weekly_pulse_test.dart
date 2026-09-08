import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/core/app_state.dart';
import 'package:vyuhbhed/features/pulse/weekly_pulse_screen.dart';

import '../support/harness.dart';

String pulsesJson(List<(int daysAgo, int score, String word)> entries) {
  final now = DateTime.now();
  final rows = entries.map((e) {
    final day = AppState.dayKey(now.subtract(Duration(days: e.$1)));
    return '{"day":"$day","connection":${e.$2},"word":"${e.$3}"}';
  });
  return '[${rows.join(',')}]';
}

void main() {
  group('PulseWeek', () {
    test('needs three check-ins before it will say anything', () {
      const twoDays = AppState(
        pulses: [
          DailyPulse(day: 'x', connection: 3),
          DailyPulse(day: 'y', connection: 4),
        ],
      );
      expect(PulseWeek.from(twoDays, const []).isReportable, isFalse);
    });

    test('always covers exactly seven days, gaps included', () {
      final week = PulseWeek.from(const AppState(), const []);
      expect(week.days, hasLength(7));
      expect(week.scores, isEmpty);
      expect(week.average, isNull);
    });

    test('ignores check-ins older than the window', () {
      final now = DateTime.now();
      final state = AppState(
        pulses: [
          DailyPulse(day: AppState.dayKey(now), connection: 5),
          DailyPulse(
            day: AppState.dayKey(now.subtract(const Duration(days: 30))),
            connection: 1,
          ),
        ],
      );
      final week = PulseWeek.from(state, const []);
      expect(week.scores, [5]);
      expect(week.average, 5);
    });

    test('orders days oldest first, so a trend reads left to right', () {
      final now = DateTime.now();
      final state = AppState(
        pulses: [
          DailyPulse(day: AppState.dayKey(now), connection: 5),
          DailyPulse(
            day: AppState.dayKey(now.subtract(const Duration(days: 6))),
            connection: 1,
          ),
        ],
      );
      expect(PulseWeek.from(state, const []).scores, [1, 5]);
    });
  });

  testWidgets('a quiet week says so instead of inventing a report',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());

    app.push('/week');
    await tester.pumpAndSettle();

    expect(find.textContaining('Check in a few days'), findsOneWidget);
  });

  testWidgets('a real week renders the chart and an on-device reflection',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(
      tester,
      seed: {
        ...onboardedSeed(),
        'saath.pulses': pulsesJson([
          (0, 4, 'warm'),
          (1, 3, ''),
          (2, 2, 'tense'),
          (4, 5, 'close'),
        ]),
      },
    );

    app.push('/week');
    await tester.pumpAndSettle();

    expect(findEyebrow('4 of 7 check-ins'), findsOneWidget);
    expect(find.text('Average 3.5'), findsOneWidget);
    // The words the user chose come back to them.
    expect(find.text('warm'), findsWidgets);
    expect(find.text('tense'), findsWidgets);
    expect(findEyebrow('One thing this week'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('is reachable from the Today tile', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());

    await tapVisible(tester, find.textContaining('See your week'));
    expect(app.location, '/week');
  });
}

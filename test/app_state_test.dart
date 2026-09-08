import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/core/app_state.dart';
import 'package:vyuhbhed/core/key_value_store.dart';

void main() {
  group('AppState.copyWith', () {
    test('carries every field forward when nothing is passed', () {
      const original = AppState(
        language: AppLanguage.hi,
        themeMode: ThemeMode.dark,
        onboarded: true,
        userName: 'Asha',
        partnerName: 'Vikram',
        relationshipStage: RelationshipStage.married,
        originStory: 'a reason',
        safetyNoticeSeen: true,
      );

      final copy = original.copyWith();

      expect(copy.language, AppLanguage.hi);
      expect(copy.themeMode, ThemeMode.dark);
      expect(copy.onboarded, isTrue);
      expect(copy.userName, 'Asha');
      expect(copy.partnerName, 'Vikram');
      expect(copy.relationshipStage, RelationshipStage.married);
      expect(copy.originStory, 'a reason');
      expect(copy.safetyNoticeSeen, isTrue);
    });

    test('can clear the nullable relationship stage', () {
      // Passing `null` to a `?? this.x` copyWith is a no-op — the field was
      // unclearable before the explicit flag existed.
      const original = AppState(relationshipStage: RelationshipStage.dating);
      expect(original.copyWith(relationshipStage: null).relationshipStage,
          RelationshipStage.dating);
      expect(original.copyWith(clearRelationshipStage: true).relationshipStage,
          isNull);
    });
  });

  group('dayKey', () {
    test('zero-pads so keys sort and compare correctly', () {
      expect(AppState.dayKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(AppState.dayKey(DateTime(2026, 11, 15)), '2026-11-15');
    });

    test('distinguishes days that an unpadded format would collide on', () {
      // '2026-1-11' and '2026-11-1' are different days; a naive concat of
      // year-month-day without padding gives '2026-1-11' for both readings.
      expect(AppState.dayKey(DateTime(2026, 1, 11)),
          isNot(AppState.dayKey(DateTime(2026, 11, 1))));
    });
  });

  group('check-ins', () {
    late InMemoryStore store;
    late AppStateNotifier notifier;

    setUp(() {
      store = InMemoryStore();
      notifier = AppStateNotifier(store);
    });

    test('records today and exposes it', () async {
      await notifier.checkIn(connection: 4, word: 'tired');

      expect(notifier.state.todayConnection, 4);
      expect(notifier.state.todayWord, 'tired');
      expect(notifier.state.pulses, hasLength(1));
    });

    test('a second check-in replaces today rather than adding a row', () async {
      await notifier.checkIn(connection: 2);
      await notifier.checkIn(connection: 5);

      expect(notifier.state.pulses, hasLength(1));
      expect(notifier.state.todayConnection, 5);
    });

    test('keeps the word when only the score changes', () async {
      await notifier.checkIn(connection: 2, word: 'tense');
      await notifier.checkIn(connection: 4);

      expect(notifier.state.todayWord, 'tense');
      expect(notifier.state.todayConnection, 4);
    });

    test('setTodayWord does nothing before a score exists', () async {
      await notifier.setTodayWord('warm');
      expect(notifier.state.pulses, isEmpty);
    });

    test('clamps out-of-range scores', () async {
      await notifier.checkIn(connection: 9);
      expect(notifier.state.todayConnection, 5);
    });

    test('survives a reload from the store', () async {
      await notifier.checkIn(connection: 3, word: 'ok');

      final reloaded = AppStateNotifier.load(store);
      expect(reloaded.todayConnection, 3);
      expect(reloaded.todayWord, 'ok');
    });
  });

  group('checkInsThisWeek', () {
    test('counts only the last seven days', () {
      final now = DateTime.now();
      final state = AppState(pulses: [
        for (final offset in [0, 1, 3, 6, 7, 40])
          DailyPulse(
            day: AppState.dayKey(now.subtract(Duration(days: offset))),
            connection: 3,
          ),
      ]);

      // 0, 1, 3 and 6 days ago are inside the window; 7 and 40 are not.
      expect(state.checkInsThisWeek, 4);
    });

    test('is zero for a new user', () {
      expect(const AppState().checkInsThisWeek, 0);
    });
  });

  group('persistence', () {
    test('round-trips every persisted field', () async {
      final store = InMemoryStore();
      final notifier = AppStateNotifier(store);

      await notifier.setLanguage(AppLanguage.hi);
      await notifier.setThemeMode(ThemeMode.dark);
      await notifier.setNames(user: '  Asha  ', partner: ' Vikram ');
      await notifier.setRelationshipStage(RelationshipStage.longDistance);
      await notifier.setOriginStory('  because he stayed  ');
      await notifier.completeOnboarding();
      await notifier.markSafetyNoticeSeen();

      final reloaded = AppStateNotifier.load(store);
      expect(reloaded.language, AppLanguage.hi);
      expect(reloaded.themeMode, ThemeMode.dark);
      expect(reloaded.userName, 'Asha', reason: 'names are trimmed on write');
      expect(reloaded.partnerName, 'Vikram');
      expect(reloaded.relationshipStage, RelationshipStage.longDistance);
      expect(reloaded.originStory, 'because he stayed');
      expect(reloaded.onboarded, isTrue);
      expect(reloaded.safetyNoticeSeen, isTrue);
    });

    test('enum ids are stable strings, not ordinals', () async {
      final store = InMemoryStore();
      await AppStateNotifier(store)
          .setRelationshipStage(RelationshipStage.roughPatch);

      // Reordering the enum must not silently re-map stored data.
      expect(store.getString('saath.relationshipStage'), 'rough_patch');
    });

    test('a corrupt pulse blob degrades to empty instead of failing to launch',
        () {
      final store = InMemoryStore({'saath.pulses': '{not json at all'});
      expect(AppStateNotifier.load(store).pulses, isEmpty);
    });

    test('skips malformed pulse rows but keeps the good ones', () {
      final store = InMemoryStore({
        'saath.pulses':
            '[{"day":"2026-09-01","connection":3,"word":"ok"},{"day":42},null]',
      });
      expect(AppStateNotifier.load(store).pulses, hasLength(1));
    });

    test('an unknown language code falls back to English', () {
      final store = InMemoryStore({'saath.language': 'ta'});
      expect(AppStateNotifier.load(store).language, AppLanguage.en);
    });

    test('reset clears only Saath keys', () async {
      final store = InMemoryStore({'someone.elses.key': 'keep me'});
      final notifier = AppStateNotifier(store);
      await notifier.setNames(user: 'Asha', partner: 'Vikram');
      await notifier.completeOnboarding();

      await notifier.reset();

      expect(notifier.state.onboarded, isFalse);
      expect(notifier.state.userName, isEmpty);
      expect(store.getString('someone.elses.key'), 'keep me');
    });
  });

  group('display names', () {
    test('never render an empty partner name into a sentence', () {
      expect(const AppState().partnerOrDefault, 'your partner');
      expect(
          const AppState(partnerName: '   ').partnerOrDefault, 'your partner');
      expect(const AppState(language: AppLanguage.hi).partnerOrDefault,
          'आपका साथी');
      expect(const AppState(partnerName: 'Vikram').partnerOrDefault, 'Vikram');
    });
  });
}

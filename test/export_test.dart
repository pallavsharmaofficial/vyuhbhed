import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/core/app_state.dart';
import 'package:vyuhbhed/core/couple_space.dart';
import 'package:vyuhbhed/core/journal.dart';
import 'package:vyuhbhed/features/settings/export.dart';

void main() {
  test('the export is valid JSON containing everything the app holds', () {
    const app = AppState(
      language: AppLanguage.hi,
      onboarded: true,
      userName: 'Asha',
      partnerName: 'Vikram',
      relationshipStage: RelationshipStage.married,
      originStory: 'he stayed',
      pulses: [DailyPulse(day: '2026-09-01', connection: 4, word: 'warm')],
    );
    final journal = [
      JournalEntry(
        id: '1',
        createdAt: DateTime(2026, 9, 1, 21, 30),
        kind: JournalKind.untangle,
        title: 'the dishes',
        body: 'body',
        ask: 'can we pick a time?',
        themes: const [JournalTheme.time],
      ),
    ];

    final couple = CoupleSpace(
      loveMap: [
        LoveMapFact(
          id: 'f1',
          prompt: 'What worries them?',
          answer: 'his mother',
          updatedAt: DateTime(2026, 9, 1),
        ),
      ],
      goals: [
        SharedGoal(
          id: 'g1',
          text: 'walk after dinner',
          createdAt: DateTime(2026, 9, 1),
        ),
      ],
      dates: const [
        ImportantDate(
            id: 'd1', label: 'Married', month: 12, day: 2, year: 2018),
      ],
    );

    final decoded =
        jsonDecode(buildExportJson(app: app, journal: journal, couple: couple))
            as Map<String, Object?>;

    expect(decoded['app'], 'Saath');
    expect(decoded['version'], isNotEmpty);
    expect(DateTime.tryParse(decoded['exportedAt']! as String), isNotNull);

    final profile = decoded['profile']! as Map<String, Object?>;
    expect(profile['userName'], 'Asha');
    expect(profile['partnerName'], 'Vikram');
    expect(profile['originStory'], 'he stayed');
    expect(profile['language'], 'hi');
    expect(profile['relationshipStage'], 'married');
    expect((profile['pulses']! as List).single,
        {'day': '2026-09-01', 'connection': 4, 'word': 'warm'});

    final us = decoded['us']! as Map<String, Object?>;
    expect((us['goals']! as List).single,
        containsPair('text', 'walk after dinner'));
    expect(
        (us['loveMap']! as List).single, containsPair('answer', 'his mother'));

    final entries = decoded['journal']! as List;
    expect(entries, hasLength(1));
    expect((entries.single as Map)['ask'], 'can we pick a time?');
    expect((entries.single as Map)['themes'], ['time']);
  });

  test('the Us page is in the export too — "everything" has to mean it', () {
    final decoded =
        jsonDecode(buildExportJson(app: const AppState(), journal: const []))
            as Map<String, Object?>;
    expect(decoded['us'], isA<Map<String, Object?>>());
  });

  test('an empty install still produces valid, readable JSON', () {
    final decoded =
        jsonDecode(buildExportJson(app: const AppState(), journal: const []))
            as Map<String, Object?>;
    expect(decoded['journal'], isEmpty);
    expect((decoded['profile']! as Map)['userName'], '');
  });

  test('is indented, because a user is meant to be able to read it', () {
    expect(buildExportJson(app: const AppState(), journal: const []),
        contains('\n  '));
  });
}

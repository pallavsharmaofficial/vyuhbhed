import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/core/journal.dart';
import 'package:vyuhbhed/features/learn/learn_screen.dart';

import '../support/harness.dart';

void main() {
  testWidgets('the header counts what the person has done, and it persists',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    app.go('/learn');
    await tester.pumpAndSettle();

    expect(findEyebrow('Learn · 0 of 15 done'), findsOneWidget);
    expect(find.text('Show the exercise'), findsWidgets);

    await tester.tap(find.text('Show the exercise').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done this').first);
    await tester.pumpAndSettle();

    expect(findEyebrow('Learn · 1 of 15 done'), findsOneWidget);
    expect(LearnProgress.load(app.store), hasLength(1));
  });

  testWidgets('an exercise can be kept in the journal', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    app.go('/learn');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show the exercise').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save to journal').first);
    await tester.pumpAndSettle();

    final entries = app.container.read(journalProvider);
    expect(entries, hasLength(1));
    expect(entries.first.kind, JournalKind.note);
    expect(entries.first.title, learnCards.first.title);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/core/journal.dart';

import '../support/harness.dart';

void main() {
  const vent = 'he said do whatever you want and walked out';

  testWidgets('renders all four columns and the one sentence', (tester) async {
    usePhoneSurface(tester);
    // Asserting through the semantics tree rather than the rendered glyphs:
    // the eyebrow labels are visually uppercased, and a screen reader is
    // supposed to hear the real words.
    final handle = tester.ensureSemantics();
    final app = await pumpApp(tester, seed: onboardedSeed());

    app.push('/untangle', extra: vent);
    await tester.pumpAndSettle();

    for (final column in [
      'What happened',
      'What I assumed',
      'What I felt',
      'What I need',
    ]) {
      expect(findEyebrow(column), findsOneWidget, reason: column);
      // The screen reader hears the real words, not the uppercased ones.
      expect(find.bySemanticsLabel(RegExp(RegExp.escape(column))), findsWidgets,
          reason: '$column semantics');
    }
    // The sentence sits below the fold on a 390×844 screen, and a ListView
    // does not build what it has not scrolled to.
    final askLabel = findEyebrow('One sentence you could say');
    await tester.scrollUntilVisible(askLabel, 240,
        scrollable: find.byType(Scrollable).last);
    expect(askLabel, findsOneWidget);
    handle.dispose();
  });

  testWidgets('Save writes the result to the journal', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());

    app.push('/untangle', extra: vent);
    await tester.pumpAndSettle();

    expect(app.container.read(journalProvider), isEmpty);

    final save = find.text('Save');
    await tester.scrollUntilVisible(save, 240,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(save);
    await tester.pumpAndSettle();

    // "Save" used to just pop the screen and discard the result.
    final entries = app.container.read(journalProvider);
    expect(entries, hasLength(1));
    expect(entries.single.kind, JournalKind.untangle);
    expect(entries.single.ask, isNotEmpty);
    expect(entries.single.body, contains('What I need'));

    // And it survives a relaunch.
    expect(JournalStore.load(app.store), hasLength(1));
  });

  testWidgets(
      'a restored route with no vent explains itself instead of erroring',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());

    // Android process death drops go_router's `extra`.
    app.push('/untangle');
    await tester.pumpAndSettle();

    expect(
        find.textContaining('Tell Saath what happened first'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a disclosure in the vent goes to safety, not to four tidy columns',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());

    app.push('/untangle', extra: 'he hit me and then said it was my fault');
    await tester.pumpAndSettle();

    expect(app.location, '/safety');
    expect(find.text('What happened'), findsNothing);
  });

  testWidgets('renders in Hindi when the app is in Hindi', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed(language: 'hi'));

    app.push('/untangle', extra: vent);
    await tester.pumpAndSettle();

    // Devanagari has no case, so the eyebrow keeps the label as written.
    expect(findEyebrow('क्या हुआ'), findsOneWidget);
    expect(findEyebrow('मुझे क्या चाहिए'), findsOneWidget);
  });
}

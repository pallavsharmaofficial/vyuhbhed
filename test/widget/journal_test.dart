import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/core/journal.dart';
import 'package:vyuhbhed/ui/glass.dart';

import '../support/harness.dart';

void main() {
  testWidgets(
      'an empty journal explains itself instead of showing a blank list',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());

    app.push('/journal');
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing saved yet'), findsOneWidget);
  });

  testWidgets('shows saved entries with their ask and themes', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    await app.container.read(journalProvider.notifier).add(
      kind: JournalKind.untangle,
      title: 'He walked out of the room',
      body: 'What I need: to know it matters',
      ask: 'Can we pick a time tonight?',
      themes: [JournalTheme.time, JournalTheme.trust],
    );

    app.push('/journal');
    await tester.pumpAndSettle();

    expect(find.text('He walked out of the room'), findsOneWidget);
    expect(find.text('Can we pick a time tonight?'), findsOneWidget);
    expect(find.text('Time · 1'), findsOneWidget);
    expect(find.text('Trust · 1'), findsOneWidget);
  });

  testWidgets('deleting an entry removes it from screen and from disk',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    await app.container
        .read(journalProvider.notifier)
        .add(kind: JournalKind.untangle, title: 'the dishes', body: '');

    app.push('/journal');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(app.container.read(journalProvider), isEmpty);
    expect(JournalStore.load(app.store), isEmpty);
    expect(find.textContaining('Nothing saved yet'), findsOneWidget);
  });

  testWidgets('themes can be corrected by the person who lived it',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    await app.container.read(journalProvider.notifier).add(
      kind: JournalKind.untangle,
      title: 'the dishes',
      body: 'b',
      // What the keyword pass guessed.
      themes: [JournalTheme.time],
    );

    app.push('/journal');
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Trust'));

    final themes = app.container.read(journalProvider).single.themes;
    expect(themes, containsAll([JournalTheme.time, JournalTheme.trust]));
    expect(JournalStore.load(app.store).single.themes, hasLength(2));
  });

  testWidgets('a reflection is generated on request and kept', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    await app.container.read(journalProvider.notifier).add(
          kind: JournalKind.untangle,
          title: 'the dishes',
          body: 'What I need: to know it matters',
          ask: 'Can we pick a time tonight?',
          at: DateTime.now().subtract(const Duration(days: 9)),
        );

    app.push('/journal');
    await tester.pumpAndSettle();

    // Not generated at save time: the value is in the distance.
    await tapVisible(tester, find.text('What does this look like now?'));

    final entry = app.container.read(journalProvider).single;
    expect(entry.reflection, isNotEmpty);
    expect(entry.reflection, contains('A week ago'));
    expect(JournalStore.load(app.store).single.reflection, isNotEmpty);
  });

  testWidgets('reachable from Today once something is saved', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());

    await tapVisible(tester, find.byIcon(Icons.auto_stories_outlined));
    expect(app.location, '/journal');
  });

  testWidgets('a deleted entry can be undone from the snackbar', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    await app.container.read(journalProvider.notifier).add(
        kind: JournalKind.untangle,
        title: 'the dishes',
        body: 'it was never about the dishes',
        themes: [JournalTheme.time]);

    app.push('/journal');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(app.container.read(journalProvider), isEmpty);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    final back = app.container.read(journalProvider);
    expect(back, hasLength(1));
    expect(back.first.title, 'the dishes');
    expect(back.first.themes, [JournalTheme.time]);
    expect(find.text('the dishes'), findsOneWidget);
  });

  testWidgets('a plain note can be written from the empty state', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    app.push('/journal');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(GlassButton, 'Write a note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last,
        'Remember to ask about her mother\nshe mentioned it twice');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    final entries = app.container.read(journalProvider);
    expect(entries, hasLength(1));
    expect(entries.first.kind, JournalKind.note);
    expect(entries.first.title, 'Remember to ask about her mother');
    expect(JournalStore.load(app.store), hasLength(1));
  });

  testWidgets('trend chips filter the list', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    final j = app.container.read(journalProvider.notifier);
    await j.add(kind: JournalKind.untangle, title: 'money thing', body: '',
        themes: [JournalTheme.money]);
    await j.add(kind: JournalKind.untangle, title: 'time thing', body: '',
        themes: [JournalTheme.time]);

    app.push('/journal');
    await tester.pumpAndSettle();
    expect(find.text('money thing'), findsOneWidget);
    expect(find.text('time thing'), findsOneWidget);

    await tester.tap(find.text('Money · 1'));
    await tester.pumpAndSettle();
    expect(find.text('money thing'), findsOneWidget);
    expect(find.text('time thing'), findsNothing);

    await tester.tap(find.text('All · 2'));
    await tester.pumpAndSettle();
    expect(find.text('time thing'), findsOneWidget);
  });
}

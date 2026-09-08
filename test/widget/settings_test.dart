import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/core/app_state.dart';
import 'package:vyuhbhed/core/journal.dart';

import '../support/harness.dart';

void main() {
  Future<void> openSettings(WidgetTester tester, TestApp app) async {
    app.push('/settings');
    await tester.pumpAndSettle();
  }

  testWidgets('switching language re-renders the app, not just the chip',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    await openSettings(tester, app);

    await tester.tap(find.text('हिंदी'));
    await tester.pumpAndSettle();

    expect(app.container.read(appStateProvider).language, AppLanguage.hi);
    expect(find.text('सेटिंग्स'), findsOneWidget);
    expect(AppStateNotifier.load(app.store).language, AppLanguage.hi);
  });

  testWidgets('theme mode persists', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    await openSettings(tester, app);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(app.container.read(appStateProvider).themeMode, ThemeMode.dark);
    expect(AppStateNotifier.load(app.store).themeMode, ThemeMode.dark);
  });

  group('delete everything', () {
    testWidgets('asks first, and cancelling changes nothing', (tester) async {
      usePhoneSurface(tester);
      final app = await pumpApp(tester, seed: onboardedSeed());
      await app.container
          .read(journalProvider.notifier)
          .add(kind: JournalKind.note, title: 'keep me', body: '');
      await openSettings(tester, app);

      await tapVisible(tester, find.text('Delete everything'));

      // One tap used to wipe the journal, the origin story and every check-in
      // with no confirmation and no undo.
      expect(find.text('Delete everything?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(app.container.read(appStateProvider).onboarded, isTrue);
      expect(app.container.read(journalProvider), hasLength(1));
    });

    testWidgets('confirming wipes everything and returns to onboarding',
        (tester) async {
      usePhoneSurface(tester);
      final app = await pumpApp(tester, seed: onboardedSeed());
      await app.container
          .read(journalProvider.notifier)
          .add(kind: JournalKind.note, title: 'gone', body: '');
      await openSettings(tester, app);

      await tapVisible(tester, find.text('Delete everything'));

      await tester.tap(find.widgetWithText(TextButton, 'Delete everything'));
      await tester.pumpAndSettle();

      expect(app.location, '/onboarding');
      expect(app.container.read(appStateProvider).onboarded, isFalse);
      expect(app.container.read(appStateProvider).originStory, isEmpty);
      expect(app.container.read(journalProvider), isEmpty);
      expect(JournalStore.load(app.store), isEmpty);
    });
  });

  group('export', () {
    testWidgets('shows the whole payload and copies it', (tester) async {
      usePhoneSurface(tester);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      final app = await pumpApp(tester, seed: onboardedSeed());
      await app.container.read(journalProvider.notifier).add(
        kind: JournalKind.untangle,
        title: 'the dishes',
        body: 'body text',
        ask: 'can we pick a time?',
        themes: [JournalTheme.time],
      );
      await openSettings(tester, app);

      // Was `onPressed: () {}` under a promise of "export all your data".
      await tapVisible(tester, find.text('Export my data'));

      expect(find.text('Everything Saath knows'), findsOneWidget);

      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      expect(copied, isNotNull);
      final decoded = jsonDecode(copied!) as Map<String, Object?>;
      expect(decoded['app'], 'Saath');
      expect((decoded['profile']! as Map)['userName'], 'Asha');
      expect((decoded['profile']! as Map)['originStory'],
          startsWith('He made me laugh'));
      expect(decoded['journal'], hasLength(1));
      expect(((decoded['journal']! as List).first as Map)['ask'],
          'can we pick a time?');
    });
  });

  testWidgets('helplines are reachable from Settings, not only from a crisis',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    await openSettings(tester, app);

    // The section eyebrow renders as "HELPLINES", so this matches only the button.
    await tapVisible(tester, find.text('Helplines'));

    expect(app.location, '/safety');
  });

  testWidgets('the origin story can be edited after onboarding',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    await openSettings(tester, app);

    await tapVisible(tester, find.text('Why we started — edit'));
    expect(app.location, '/settings/origin');

    await tester.enterText(find.byType(TextField).first, 'Because he stayed.');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep this'));
    await tester.pumpAndSettle();

    expect(
        app.container.read(appStateProvider).originStory, 'Because he stayed.');
    expect(app.location, '/settings');
  });
}

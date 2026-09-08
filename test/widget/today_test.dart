import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/core/app_state.dart';

import '../support/harness.dart';

void main() {
  testWidgets('the week counter reflects real check-ins', (tester) async {
    usePhoneSurface(tester);
    final now = DateTime.now();
    final app = await pumpApp(tester, seed: {
      ...onboardedSeed(),
      'saath.pulses': '['
          '{"day":"${AppState.dayKey(now)}","connection":4,"word":"ok"},'
          '{"day":"${AppState.dayKey(now.subtract(const Duration(days: 2)))}","connection":2,"word":""},'
          '{"day":"${AppState.dayKey(now.subtract(const Duration(days: 30)))}","connection":5,"word":""}'
          ']',
    });

    // This tile was hardcoded to "0 of 7" / "1 of 7" regardless of history.
    expect(find.textContaining('2 of 7 check-ins'), findsOneWidget);
    expect(app.container.read(appStateProvider).todayConnection, 4);
  });

  testWidgets('a new user sees zero, not a fabricated number', (tester) async {
    usePhoneSurface(tester);
    await pumpApp(tester, seed: onboardedSeed());
    expect(find.textContaining('0 of 7 check-ins'), findsOneWidget);
  });

  testWidgets('tapping a score records it and reveals the one-word field',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());

    // The "One word for today?" prompt used to be a label with nothing to
    // type into.
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();

    expect(app.container.read(appStateProvider).todayConnection, 4);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('1 of 7 check-ins'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'tired');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(app.container.read(appStateProvider).todayWord, 'tired');
    expect(AppStateNotifier.load(app.store).todayWord, 'tired',
        reason: 'the word must survive a relaunch');
  });

  testWidgets('the greeting uses the name, and degrades gracefully without one',
      (tester) async {
    usePhoneSurface(tester);
    await pumpApp(tester, seed: onboardedSeed(user: 'Asha'));
    expect(find.textContaining('Asha'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    final anon = await pumpApp(tester, seed: {
      'saath.onboarded': true,
      'saath.partnerName': 'Vikram',
    });
    expect(anon.container.read(appStateProvider).userName, isEmpty);
    expect(find.textContaining('there'), findsWidgets);
  });

  testWidgets('the four tabs are reachable', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());

    for (final (label, route) in [
      ('Counsellor', '/counsellor'),
      ('Us', '/us'),
      ('Learn', '/learn'),
      ('Today', '/'),
    ]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(app.location, route, reason: label);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Hindi renders the whole home screen, tabs included',
      (tester) async {
    usePhoneSurface(tester);
    await pumpApp(tester, seed: onboardedSeed(language: 'hi'));

    expect(find.text('आज'), findsOneWidget);
    expect(find.text('काउंसलर'), findsOneWidget);
    expect(find.text('हम'), findsOneWidget);
    expect(find.text('सीखें'), findsOneWidget);
    expect(
        find.text('आज आप कितना जुड़ा हुआ महसूस कर रहे हैं?'), findsOneWidget);
  });

  testWidgets('survives a large text scale without overflowing',
      (tester) async {
    usePhoneSurface(tester);
    final app = TestApp(seed: onboardedSeed());
    addTearDown(app.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: app.widget(),
      ),
    );
    await tester.pumpAndSettle();

    // Fixed 52px button heights and a fixed-height composer used to clip or
    // overflow here.
    expect(tester.takeException(), isNull);
  });
}

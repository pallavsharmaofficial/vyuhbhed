import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/core/couple_space.dart';

import '../support/harness.dart';

void main() {
  testWidgets('the love map asks real questions, not placeholder rows',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    app.go('/us');
    await tester.pumpAndSettle();

    // Was three fixed rows reading "Tap to add" and one invented insight.
    expect(find.textContaining('What is Vikram worried about'), findsOneWidget);
    expect(findEyebrow('Love map'), findsOneWidget);
    expect(find.text('0 of 10'), findsOneWidget);
  });

  testWidgets('answering a love-map question stores and shows it',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    app.go('/us');
    await tester.pumpAndSettle();

    await tapVisible(
      tester,
      find.textContaining('What is Vikram worried about'),
    );

    await tester.enterText(find.byType(TextField), 'His mother’s health');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      app.container.read(coupleSpaceProvider).loveMap.single.answer,
      'His mother’s health',
    );
    expect(find.text('1 of 10'), findsOneWidget);
    expect(CoupleSpaceStore.load(app.store).loveMap, hasLength(1));
  });

  testWidgets('a goal can be added, ticked and removed', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    app.go('/us');
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Add a goal'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tapVisible(tester, find.text('Add a goal'));
    await tester.enterText(find.byType(TextField), 'One phone-free dinner');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(app.container.read(coupleSpaceProvider).goals, hasLength(1));

    await tester.scrollUntilVisible(
      find.byIcon(Icons.radio_button_unchecked_rounded),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tapVisible(tester, find.byIcon(Icons.radio_button_unchecked_rounded));
    expect(app.container.read(coupleSpaceProvider).goals.single.isDone, isTrue);
  });

  testWidgets('an empty dates section explains itself', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    app.go('/us');
    await tester.pumpAndSettle();

    // The love map is ten rows, so the dates card is well below the fold.
    final empty = find.textContaining('no account needed');
    await tester.scrollUntilVisible(
      empty,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(empty, findsOneWidget);
  });

  testWidgets('renders in Hindi', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(
      tester,
      seed: onboardedSeed(language: 'hi', partner: 'विक्रम'),
    );
    app.go('/us');
    await tester.pumpAndSettle();

    expect(findEyebrow('लव मैप'), findsOneWidget);
    expect(find.textContaining('अभी विक्रम किस बात से परेशान हैं?'),
        findsOneWidget);
  });
}

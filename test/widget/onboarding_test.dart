import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/core/app_state.dart';
import 'package:vyuhbhed/ui/glass.dart';

import '../support/harness.dart';

void main() {
  testWidgets('a new user lands on onboarding, never on Today', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester);

    expect(app.location, '/onboarding');
    expect(find.text('Start in English'), findsOneWidget);
  });

  testWidgets('an onboarded user goes straight to Today', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());

    expect(app.location, '/');
    expect(find.textContaining('Asha'), findsWidgets);
  });

  testWidgets('deep links cannot skip onboarding', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester);

    app.go('/us');
    await tester.pumpAndSettle();

    expect(app.location, '/onboarding');
  });

  testWidgets(
      'the full flow reaches Today and completing it does not tear down navigation',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester);

    // Step 1 — language.
    await tester.tap(find.text('Start in English'));
    await tester.pumpAndSettle();
    expect(app.location, '/onboarding/names');
    expect(find.text('Step 2 of 4'), findsOneWidget);

    // Step 2 — Continue stays disabled until all three answers exist.
    GlassButton continueButton() => tester
        .widget<GlassButton>(find.widgetWithText(GlassButton, 'Continue'));
    expect(continueButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'Asha');
    await tester.enterText(find.byType(TextField).last, 'Vikram');
    await tester.pumpAndSettle();
    expect(continueButton().onPressed, isNull,
        reason: 'stage is still unanswered');

    await tester.tap(find.text('Married'));
    await tester.pumpAndSettle();
    expect(continueButton().onPressed, isNotNull);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(app.location, '/onboarding/origin');
    expect(find.text('Step 3 of 4'), findsOneWidget);
    expect(find.textContaining('Vikram'), findsWidgets);

    // Step 3 — "Keep this" is gated on actually writing something.
    GlassButton keepButton() => tester
        .widget<GlassButton>(find.widgetWithText(GlassButton, 'Keep this'));
    expect(keepButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField).first,
        'He made me laugh on the worst day of my year.');
    await tester.pumpAndSettle();
    expect(keepButton().onPressed, isNotNull);

    await tester.tap(find.text('Keep this'));
    await tester.pumpAndSettle();

    // Step 4 is the model download, and it is the one step a user may skip.
    expect(app.location, '/onboarding/model');
    expect(find.text('Step 4 of 4'), findsOneWidget);
    expect(find.text('Bring the counsellor home'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    // Completing onboarding used to rebuild the whole GoRouter mid-navigation.
    expect(app.location, '/');
    expect(tester.takeException(), isNull);

    final state = app.container.read(appStateProvider);
    expect(state.onboarded, isTrue);
    expect(state.userName, 'Asha');
    expect(state.partnerName, 'Vikram');
    expect(state.relationshipStage, RelationshipStage.married);
    expect(state.originStory, startsWith('He made me laugh'));
  });

  testWidgets('"I\'ll write this later" finishes onboarding without a story',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester);

    await tester.tap(find.text('Start in English'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Asha');
    await tester.enterText(find.byType(TextField).last, 'Vikram');
    await tester.tap(find.text('Dating'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('I’ll write this later'));
    await tester.pumpAndSettle();
    expect(app.location, '/onboarding/model');

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(app.location, '/');
    expect(app.container.read(appStateProvider).onboarded, isTrue);
    expect(app.container.read(appStateProvider).originStory, isEmpty);
  });

  testWidgets('choosing Hindi switches the whole flow, not just the button',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester);

    await tester.tap(find.text('हिंदी में शुरू करें'));
    await tester.pumpAndSettle();

    expect(app.container.read(appStateProvider).language, AppLanguage.hi);
    // These headings were hardcoded English before, so a Hindi user saw
    // "Step 2 of 4" and "Who are we talking about?".
    expect(find.text('चरण 2 / 4'), findsOneWidget);
    expect(find.text('बात किसके बारे में है?'), findsOneWidget);
    expect(find.text('शादीशुदा'), findsOneWidget);
  });

  testWidgets('going back from step 2 returns to the welcome screen',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester);

    await tester.tap(find.text('Start in English'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    expect(app.location, '/onboarding');
  });

  testWidgets('intro slides are swipeable and the start buttons never leave',
      (tester) async {
    usePhoneSurface(tester);
    await pumpApp(tester);

    expect(find.textContaining('Most problems are simple'), findsOneWidget);
    expect(find.text('Start in English'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing you say leaves your phone'),
        findsOneWidget);
    expect(find.text('Start in English'), findsOneWidget,
        reason: 'reading the slides is optional; starting never scrolls away');

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Three tools'), findsOneWidget);
    expect(find.textContaining('Repair Room'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('remembers why you two started'),
        findsOneWidget);
    expect(find.text('Next'), findsNothing,
        reason: 'the last slide has nowhere further to go');
  });

  testWidgets('the origin editor no longer advertises voice input it lacks',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester);
    app.go('/onboarding/origin');
    await tester.pumpAndSettle();
    expect(find.text('Say it instead'), findsNothing);
  });
}

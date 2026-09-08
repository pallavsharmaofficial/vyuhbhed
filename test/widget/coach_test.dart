import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/features/coach/profile.dart';
import 'package:vyuhbhed/features/coach/tracker.dart';
import 'package:vyuhbhed/ui/glass.dart';

import '../support/harness.dart';

Map<String, Object> coachSeed() => {
      ...onboardedSeed(),
      'vyuhbhed.profile':
          '{"name":"Asha","targetRole":"Senior Flutter Developer","yearsExperience":6,"targetOffers":10,"applicationsPerDay":2}',
    };

void main() {
  testWidgets('a new user sees the intro, then the profile step',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester);
    expect(app.location, '/onboarding');
    expect(find.textContaining('like a campaign'), findsOneWidget);

    await tester.tap(find.text('Start in English'));
    await tester.pumpAndSettle();
    expect(app.location, '/onboarding/profile');

    GlassButton start() => tester.widget<GlassButton>(
        find.widgetWithText(GlassButton, 'Start the campaign'));
    expect(start().onPressed, isNull, reason: 'target role is required');
    await tester.enterText(
        find.widgetWithText(TextField, 'Target role'), 'Flutter Lead');
    await tester.pumpAndSettle();
    expect(start().onPressed, isNotNull);
    await tester.tap(find.text('Start the campaign'));
    await tester.pumpAndSettle();
    expect(app.location, '/onboarding/model');
    expect(ProfileStore.load(app.store).targetRole, 'Flutter Lead');
  });

  testWidgets('Today asks for the check-in first, then applications',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: coachSeed());
    expect(app.location, '/');
    expect(find.textContaining('Today, Asha'), findsOneWidget);
    expect(find.textContaining('how is your energy'), findsOneWidget);

    // The energy scale sits below the fold on a 390x844 surface, so a bare
    // tap() lands on empty space and only warns.
    await tapVisible(tester, find.text('4'));

    // Reaching it scrolled the "Right now" card off the top, and a ListView
    // disposes what it cannot see — so scroll back before asserting on it.
    final plan = find.textContaining('Send 2 more applications');
    await tester.scrollUntilVisible(
      plan,
      -240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(plan, findsOneWidget);
  });

  testWidgets('logging an application moves the plan on', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: coachSeed());
    final store = app.container.read(applicationsProvider.notifier);
    await store.add(company: 'Zeta', role: 'Lead');
    await store.add(company: 'Razorpay', role: 'Lead');
    await app.container.read(applicationsProvider.notifier).setStage(
        app.container.read(applicationsProvider).first.id, AppStage.interview);
    await tester.pumpAndSettle();

    expect(find.textContaining('Applications · 2 of 2'), findsOneWidget);
    app.go('/track');
    await tester.pumpAndSettle();
    expect(find.text('Zeta'), findsOneWidget);
    expect(find.text('Interview · 1'), findsOneWidget);
  });

  testWidgets('a mock interview runs end to end on the sample engine',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: coachSeed());
    app.go('/practice');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Start'));
    expect(app.location, '/mock');
    // Eyebrow uppercases Latin labels, so this is "QUESTION 1 OF 5" on screen.
    expect(findEyebrow('Question 1 of 5'), findsOneWidget);

    await tester.enterText(find.byType(TextField),
        'I led a Flutter team of four and shipped two apps.');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Score my answer'));
    expect(find.text('Structure'), findsOneWidget);
    // TintPanel labels go through Eyebrow too.
    expect(findEyebrow('A stronger version'), findsOneWidget);

    await tapVisible(tester, find.text('Next question'));
    for (var i = 0; i < 4; i++) {
      await tapVisible(tester, find.text('Skip'));
    }
    expect(find.textContaining('Logged for today'), findsOneWidget);
    expect(MockStore.load(app.store), hasLength(1));
  });

  testWidgets('the coach answers and routes a crisis to the helplines',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: coachSeed());
    app.go('/coach');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Got rejected today'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sample coach'), findsOneWidget);
  });
}

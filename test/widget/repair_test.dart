import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/ui/glass.dart';

import '../support/harness.dart';

void main() {
  GlassButton buttonWith(WidgetTester tester, String label) =>
      tester.widget<GlassButton>(find.widgetWithText(GlassButton, label));

  testWidgets('cannot submit an empty side', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());

    app.push('/repair');
    await tester.pumpAndSettle();

    // Was unconditionally enabled: an empty room merged two empty strings into
    // a confident, invented summary.
    expect(buttonWith(tester, 'Submit my side').onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'short');
    await tester.pumpAndSettle();
    expect(buttonWith(tester, 'Submit my side').onPressed, isNull);

    await tester.enterText(find.byType(TextField),
        'I asked him to help and he walked out of the room');
    await tester.pumpAndSettle();
    expect(buttonWith(tester, 'Submit my side').onPressed, isNotNull);
  });

  testWidgets('the partner never sees the first side', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    app.push('/repair');
    await tester.pumpAndSettle();

    const mine = 'I asked him to help and he walked out of the room';
    await tester.enterText(find.byType(TextField), mine);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit my side'));
    await tester.pumpAndSettle();

    expect(find.text('Your side is sealed.'), findsOneWidget);
    expect(find.text(mine), findsNothing);

    await tester.tap(find.text('I am Vikram'));
    await tester.pumpAndSettle();

    expect(find.text(mine), findsNothing,
        reason: 'the second side must start from a blank field');
    expect(findEyebrow('Vikram’s side · private'), findsOneWidget);
  });

  testWidgets('two real sides reach the merged view', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    app.push('/repair');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField),
        'I asked him to help and he walked out of the room');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit my side'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I am Vikram'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField),
        'she asked at the worst moment and I was exhausted');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Both sides in — merge'));
    await tester.pumpAndSettle();

    expect(app.location, '/repair/merged');
    expect(findEyebrow('You both agree'), findsOneWidget);
    expect(findEyebrow('Where the stories split'), findsOneWidget);
    expect(find.textContaining('TURN 1 OF 4'), findsOneWidget);
  });

  testWidgets('a disclosure on either side goes to safety instead of merging',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    app.push('/repair');
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextField), 'we argued for an hour about nothing at all');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit my side'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I am Vikram'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField),
        'she would not stop so I hit her, I am not proud');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Both sides in — merge'));
    await tester.pumpAndSettle();

    expect(app.location, '/safety');
  });

  testWidgets('the closing screen shows the origin story back', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());

    app.push('/repair/close');
    await tester.pumpAndSettle();

    expect(findEyebrow('Repaired'), findsOneWidget);
    expect(
      find.textContaining('He made me laugh on the worst day of my year.'),
      findsOneWidget,
    );
  });

  testWidgets('the cool-down timer stops at zero', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());

    app.push('/repair/cooldown');
    // Never pumpAndSettle here: the breathing circle repeats forever by
    // design, so "settled" never arrives.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('20:00'), findsOneWidget);

    // Twenty minutes plus a margin. The old timer kept firing and rebuilding
    // forever once it reached zero.
    await tester.pump(const Duration(minutes: 20, seconds: 5));
    await tester.pump();

    expect(find.text('00:00'), findsOneWidget);
    expect(find.textContaining('You can go back now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a merged route restored without its sides offers a retry',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());

    // `extra` does not survive Android process death.
    app.push('/repair/merged');
    await tester.pumpAndSettle();

    expect(find.textContaining('Both sides need a few words'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

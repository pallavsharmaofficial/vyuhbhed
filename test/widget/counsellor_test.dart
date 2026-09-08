import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/features/counsellor/chat_controller.dart';

import '../support/harness.dart';

void main() {
  testWidgets('sending a message shows it and a streamed reply',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());

    app.go('/counsellor');
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextField), 'we keep having the same fight');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(app.container.read(chatControllerProvider).messages, hasLength(2));
    expect(tester.takeException(), isNull);

    // The reply scrolls the conversation, so the user's own message may be
    // above the fold — a ListView does not keep what it cannot see.
    await tester.scrollUntilVisible(
      find.text('we keep having the same fight'),
      -240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('we keep having the same fight'), findsOneWidget);
  });

  testWidgets('the send button is disabled until something is typed',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    app.go('/counsellor');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(app.container.read(chatControllerProvider).messages, isEmpty);
  });

  testWidgets('a disclosure routes to the safety screen and dialable helplines',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    app.go('/counsellor');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'I am afraid of him');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(app.location, '/safety');
    expect(find.text('Tele-MANAS'), findsOneWidget);
    expect(find.text('Emergency'), findsOneWidget);
    // Every helpline row is tappable now; they used to be decoration.
    expect(find.byIcon(Icons.call_outlined), findsNWidgets(5));
  });

  testWidgets('returning from the safety screen leaves the counsellor speaking',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    app.go('/counsellor');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'he hit me');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    final keepTalking = find.text('I’m okay, keep talking');
    await tester.ensureVisible(keepTalking);
    await tester.pumpAndSettle();
    await tester.tap(keepTalking);
    await tester.pumpAndSettle();

    expect(app.location, '/counsellor');
    final messages = app.container.read(chatControllerProvider).messages;
    expect(messages, hasLength(2),
        reason: 'the conversation used to be left with no reply at all');
    expect(messages.last.fromUser, isFalse);
  });

  testWidgets('a suggested prompt starts the conversation', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    app.go('/counsellor');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Same fight again'));
    await tester.pumpAndSettle();

    expect(app.container.read(chatControllerProvider).messages, hasLength(2));
  });

  testWidgets('the tab counsellor has no back arrow', (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());
    app.go('/counsellor');
    await tester.pumpAndSettle();

    // A tab that shows a back arrow which jumps to another tab is a lie about
    // the navigation stack.
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
  });

  testWidgets('a seeded conversation is not sent twice on rebuild',
      (tester) async {
    usePhoneSurface(tester);
    final app = await pumpApp(tester, seed: onboardedSeed());

    app.push('/talk', extra: 'About to say something I’ll regret');
    await tester.pumpAndSettle();

    await tester.pump();
    await tester.pumpAndSettle();

    final messages = app.container.read(chatControllerProvider).messages;
    expect(messages.where((m) => m.fromUser), hasLength(1));
  });
}

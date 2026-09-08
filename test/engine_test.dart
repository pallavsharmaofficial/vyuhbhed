import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/core/journal.dart';
import 'package:vyuhbhed/features/counsellor/engine.dart';

void main() {
  const engine = MockCounsellorEngine(tokenDelay: Duration.zero);
  const ctx = CounsellorContext(
    userName: 'Asha',
    partnerName: 'Vikram',
    originStory: 'he stayed',
    hindi: false,
  );

  group('reply', () {
    test('streams a non-empty reply', () async {
      final chunks = await engine.reply(const [], ctx).toList();
      expect(chunks, isNotEmpty);
      expect(chunks.join().trim(), isNotEmpty);
    });

    test('names the partner rather than leaving a blank', () async {
      final text = await engine.reply(const [
        ChatMessage(fromUser: true, text: 'a'),
        ChatMessage(fromUser: false, text: 'b'),
        ChatMessage(fromUser: true, text: 'c'),
      ], ctx).join();
      expect(text, contains('Vikram'));
    });

    test('falls back to a readable phrase when no partner name is set',
        () async {
      const anon = CounsellorContext(
          userName: '', partnerName: '', originStory: '', hindi: false);
      final text = await engine.reply(const [
        ChatMessage(fromUser: true, text: 'a'),
        ChatMessage(fromUser: false, text: 'b'),
        ChatMessage(fromUser: true, text: 'c'),
      ], anon).join();
      expect(text, contains('your partner'));
      expect(text, isNot(contains('  ')));
    });

    test('answers in Hindi when the context asks for it', () async {
      const hindi = CounsellorContext(
          userName: 'आशा', partnerName: 'विक्रम', originStory: '', hindi: true);
      final text = await engine.reply(const [], hindi).join();
      expect(RegExp(r'[ऀ-ॿ]').hasMatch(text), isTrue);
    });
  });

  group('untangle', () {
    test('returns all four columns and a sentence', () async {
      final u = await engine.untangle('he left the room again', ctx);
      expect(u.happened, isNotEmpty);
      expect(u.assumed, isNotEmpty);
      expect(u.felt, isNotEmpty);
      expect(u.need, isNotEmpty);
      expect(u.sentence, isNotEmpty);
    });

    test('refuses an empty vent instead of inventing one', () {
      expect(
        () => engine.untangle('   ', ctx),
        throwsA(isA<CounsellorException>()),
      );
    });
  });

  group('mergeRepair', () {
    test('merges two real sides', () async {
      final m = await engine.mergeRepair(
        const RepairSides(
          'I asked him to help and he said do whatever you want',
          'she asked at the worst possible moment and I was done',
        ),
        ctx,
      );
      expect(m.title, isNotEmpty);
      expect(m.agreed, isNotEmpty);
      expect(m.firstTurn, contains('Asha'));
    });

    test('refuses to merge two empty sides', () {
      // The old screen let an empty room through and rendered a confident,
      // entirely fabricated summary of a fight nobody described.
      expect(
        () => engine.mergeRepair(const RepairSides('', ''), ctx),
        throwsA(isA<CounsellorException>()),
      );
    });

    test('refuses when only one side wrote anything', () {
      expect(
        () => engine.mergeRepair(
            const RepairSides('a proper account of the evening', ''), ctx),
        throwsA(isA<CounsellorException>()),
      );
    });
  });

  group('RepairSides', () {
    test('needs real content on both sides', () {
      expect(const RepairSides('', '').isComplete, isFalse);
      expect(const RepairSides('too short', 'also').isComplete, isFalse);
      expect(
        const RepairSides('a long enough account', 'and the other one')
            .isComplete,
        isTrue,
      );
    });

    test('compares by value so the merge provider caches per pair', () {
      expect(const RepairSides('a', 'b'), const RepairSides('a', 'b'));
      expect(const RepairSides('a', 'b').hashCode,
          const RepairSides('a', 'b').hashCode);
    });
  });

  group('theme inference', () {
    test('picks up money and family in English', () {
      expect(
        MockCounsellorEngine.inferThemes(
            'we fought about money and his mother'),
        containsAll([JournalTheme.money, JournalTheme.family]),
      );
    });

    test('picks up Hindi keywords too', () {
      expect(
        MockCounsellorEngine.inferThemes('पैसे और ससुराल को लेकर झगड़ा'),
        containsAll([JournalTheme.money, JournalTheme.family]),
      );
    });

    test('returns nothing rather than guessing', () {
      expect(MockCounsellorEngine.inferThemes('hmm'), isEmpty);
    });
  });

  group('Hindi preview content', () {
    const hi = CounsellorContext(
        userName: 'आशा', partnerName: 'विक्रम', originStory: '', hindi: true);
    final devanagari = RegExp(r'[ऀ-ॿ]');

    test('untangle answers in Hindi, not English inside Hindi chrome',
        () async {
      final u = await engine.untangle('वो कमरे से चला गया', hi);
      for (final field in [u.happened, u.assumed, u.felt, u.need, u.sentence]) {
        expect(field, matches(devanagari), reason: field);
      }
      expect(u.happened, contains('विक्रम'));
    });

    test('the repair merge answers in Hindi too', () async {
      final m = await engine.mergeRepair(
        const RepairSides(
            'मैंने मदद माँगी और वो चले गए', 'उसने सबसे बुरे वक़्त पर कहा'),
        hi,
      );
      for (final field in [
        m.title,
        m.agreed,
        m.sideA,
        m.sideB,
        m.split,
        m.firstTurn
      ]) {
        expect(field, matches(devanagari), reason: field);
      }
      expect(m.firstTurn, contains('आशा'));
    });
  });

  group('safety guardrail', () {
    test('is on the engine interface, so every entry point gets it', () {
      expect(engine.needsSafetyInterrupt('he hit me'), isTrue);
      expect(
          engine.needsSafetyInterrupt('we argued about the dishes'), isFalse);
    });
  });
}

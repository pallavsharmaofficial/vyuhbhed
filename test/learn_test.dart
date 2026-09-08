import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/features/learn/learn_screen.dart';

void main() {
  final devanagari = RegExp(r'[ऀ-ॿ]');

  test('the deck is the full fifteen the plan calls for', () {
    // The header used to claim "5 of 15" with five cards behind it.
    expect(learnCards, hasLength(15));
  });

  test('every card is complete in both languages', () {
    for (final c in learnCards) {
      expect(c.title.trim(), isNotEmpty, reason: c.title);
      expect(c.body.trim(), isNotEmpty, reason: c.title);
      expect(c.exercise.trim(), isNotEmpty, reason: c.title);

      expect(c.titleHi, matches(devanagari), reason: c.title);
      expect(c.bodyHi, matches(devanagari), reason: c.title);
      expect(c.exerciseHi, matches(devanagari), reason: c.title);
    }
  });

  test('no card is a duplicate', () {
    final titles = learnCards.map((c) => c.title).toSet();
    expect(titles, hasLength(learnCards.length));
  });

  test('the Hindi is a translation, not a copy of the English', () {
    for (final c in learnCards) {
      expect(c.titleHi, isNot(c.title), reason: c.title);
      expect(c.bodyHi, isNot(c.body), reason: c.title);
    }
  });

  test('every card ends in something to actually do', () {
    for (final c in learnCards) {
      // An idea with no exercise is a fact, not a card.
      expect(c.exercise.length, greaterThan(20), reason: c.title);
      expect(c.exerciseHi.length, greaterThan(15), reason: c.title);
    }
  });

  test('t/b/e pick the right language', () {
    final c = learnCards.first;
    expect(c.t(false), c.title);
    expect(c.t(true), c.titleHi);
    expect(c.b(true), c.bodyHi);
    expect(c.e(true), c.exerciseHi);
  });
}

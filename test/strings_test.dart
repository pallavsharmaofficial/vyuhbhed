import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/core/app_state.dart';
import 'package:vyuhbhed/core/strings.dart';

/// Strings are the product here, and the failure mode is silent: a Hindi user
/// gets an English sentence and nothing errors. These tests read the table as
/// source so a new string cannot be added half-translated.
void main() {
  final en = S.forLanguage(AppLanguage.en);
  final hi = S.forLanguage(AppLanguage.hi);
  final devanagari = RegExp(r'[ऀ-ॿ]');

  group('translation coverage', () {
    final source = File('lib/core/strings.dart').readAsStringSync();

    /// Matches `_t('english', 'हिंदी')` across line breaks, handling escaped
    /// quotes inside either argument.
    final calls = RegExp(
      r"""_t\(\s*'((?:[^'\\]|\\.)*)'\s*,\s*'((?:[^'\\]|\\.)*)'\s*\)""",
      dotAll: true,
    ).allMatches(source).toList();

    test('the table is actually being read', () {
      expect(calls.length, greaterThan(80),
          reason: 'if this drops, the regex stopped matching, not the strings');
    });

    test('every _t call has a non-empty pair', () {
      for (final m in calls) {
        expect(m.group(1)!.trim(), isNotEmpty, reason: 'English side of $m');
        expect(m.group(2)!.trim(), isNotEmpty, reason: 'Hindi side of $m');
      }
    });

    test('no Hindi value is a copy of the English one', () {
      final untranslated = [
        for (final m in calls)
          if (m.group(1) == m.group(2)) m.group(1)!,
      ];
      expect(untranslated, isEmpty,
          reason: 'these shipped to Hindi users in English');
    });

    test('every Hindi value contains Devanagari', () {
      // A Hindi value with no Devanagari in it is either untranslated or a
      // brand name that should not have gone through _t at all. Values that
      // are purely placeholders, digits and punctuation are exempt.
      bool onlyPlaceholders(String v) => v
          .replaceAll(RegExp(r'\$\{?\w+\}?'), '')
          .replaceAll(RegExp(r'[\s\d\p{P}\p{S}]', unicode: true), '')
          .isEmpty;

      final suspicious = [
        for (final m in calls)
          if (!devanagari.hasMatch(m.group(2)!) &&
              !onlyPlaceholders(m.group(2)!))
            m.group(2)!,
      ];
      expect(suspicious, isEmpty);
    });
  });

  group('placeholders', () {
    test('interpolate the partner name into both languages', () {
      expect(en.whyChoose('Vikram'), contains('Vikram'));
      expect(hi.whyChoose('विक्रम'), contains('विक्रम'));
      expect(hi.whyChoose('विक्रम'), matches(devanagari));
    });

    test('the turn header names both people in order', () {
      final line = en.turnHeader(2, 4, 'Asha', 'Vikram');
      expect(line, contains('2'));
      expect(line, contains('4'));
      expect(line.indexOf('Asha'), lessThan(line.indexOf('Vikram')));
    });

    test('counts render in both languages', () {
      expect(en.checkinsThisWeek(3), contains('3'));
      expect(hi.checkinsThisWeek(3), contains('3'));
      expect(en.stepOf(2, 3), contains('2'));
      expect(hi.stepOf(2, 3), matches(devanagari));
    });
  });

  group('relationship stages', () {
    test('every enum value has a label in both languages', () {
      for (final stage in RelationshipStage.values) {
        expect(en.stageLabel(stage).trim(), isNotEmpty);
        expect(hi.stageLabel(stage).trim(), isNotEmpty);
        expect(hi.stageLabel(stage), isNot(en.stageLabel(stage)));
      }
    });
  });

  group('greeting', () {
    test('always includes the name', () {
      expect(en.greeting('Asha'), contains('Asha'));
      expect(hi.greeting('आशा'), contains('आशा'));
    });
  });

  test('the app name is not translated', () {
    // "Saath" is the brand; the Devanagari form sits beside it, not instead.
    expect(en.appName, 'Saath');
    expect(hi.appName, 'Saath');
    expect(hi.appNameDevanagari, 'साथ');
  });

  test('the download percentage is a number, not the literal placeholder', () {
    expect(en.modelPercent(50), '50%');
    expect(hi.modelPercent(7), '7%');
  });
}

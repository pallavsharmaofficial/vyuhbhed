import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/core/app_state.dart';
import 'package:vyuhbhed/features/coach/coach_engine.dart';
import 'package:vyuhbhed/features/coach/coach_strings.dart';
import 'package:vyuhbhed/features/coach/motivation.dart';
import 'package:vyuhbhed/features/coach/tracker.dart';

void main() {
  final en = T.forLanguage(AppLanguage.en);
  final hi = T.forLanguage(AppLanguage.hi);
  final devanagari = RegExp(r'[ऀ-ॿ]');

  test('every string pair is complete and translated', () {
    final source =
        File('lib/features/coach/coach_strings.dart').readAsStringSync();
    final calls = RegExp(
            r"""_t\(\s*'((?:[^'\\]|\\.)*)'\s*,\s*'((?:[^'\\]|\\.)*)'\s*\)""",
            dotAll: true)
        .allMatches(source)
        .toList();
    expect(calls.length, greaterThan(90));
    for (final m in calls) {
      expect(m.group(1)!.trim(), isNotEmpty);
      expect(m.group(1), isNot(equals(m.group(2))));
      expect(devanagari.hasMatch(m.group(2)!), isTrue, reason: m.group(2));
    }
  });

  test('enum labels cover every value in both languages', () {
    for (final s in AppStage.values) {
      expect(en.stage(s), isNotEmpty);
      expect(hi.stage(s), matches(devanagari));
    }
    for (final r in InterviewRound.values) {
      expect(en.round(r), isNotEmpty);
      expect(hi.round(r), matches(devanagari));
    }
    for (final k in EngineKind.values) {
      expect(en.engineKind(k), isNotEmpty);
    }
  });

  test(
      'every moment has a line in both languages and it is stable within a day',
      () {
    for (final m in Moment.values) {
      final a = Motivation.line(m, hindi: false, on: DateTime(2026, 9, 8));
      final b = Motivation.line(m, hindi: false, on: DateTime(2026, 9, 8));
      expect(a, isNotEmpty);
      expect(a, b);
      expect(Motivation.line(m, hindi: true, on: DateTime(2026, 9, 8)),
          matches(devanagari));
    }
  });
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state.dart';
import 'key_value_store.dart';

/// One thing you know about your partner.
///
/// Gottman's love map: the answers are the point, but the *questions* are what
/// the app supplies — most people cannot think of what they do not know.
@immutable
class LoveMapFact {
  const LoveMapFact({
    required this.id,
    required this.prompt,
    required this.answer,
    required this.updatedAt,
  });

  final String id;

  /// The question, as it was asked. Stored rather than looked up, so changing
  /// the prompt list later does not rewrite what someone answered.
  final String prompt;
  final String answer;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'prompt': prompt,
        'answer': answer,
        'updatedAt': updatedAt.toIso8601String(),
      };

  static LoveMapFact? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String) return null;
    return LoveMapFact(
      id: id,
      prompt: raw['prompt'] as String? ?? '',
      answer: raw['answer'] as String? ?? '',
      updatedAt: DateTime.tryParse(raw['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Something the two of you decided to do.
@immutable
class SharedGoal {
  const SharedGoal({
    required this.id,
    required this.text,
    required this.createdAt,
    this.doneAt,
  });

  final String id;
  final String text;
  final DateTime createdAt;

  /// Null while it is still a goal.
  final DateTime? doneAt;

  bool get isDone => doneAt != null;

  SharedGoal copyWith({
    String? text,
    DateTime? doneAt,
    bool clearDone = false,
  }) =>
      SharedGoal(
        id: id,
        text: text ?? this.text,
        createdAt: createdAt,
        doneAt: clearDone ? null : (doneAt ?? this.doneAt),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'doneAt': doneAt?.toIso8601String(),
      };

  static SharedGoal? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final text = raw['text'];
    if (id is! String || text is! String) return null;
    return SharedGoal(
      id: id,
      text: text,
      createdAt: DateTime.tryParse(raw['createdAt'] as String? ?? '') ??
          DateTime.now(),
      doneAt: DateTime.tryParse(raw['doneAt'] as String? ?? ''),
    );
  }
}

/// A date that matters, with a reminder the app can surface.
@immutable
class ImportantDate {
  const ImportantDate({
    required this.id,
    required this.label,
    required this.month,
    required this.day,
    this.year,
  });

  final String id;
  final String label;
  final int month;
  final int day;

  /// Optional: the year it first happened, so an anniversary can be counted.
  final int? year;

  /// Days until the next occurrence, counting today as 0.
  int daysUntil([DateTime? now]) {
    final today = now ?? DateTime.now();
    var next = DateTime(today.year, month, day);
    final startOfToday = DateTime(today.year, today.month, today.day);
    if (next.isBefore(startOfToday)) {
      next = DateTime(today.year + 1, month, day);
    }
    return next.difference(startOfToday).inDays;
  }

  /// Which anniversary the next occurrence will be, if a year is known.
  int? nextCount([DateTime? now]) {
    if (year == null) return null;
    final today = now ?? DateTime.now();
    final thisYear = DateTime(today.year, month, day);
    final startOfToday = DateTime(today.year, today.month, today.day);
    final targetYear =
        thisYear.isBefore(startOfToday) ? today.year + 1 : today.year;
    return targetYear - year!;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'month': month,
        'day': day,
        'year': year,
      };

  static ImportantDate? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final label = raw['label'];
    final month = raw['month'];
    final day = raw['day'];
    if (id is! String || label is! String || month is! int || day is! int) {
      return null;
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    // 30 Feb would silently roll into March in daysUntil(). A leap year is
    // used so 29 Feb stays valid.
    if (DateTime(2024, month, day).month != month) return null;
    return ImportantDate(
      id: id,
      label: label,
      month: month,
      day: day,
      year: raw['year'] is int ? raw['year'] as int : null,
    );
  }
}

@immutable
class CoupleSpace {
  const CoupleSpace({
    this.loveMap = const [],
    this.goals = const [],
    this.dates = const [],
  });

  final List<LoveMapFact> loveMap;
  final List<SharedGoal> goals;
  final List<ImportantDate> dates;

  List<SharedGoal> get openGoals => [
        for (final g in goals)
          if (!g.isDone) g
      ];

  /// The next date coming up, or null.
  ImportantDate? get nextDate {
    if (dates.isEmpty) return null;
    final sorted = [...dates]
      ..sort((a, b) => a.daysUntil().compareTo(b.daysUntil()));
    return sorted.first;
  }

  Map<String, Object?> toJson() => {
        'loveMap': [for (final f in loveMap) f.toJson()],
        'goals': [for (final g in goals) g.toJson()],
        'dates': [for (final d in dates) d.toJson()],
      };
}

const _coupleKey = 'saath.coupleSpace';

/// The "Us" page's data. Local, like everything else — this is the part that
/// syncs once pairing exists, which is why it is already one serialisable
/// object rather than three loose lists.
class CoupleSpaceStore extends StateNotifier<CoupleSpace> {
  CoupleSpaceStore(this._store) : super(load(_store));

  final KeyValueStore _store;

  @visibleForTesting
  static CoupleSpace load(KeyValueStore store) {
    final raw = store.getString(_coupleKey);
    if (raw == null || raw.isEmpty) return const CoupleSpace();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const CoupleSpace();
      return CoupleSpace(
        loveMap: [
          for (final f in (decoded['loveMap'] as List? ?? const []))
            if (LoveMapFact.fromJson(f) case final fact?) fact,
        ],
        goals: [
          for (final g in (decoded['goals'] as List? ?? const []))
            if (SharedGoal.fromJson(g) case final goal?) goal,
        ],
        dates: [
          for (final d in (decoded['dates'] as List? ?? const []))
            if (ImportantDate.fromJson(d) case final date?) date,
        ],
      );
    } on FormatException {
      return const CoupleSpace();
    }
  }

  static String _id() => '${DateTime.now().microsecondsSinceEpoch}';

  Future<void> setFact({required String prompt, required String answer}) async {
    final trimmed = answer.trim();
    final existing = state.loveMap.where((f) => f.prompt == prompt).firstOrNull;

    final next = [
      for (final f in state.loveMap)
        if (f.prompt != prompt) f,
      // An emptied answer removes the fact rather than storing a blank.
      if (trimmed.isNotEmpty)
        LoveMapFact(
          id: existing?.id ?? _id(),
          prompt: prompt,
          answer: trimmed,
          updatedAt: DateTime.now(),
        ),
    ];
    state = CoupleSpace(loveMap: next, goals: state.goals, dates: state.dates);
    await _persist();
  }

  String? answerFor(String prompt) =>
      state.loveMap.where((f) => f.prompt == prompt).firstOrNull?.answer;

  Future<void> addGoal(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    state = CoupleSpace(
      loveMap: state.loveMap,
      goals: [
        SharedGoal(id: _id(), text: trimmed, createdAt: DateTime.now()),
        ...state.goals,
      ],
      dates: state.dates,
    );
    await _persist();
  }

  Future<void> toggleGoal(String id) async {
    state = CoupleSpace(
      loveMap: state.loveMap,
      goals: [
        for (final g in state.goals)
          if (g.id == id)
            g.isDone
                ? g.copyWith(clearDone: true)
                : g.copyWith(doneAt: DateTime.now())
          else
            g,
      ],
      dates: state.dates,
    );
    await _persist();
  }

  /// A typo used to mean remove-and-re-add, which also lost the done state.
  Future<void> editGoal(String id, String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    state = CoupleSpace(
      loveMap: state.loveMap,
      goals: [
        for (final g in state.goals)
          if (g.id == id) g.copyWith(text: t) else g,
      ],
      dates: state.dates,
    );
    await _persist();
  }

  Future<void> removeGoal(String id) async {
    state = CoupleSpace(
      loveMap: state.loveMap,
      goals: [
        for (final g in state.goals)
          if (g.id != id) g
      ],
      dates: state.dates,
    );
    await _persist();
  }

  Future<void> addDate({
    required String label,
    required int month,
    required int day,
    int? year,
  }) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    state = CoupleSpace(
      loveMap: state.loveMap,
      goals: state.goals,
      dates: [
        ...state.dates,
        ImportantDate(
            id: _id(), label: trimmed, month: month, day: day, year: year),
      ],
    );
    await _persist();
  }

  Future<void> removeDate(String id) async {
    state = CoupleSpace(
      loveMap: state.loveMap,
      goals: state.goals,
      dates: [
        for (final d in state.dates)
          if (d.id != id) d
      ],
    );
    await _persist();
  }

  Future<void> clear() async {
    state = const CoupleSpace();
    await _store.remove(_coupleKey);
  }

  Future<void> _persist() =>
      _store.setString(_coupleKey, jsonEncode(state.toJson()));
}

final coupleSpaceProvider =
    StateNotifierProvider<CoupleSpaceStore, CoupleSpace>(
  (ref) => CoupleSpaceStore(ref.watch(keyValueStoreProvider)),
);

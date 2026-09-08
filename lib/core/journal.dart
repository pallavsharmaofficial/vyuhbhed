import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state.dart';
import 'key_value_store.dart';

/// What kind of moment produced an entry. Kept as a string id so a new kind
/// never renumbers the old ones on disk.
enum JournalKind {
  untangle('untangle'),
  repair('repair'),
  note('note');

  const JournalKind(this.id);
  final String id;

  static JournalKind fromId(String? id) =>
      values.firstWhere((k) => k.id == id, orElse: () => JournalKind.note);
}

/// A theme the user (or the counsellor) attached to an entry. These are the
/// five that show up in Indian couple counselling often enough to be worth
/// trending over 30 days.
enum JournalTheme {
  money('money'),
  family('family'),
  intimacy('intimacy'),
  time('time'),
  trust('trust');

  const JournalTheme(this.id);
  final String id;

  static JournalTheme? fromId(String? id) {
    if (id == null) return null;
    for (final t in values) {
      if (t.id == id) return t;
    }
    return null;
  }
}

@immutable
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.createdAt,
    required this.kind,
    required this.title,
    required this.body,
    this.ask = '',
    this.themes = const [],
    this.reflection = '',
  });

  final String id;
  final DateTime createdAt;
  final JournalKind kind;

  /// Short line for the list — for an Untangle, "what happened".
  final String title;

  /// The full saved text.
  final String body;

  /// The one sentence the user could actually say. Empty for plain notes.
  final String ask;

  final List<JournalTheme> themes;

  /// The counsellor's note on reading this back, generated on request rather
  /// than at save time — the value is in the distance.
  final String reflection;

  Map<String, Object?> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'kind': kind.id,
        'title': title,
        'body': body,
        'ask': ask,
        'themes': [for (final t in themes) t.id],
        if (reflection.isNotEmpty) 'reflection': reflection,
      };

  static JournalEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final created = DateTime.tryParse(raw['createdAt'] as String? ?? '');
    if (id is! String || created == null) return null;
    return JournalEntry(
      id: id,
      createdAt: created,
      kind: JournalKind.fromId(raw['kind'] as String?),
      title: raw['title'] as String? ?? '',
      body: raw['body'] as String? ?? '',
      ask: raw['ask'] as String? ?? '',
      themes: [
        for (final t in (raw['themes'] as List? ?? const []))
          if (JournalTheme.fromId(t as String?) case final theme?) theme,
      ],
      reflection: raw['reflection'] as String? ?? '',
    );
  }
}

const _journalKey = 'saath.journal';
const _maxEntries = 500;

/// Local journal. Newest first.
///
/// This is the store behind Untangle's "Save" — which, before it existed, was a
/// button that closed the screen and threw the result away.
class JournalStore extends StateNotifier<List<JournalEntry>> {
  JournalStore(this._prefs) : super(load(_prefs));

  final KeyValueStore _prefs;

  @visibleForTesting
  static List<JournalEntry> load(KeyValueStore p) {
    final raw = p.getString(_journalKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final entries = [
        for (final item in decoded)
          if (JournalEntry.fromJson(item) case final e?) e,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return List.unmodifiable(entries);
    } on FormatException {
      return const [];
    }
  }

  Future<JournalEntry> add({
    required JournalKind kind,
    required String title,
    required String body,
    String ask = '',
    List<JournalTheme> themes = const [],
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final entry = JournalEntry(
      // Monotonic enough for a single device, and readable in an export.
      id: '${now.microsecondsSinceEpoch}',
      createdAt: now,
      kind: kind,
      title: title.trim(),
      body: body.trim(),
      ask: ask.trim(),
      themes: themes,
    );
    state = List.unmodifiable([entry, ...state].take(_maxEntries));
    await _persist();
    return entry;
  }

  /// Replaces the themes on an entry, so the 30-day trends reflect what the
  /// user thinks it was about rather than only what a keyword pass guessed.
  Future<void> setThemes(String id, List<JournalTheme> themes) async {
    state = List.unmodifiable([
      for (final e in state)
        if (e.id == id)
          JournalEntry(
            id: e.id,
            createdAt: e.createdAt,
            kind: e.kind,
            title: e.title,
            body: e.body,
            ask: e.ask,
            themes: themes,
            reflection: e.reflection,
          )
        else
          e,
    ]);
    await _persist();
  }

  Future<void> setReflection(String id, String reflection) async {
    state = List.unmodifiable([
      for (final e in state)
        if (e.id == id)
          JournalEntry(
            id: e.id,
            createdAt: e.createdAt,
            kind: e.kind,
            title: e.title,
            body: e.body,
            ask: e.ask,
            themes: e.themes,
            reflection: reflection.trim(),
          )
        else
          e,
    ]);
    await _persist();
  }

  Future<void> remove(String id) async {
    state = List.unmodifiable(state.where((e) => e.id != id));
    await _persist();
  }

  Future<void> clear() async {
    state = const [];
    await _prefs.remove(_journalKey);
  }

  /// How often each theme appears in the last [days] days, for the trend row.
  Map<JournalTheme, int> themeCounts({int days = 30}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final counts = <JournalTheme, int>{};
    for (final e in state) {
      if (e.createdAt.isBefore(cutoff)) continue;
      for (final t in e.themes) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<void> _persist() => _prefs.setString(
      _journalKey, jsonEncode([for (final e in state) e.toJson()]));
}

final journalProvider = StateNotifierProvider<JournalStore, List<JournalEntry>>(
  (ref) => JournalStore(ref.watch(keyValueStoreProvider)),
);

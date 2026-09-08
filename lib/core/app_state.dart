import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'key_value_store.dart';

enum AppLanguage {
  en('en', 'English'),
  hi('hi', 'हिंदी');

  const AppLanguage(this.code, this.label);
  final String code;
  final String label;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) =>
      values.firstWhere((l) => l.code == code, orElse: () => AppLanguage.en);
}

enum RelationshipStage {
  dating('dating'),
  engaged('engaged'),
  married('married'),
  longDistance('long_distance'),
  roughPatch('rough_patch');

  const RelationshipStage(this.id);
  final String id;

  static RelationshipStage? fromId(String? id) {
    if (id == null) return null;
    for (final s in values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// One day's 30-second check-in.
@immutable
class DailyPulse {
  const DailyPulse(
      {required this.day, required this.connection, this.word = ''});

  /// `yyyy-MM-dd` in the device's local time. Stored as a string rather than a
  /// [DateTime] so a check-in stays attached to the day the user experienced,
  /// not to a UTC instant that shifts across a timezone change.
  final String day;
  final int connection;
  final String word;

  Map<String, Object?> toJson() =>
      {'day': day, 'connection': connection, 'word': word};

  static DailyPulse? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final day = raw['day'];
    final connection = raw['connection'];
    if (day is! String || connection is! int) return null;
    return DailyPulse(
      day: day,
      connection: connection.clamp(1, 5),
      word: raw['word'] is String ? raw['word'] as String : '',
    );
  }
}

/// Everything the app needs to remember between launches.
///
/// Persisted with SharedPreferences. Drift replaces this once the couple layer
/// needs relational data (repairs, chat history, memory wall); the shape here is
/// deliberately small and JSON-serialisable so that migration is a copy, not a
/// rewrite — and so that "export everything" is one call, not a crawl.
@immutable
class AppState {
  const AppState({
    this.language = AppLanguage.en,
    this.themeMode = ThemeMode.system,
    this.onboarded = false,
    this.userName = '',
    this.partnerName = '',
    this.relationshipStage,
    this.originStory = '',
    this.pulses = const [],
    this.safetyNoticeSeen = false,
  });

  final AppLanguage language;
  final ThemeMode themeMode;
  final bool onboarded;
  final String userName;
  final String partnerName;
  final RelationshipStage? relationshipStage;
  final String originStory;

  /// Newest first, capped at [_maxPulses].
  final List<DailyPulse> pulses;

  /// Whether the user has already seen the "Saath is not a therapist" notice.
  final bool safetyNoticeSeen;

  bool get isHindi => language == AppLanguage.hi;

  /// Never returns an empty string, so no screen can render "You raised it
  /// while  was busy".
  String get partnerOrDefault => partnerName.trim().isEmpty
      ? (isHindi ? 'आपका साथी' : 'your partner')
      : partnerName.trim();

  String get userOrDefault =>
      userName.trim().isEmpty ? (isHindi ? 'आप' : 'you') : userName.trim();

  DailyPulse? get todayPulse {
    final today = AppState.dayKey(DateTime.now());
    for (final p in pulses) {
      if (p.day == today) return p;
    }
    return null;
  }

  int? get todayConnection => todayPulse?.connection;
  String get todayWord => todayPulse?.word ?? '';

  /// Check-ins inside the last 7 days, for the "n of 7" card. Counted from
  /// stored days rather than a running tally, so it stays right after a
  /// reinstall, a timezone hop or a day the app never opened.
  int get checkInsThisWeek {
    final now = DateTime.now();
    final week = <String>{
      for (var i = 0; i < 7; i++)
        AppState.dayKey(now.subtract(Duration(days: i))),
    };
    return pulses.where((p) => week.contains(p.day)).length;
  }

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  AppState copyWith({
    AppLanguage? language,
    ThemeMode? themeMode,
    bool? onboarded,
    String? userName,
    String? partnerName,
    RelationshipStage? relationshipStage,
    bool clearRelationshipStage = false,
    String? originStory,
    List<DailyPulse>? pulses,
    bool? safetyNoticeSeen,
  }) {
    return AppState(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      onboarded: onboarded ?? this.onboarded,
      userName: userName ?? this.userName,
      partnerName: partnerName ?? this.partnerName,
      relationshipStage: clearRelationshipStage
          ? null
          : (relationshipStage ?? this.relationshipStage),
      originStory: originStory ?? this.originStory,
      pulses: pulses ?? this.pulses,
      safetyNoticeSeen: safetyNoticeSeen ?? this.safetyNoticeSeen,
    );
  }

  /// The user-facing half of "export all data". [JournalStore] adds its own
  /// section; nothing else is stored anywhere.
  Map<String, Object?> toJson() => {
        'language': language.code,
        'themeMode': themeMode.name,
        'onboarded': onboarded,
        'userName': userName,
        'partnerName': partnerName,
        'relationshipStage': relationshipStage?.id,
        'originStory': originStory,
        'pulses': [for (final p in pulses) p.toJson()],
      };
}

/// Keys are namespaced so a future store cannot collide with these, and so
/// `reset()` can be selective if we ever need it to be.
class _Keys {
  static const language = 'saath.language';
  static const themeMode = 'saath.themeMode';
  static const onboarded = 'saath.onboarded';
  static const userName = 'saath.userName';
  static const partnerName = 'saath.partnerName';
  static const relationshipStage = 'saath.relationshipStage';
  static const originStory = 'saath.originStory';
  static const pulses = 'saath.pulses';
  static const safetyNoticeSeen = 'saath.safetyNoticeSeen';
}

const _maxPulses = 400;

class AppStateNotifier extends StateNotifier<AppState> {
  AppStateNotifier(this._prefs) : super(load(_prefs));

  final KeyValueStore _prefs;

  @visibleForTesting
  static AppState load(KeyValueStore p) {
    return AppState(
      language: AppLanguage.fromCode(p.getString(_Keys.language)),
      themeMode: _themeModeFromName(p.getString(_Keys.themeMode)),
      onboarded: p.getBool(_Keys.onboarded) ?? false,
      userName: p.getString(_Keys.userName) ?? '',
      partnerName: p.getString(_Keys.partnerName) ?? '',
      relationshipStage:
          RelationshipStage.fromId(p.getString(_Keys.relationshipStage)),
      originStory: p.getString(_Keys.originStory) ?? '',
      pulses: _decodePulses(p.getString(_Keys.pulses)),
      safetyNoticeSeen: p.getBool(_Keys.safetyNoticeSeen) ?? false,
    );
  }

  static ThemeMode _themeModeFromName(String? name) {
    for (final m in ThemeMode.values) {
      if (m.name == name) return m;
    }
    return ThemeMode.system;
  }

  /// Corrupt or half-written preferences must not brick the app on launch: a
  /// user who cannot get past the splash screen has lost their journal as
  /// surely as if we deleted it. Anything unreadable degrades to "no pulses".
  static List<DailyPulse> _decodePulses(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (DailyPulse.fromJson(item) case final p?) p,
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<void> setLanguage(AppLanguage l) async {
    state = state.copyWith(language: l);
    await _prefs.setString(_Keys.language, l.code);
  }

  Future<void> setThemeMode(ThemeMode m) async {
    state = state.copyWith(themeMode: m);
    await _prefs.setString(_Keys.themeMode, m.name);
  }

  Future<void> setNames({required String user, required String partner}) async {
    final u = user.trim();
    final p = partner.trim();
    state = state.copyWith(userName: u, partnerName: p);
    await _prefs.setString(_Keys.userName, u);
    await _prefs.setString(_Keys.partnerName, p);
  }

  Future<void> setRelationshipStage(RelationshipStage s) async {
    state = state.copyWith(relationshipStage: s);
    await _prefs.setString(_Keys.relationshipStage, s.id);
  }

  Future<void> setOriginStory(String text) async {
    final t = text.trim();
    state = state.copyWith(originStory: t);
    await _prefs.setString(_Keys.originStory, t);
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(onboarded: true);
    await _prefs.setBool(_Keys.onboarded, true);
  }

  Future<void> markSafetyNoticeSeen() async {
    if (state.safetyNoticeSeen) return;
    state = state.copyWith(safetyNoticeSeen: true);
    await _prefs.setBool(_Keys.safetyNoticeSeen, true);
  }

  /// Records (or replaces) today's check-in. Tapping 3 then 4 leaves one entry
  /// for today, not two — the streak counts days, not taps.
  Future<void> checkIn({required int connection, String? word}) async {
    final today = AppState.dayKey(DateTime.now());
    final existing = state.todayPulse;
    final pulse = DailyPulse(
      day: today,
      connection: connection.clamp(1, 5),
      word: (word ?? existing?.word ?? '').trim(),
    );
    final next = [pulse, ...state.pulses.where((p) => p.day != today)]
        .take(_maxPulses)
        .toList(growable: false);
    state = state.copyWith(pulses: next);
    await _persistPulses(next);
  }

  /// Sets today's one word without disturbing the connection score. Does
  /// nothing before a score exists — the word is an annotation, not an entry.
  Future<void> setTodayWord(String word) async {
    final existing = state.todayPulse;
    if (existing == null) return;
    await checkIn(connection: existing.connection, word: word);
  }

  Future<void> _persistPulses(List<DailyPulse> pulses) => _prefs.setString(
      _Keys.pulses, jsonEncode([for (final p in pulses) p.toJson()]));

  /// Settings → Delete everything. Clears only Saath's own keys, so a
  /// SharedPreferences instance shared with a future plugin is left alone.
  Future<void> reset() async {
    for (final key in [
      _Keys.language,
      _Keys.themeMode,
      _Keys.onboarded,
      _Keys.userName,
      _Keys.partnerName,
      _Keys.relationshipStage,
      _Keys.originStory,
      _Keys.pulses,
      _Keys.safetyNoticeSeen,
    ]) {
      await _prefs.remove(key);
    }
    state = const AppState();
  }
}

/// Overridden in [main] with the resolved store so that every read is
/// synchronous and no screen has to render a loading state for a preference.
final keyValueStoreProvider = Provider<KeyValueStore>(
  (_) => throw UnimplementedError(
      'keyValueStoreProvider must be overridden in main()'),
);

final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>(
  (ref) => AppStateNotifier(ref.watch(keyValueStoreProvider)),
);

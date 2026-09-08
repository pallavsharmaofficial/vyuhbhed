import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/key_value_store.dart';
import 'coach_engine.dart';
import 'profile.dart';

// ── Applications ─────────────────────────────────────────────────────────────

enum AppStage {
  saved('saved'),
  applied('applied'),
  screening('screening'),
  interview('interview'),
  offer('offer'),
  rejected('rejected');

  const AppStage(this.id);
  final String id;
  static AppStage fromId(String? id) =>
      values.firstWhere((s) => s.id == id, orElse: () => AppStage.saved);
  bool get isOpen => this != AppStage.rejected && this != AppStage.offer;
}

@immutable
class JobApplication {
  const JobApplication({
    required this.id,
    required this.company,
    required this.role,
    required this.stage,
    required this.createdAt,
    required this.updatedAt,
    this.link = '',
    this.notes = '',
  });

  final String id;
  final String company;
  final String role;
  final AppStage stage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String link;
  final String notes;

  JobApplication copyWith(
          {String? company,
          String? role,
          AppStage? stage,
          String? link,
          String? notes}) =>
      JobApplication(
        id: id,
        company: company ?? this.company,
        role: role ?? this.role,
        stage: stage ?? this.stage,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        link: link ?? this.link,
        notes: notes ?? this.notes,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'company': company,
        'role': role,
        'stage': stage.id,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'link': link,
        'notes': notes,
      };

  static JobApplication? fromJson(Object? raw) {
    if (raw is! Map || raw['id'] is! String || raw['company'] is! String) {
      return null;
    }
    final c = DateTime.tryParse('${raw['createdAt']}');
    if (c == null) return null;
    return JobApplication(
      id: raw['id'] as String,
      company: raw['company'] as String,
      role: raw['role'] is String ? raw['role'] as String : '',
      stage: AppStage.fromId(
          raw['stage'] is String ? raw['stage'] as String : null),
      createdAt: c,
      updatedAt: DateTime.tryParse('${raw['updatedAt']}') ?? c,
      link: raw['link'] is String ? raw['link'] as String : '',
      notes: raw['notes'] is String ? raw['notes'] as String : '',
    );
  }
}

class ApplicationStore extends StateNotifier<List<JobApplication>> {
  ApplicationStore(this._prefs) : super(load(_prefs));
  final KeyValueStore _prefs;
  static const _key = 'vyuhbhed.applications';

  @visibleForTesting
  static List<JobApplication> load(KeyValueStore p) {
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final l = jsonDecode(raw);
      return l is List
          ? [
              for (final x in l)
                if (JobApplication.fromJson(x) case final a?) a
            ]
          : const [];
    } on FormatException {
      return const [];
    }
  }

  Future<JobApplication> add({
    required String company,
    required String role,
    String link = '',
    AppStage stage = AppStage.applied,
    DateTime? at,
    String? id,
  }) async {
    final now = at ?? DateTime.now();
    final a = JobApplication(
      id: id ?? now.microsecondsSinceEpoch.toRadixString(36),
      company: company.trim(),
      role: role.trim(),
      stage: stage,
      createdAt: now,
      updatedAt: now,
      link: link.trim(),
    );
    state = [a, ...state];
    await _persist();
    return a;
  }

  Future<void> setStage(String id, AppStage stage) async {
    state = [
      for (final a in state)
        if (a.id == id) a.copyWith(stage: stage) else a
    ];
    await _persist();
  }

  Future<void> setNotes(String id, String notes) async {
    state = [
      for (final a in state)
        if (a.id == id) a.copyWith(notes: notes) else a
    ];
    await _persist();
  }

  Future<void> remove(String id) async {
    state = [
      for (final a in state)
        if (a.id != id) a
    ];
    await _persist();
  }

  Future<void> clear() async {
    state = const [];
    await _prefs.remove(_key);
  }

  Future<void> _persist() =>
      _prefs.setString(_key, jsonEncode([for (final a in state) a.toJson()]));
}

final applicationsProvider =
    StateNotifierProvider<ApplicationStore, List<JobApplication>>(
        (ref) => ApplicationStore(ref.watch(keyValueStoreProvider)));

// ── Mock interviews (in-app and logged from outside) ─────────────────────────

@immutable
class MockSession {
  const MockSession({
    required this.id,
    required this.at,
    required this.round,
    required this.inApp,
    required this.questions,
    required this.scores,
    this.company = '',
    this.notes = '',
  });

  final String id;
  final DateTime at;
  final InterviewRound round;

  /// False for a real or external interview the candidate logged by hand.
  final bool inApp;
  final int questions;

  /// Scores out of 10 (structure + specificity); empty for external logs.
  final List<int> scores;
  final String company;
  final String notes;

  double? get average =>
      scores.isEmpty ? null : scores.reduce((a, b) => a + b) / scores.length;

  Map<String, Object?> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'round': round.id,
        'inApp': inApp,
        'questions': questions,
        'scores': scores,
        'company': company,
        'notes': notes,
      };

  static MockSession? fromJson(Object? raw) {
    if (raw is! Map || raw['id'] is! String) return null;
    final at = DateTime.tryParse('${raw['at']}');
    if (at == null) return null;
    final sc = raw['scores'];
    return MockSession(
      id: raw['id'] as String,
      at: at,
      round: InterviewRound.fromId(
          raw['round'] is String ? raw['round'] as String : null),
      inApp: raw['inApp'] == true,
      questions: raw['questions'] is int ? raw['questions'] as int : 0,
      scores: sc is List
          ? [
              for (final x in sc)
                if (x is int) x
            ]
          : const [],
      company: raw['company'] is String ? raw['company'] as String : '',
      notes: raw['notes'] is String ? raw['notes'] as String : '',
    );
  }
}

class MockStore extends StateNotifier<List<MockSession>> {
  MockStore(this._prefs) : super(load(_prefs));
  final KeyValueStore _prefs;
  static const _key = 'vyuhbhed.mocks';

  @visibleForTesting
  static List<MockSession> load(KeyValueStore p) {
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final l = jsonDecode(raw);
      return l is List
          ? [
              for (final x in l)
                if (MockSession.fromJson(x) case final m?) m
            ]
          : const [];
    } on FormatException {
      return const [];
    }
  }

  Future<void> add({
    required InterviewRound round,
    required bool inApp,
    required int questions,
    List<int> scores = const [],
    String company = '',
    String notes = '',
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    state = [
      MockSession(
        id: now.microsecondsSinceEpoch.toRadixString(36),
        at: now,
        round: round,
        inApp: inApp,
        questions: questions,
        scores: scores,
        company: company.trim(),
        notes: notes.trim(),
      ),
      ...state,
    ];
    await _prefs.setString(
        _key, jsonEncode([for (final m in state) m.toJson()]));
  }

  Future<void> clear() async {
    state = const [];
    await _prefs.remove(_key);
  }
}

final mocksProvider = StateNotifierProvider<MockStore, List<MockSession>>(
    (ref) => MockStore(ref.watch(keyValueStoreProvider)));

// ── Daily plan (rule-based; no model needed) ─────────────────────────────────

/// What "today" asks of the candidate, computed from the profile and what has
/// already been logged today. Deterministic on purpose: a plan that changes
/// every time the model is asked is not a plan.
@immutable
class DailyPlan {
  const DailyPlan({
    required this.applicationsTarget,
    required this.applicationsDone,
    required this.mockDone,
    required this.learnDone,
    required this.checkedIn,
    required this.offers,
    required this.targetOffers,
    required this.daysLeft,
    required this.openPipeline,
  });

  final int applicationsTarget;
  final int applicationsDone;
  final bool mockDone;
  final bool learnDone;
  final bool checkedIn;
  final int offers;
  final int targetOffers;
  final int? daysLeft;
  final int openPipeline;

  bool get applicationsMet => applicationsDone >= applicationsTarget;
  int get stepsTotal => 4;
  int get stepsDone =>
      (applicationsMet ? 1 : 0) +
      (mockDone ? 1 : 0) +
      (learnDone ? 1 : 0) +
      (checkedIn ? 1 : 0);

  /// The single next thing, in priority order. The whole app is this line.
  NextAction get next {
    if (!checkedIn) return NextAction.checkIn;
    if (!applicationsMet) return NextAction.apply;
    if (!mockDone) return NextAction.mock;
    if (!learnDone) return NextAction.learn;
    return NextAction.rest;
  }
}

enum NextAction { checkIn, apply, mock, learn, rest }

/// "Learned something today" is a one-tap log, persisted per day.
class LearnLogStore extends StateNotifier<Set<String>> {
  LearnLogStore(this._prefs) : super(load(_prefs));
  final KeyValueStore _prefs;
  static const _key = 'vyuhbhed.learnDays';

  @visibleForTesting
  static Set<String> load(KeyValueStore p) {
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final l = jsonDecode(raw);
      return l is List
          ? {
              for (final x in l)
                if (x is String) x
            }
          : const {};
    } on FormatException {
      return const {};
    }
  }

  Future<void> markToday() async {
    state = {...state, AppState.dayKey(DateTime.now())};
    await _prefs.setString(_key, jsonEncode(state.toList()));
  }

  Future<void> clear() async {
    state = const {};
    await _prefs.remove(_key);
  }
}

final learnLogProvider = StateNotifierProvider<LearnLogStore, Set<String>>(
    (ref) => LearnLogStore(ref.watch(keyValueStoreProvider)));

final dailyPlanProvider = Provider<DailyPlan>((ref) {
  final profile = ref.watch(profileProvider);
  final apps = ref.watch(applicationsProvider);
  final mocks = ref.watch(mocksProvider);
  final learned = ref.watch(learnLogProvider);
  final app = ref.watch(appStateProvider);
  final today = AppState.dayKey(DateTime.now());
  bool isToday(DateTime d) => AppState.dayKey(d) == today;

  return DailyPlan(
    applicationsTarget: profile.applicationsPerDay,
    applicationsDone: apps
        .where((a) => isToday(a.createdAt) && a.stage != AppStage.saved)
        .length,
    mockDone: mocks.any((m) => isToday(m.at)),
    learnDone: learned.contains(today),
    checkedIn: app.todayPulse != null,
    offers: apps.where((a) => a.stage == AppStage.offer).length,
    targetOffers: profile.targetOffers,
    daysLeft: profile.daysLeft,
    openPipeline:
        apps.where((a) => a.stage.isOpen && a.stage != AppStage.saved).length,
  );
});

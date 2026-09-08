import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/key_value_store.dart';

/// Who the candidate is and what they are aiming at. Everything the coach says
/// is conditioned on this, so it is set in onboarding and editable in Settings.
@immutable
class CoachProfile {
  const CoachProfile({
    this.name = '',
    this.currentRole = '',
    this.targetRole = '',
    this.yearsExperience = 0,
    this.location = '',
    this.skills = '',
    this.noticeEnd,
    this.targetOffers = 10,
    this.applicationsPerDay = 5,
  });

  final String name;
  final String currentRole;
  final String targetRole;
  final int yearsExperience;
  final String location;

  /// Comma-separated, as typed. Fed to prompts and to the job-search links.
  final String skills;
  final DateTime? noticeEnd;
  final int targetOffers;
  final int applicationsPerDay;

  bool get isComplete => targetRole.trim().isNotEmpty;

  int? get daysLeft {
    final end = noticeEnd;
    if (end == null) return null;
    final today = DateTime.now();
    return DateTime(end.year, end.month, end.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
  }

  CoachProfile copyWith({
    String? name,
    String? currentRole,
    String? targetRole,
    int? yearsExperience,
    String? location,
    String? skills,
    DateTime? noticeEnd,
    bool clearNoticeEnd = false,
    int? targetOffers,
    int? applicationsPerDay,
  }) =>
      CoachProfile(
        name: name ?? this.name,
        currentRole: currentRole ?? this.currentRole,
        targetRole: targetRole ?? this.targetRole,
        yearsExperience: yearsExperience ?? this.yearsExperience,
        location: location ?? this.location,
        skills: skills ?? this.skills,
        noticeEnd: clearNoticeEnd ? null : (noticeEnd ?? this.noticeEnd),
        targetOffers: targetOffers ?? this.targetOffers,
        applicationsPerDay: applicationsPerDay ?? this.applicationsPerDay,
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'currentRole': currentRole,
        'targetRole': targetRole,
        'yearsExperience': yearsExperience,
        'location': location,
        'skills': skills,
        'noticeEnd': noticeEnd?.toIso8601String(),
        'targetOffers': targetOffers,
        'applicationsPerDay': applicationsPerDay,
      };

  static CoachProfile fromJson(Object? raw) {
    if (raw is! Map) return const CoachProfile();
    String s(String k) => raw[k] is String ? raw[k] as String : '';
    int i(String k, int d) => raw[k] is int ? raw[k] as int : d;
    return CoachProfile(
      name: s('name'),
      currentRole: s('currentRole'),
      targetRole: s('targetRole'),
      yearsExperience: i('yearsExperience', 0),
      location: s('location'),
      skills: s('skills'),
      noticeEnd: raw['noticeEnd'] is String
          ? DateTime.tryParse(raw['noticeEnd'] as String)
          : null,
      targetOffers: i('targetOffers', 10),
      applicationsPerDay: i('applicationsPerDay', 5),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CoachProfile &&
      other.name == name &&
      other.currentRole == currentRole &&
      other.targetRole == targetRole &&
      other.yearsExperience == yearsExperience &&
      other.location == location &&
      other.skills == skills &&
      other.noticeEnd == noticeEnd &&
      other.targetOffers == targetOffers &&
      other.applicationsPerDay == applicationsPerDay;

  @override
  int get hashCode => Object.hash(
      name,
      currentRole,
      targetRole,
      yearsExperience,
      location,
      skills,
      noticeEnd,
      targetOffers,
      applicationsPerDay);
}

class ProfileStore extends StateNotifier<CoachProfile> {
  ProfileStore(this._prefs) : super(load(_prefs));
  final KeyValueStore _prefs;
  static const _key = 'vyuhbhed.profile';

  @visibleForTesting
  static CoachProfile load(KeyValueStore p) {
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return const CoachProfile();
    try {
      return CoachProfile.fromJson(jsonDecode(raw));
    } on FormatException {
      return const CoachProfile();
    }
  }

  Future<void> save(CoachProfile profile) async {
    state = profile;
    await _prefs.setString(_key, jsonEncode(profile.toJson()));
  }

  Future<void> clear() async {
    state = const CoachProfile();
    await _prefs.remove(_key);
  }
}

final profileProvider = StateNotifierProvider<ProfileStore, CoachProfile>(
    (ref) => ProfileStore(ref.watch(keyValueStoreProvider)));

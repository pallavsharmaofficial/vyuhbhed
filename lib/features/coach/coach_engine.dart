import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/app_state.dart';
import '../../core/key_value_store.dart';
import '../counsellor/engine.dart' show CounsellorException;
import '../counsellor/model/model_catalogue.dart';
import '../counsellor/model/model_manager.dart';
import '../counsellor/model/prompts.dart' show Prompts;
import 'coach_prompts.dart';
import 'profile.dart';

// ── Results ──────────────────────────────────────────────────────────────────

@immutable
class MockQuestion {
  const MockQuestion({required this.question, required this.lookingFor});
  final String question;

  /// What a strong answer covers — shown after the candidate answers.
  final String lookingFor;

  Map<String, Object?> toJson() =>
      {'question': question, 'lookingFor': lookingFor};
  static MockQuestion? fromJson(Object? raw) {
    if (raw is! Map || raw['question'] is! String) return null;
    final q = (raw['question'] as String).trim();
    if (q.isEmpty) return null;
    return MockQuestion(
        question: q,
        lookingFor:
            raw['lookingFor'] is String ? raw['lookingFor'] as String : '');
  }
}

@immutable
class AnswerScore {
  const AnswerScore({
    required this.structure,
    required this.specificity,
    required this.feedback,
    required this.strongerAnswer,
  });

  /// 1–5 each.
  final int structure;
  final int specificity;
  final String feedback;
  final String strongerAnswer;

  int get total => structure + specificity;

  Map<String, Object?> toJson() => {
        'structure': structure,
        'specificity': specificity,
        'feedback': feedback,
        'strongerAnswer': strongerAnswer,
      };
  static AnswerScore? fromJson(Object? raw) {
    if (raw is! Map) return null;
    int n(Object? v) => (v is int ? v : int.tryParse('$v') ?? 3).clamp(1, 5);
    return AnswerScore(
      structure: n(raw['structure']),
      specificity: n(raw['specificity']),
      feedback: raw['feedback'] is String ? raw['feedback'] as String : '',
      strongerAnswer: raw['strongerAnswer'] is String
          ? raw['strongerAnswer'] as String
          : '',
    );
  }
}

@immutable
class ResumeReview {
  const ResumeReview({
    required this.verdict,
    required this.fixes,
    required this.rewrittenBullets,
    required this.missingKeywords,
  });
  final String verdict;
  final List<String> fixes;
  final List<String> rewrittenBullets;
  final List<String> missingKeywords;
}

// ── Requests (value-equal, so family providers do not regenerate) ────────────

@immutable
class QuestionsRequest {
  const QuestionsRequest(
      {required this.profile, required this.round, required this.hindi});
  final CoachProfile profile;
  final InterviewRound round;
  final bool hindi;
  @override
  bool operator ==(Object other) =>
      other is QuestionsRequest &&
      other.profile == profile &&
      other.round == round &&
      other.hindi == hindi;
  @override
  int get hashCode => Object.hash(profile, round, hindi);
}

@immutable
class ResumeRequest {
  const ResumeRequest(
      {required this.resume,
      required this.jobDescription,
      required this.profile,
      required this.hindi});
  final String resume;
  final String jobDescription;
  final CoachProfile profile;
  final bool hindi;
  @override
  bool operator ==(Object other) =>
      other is ResumeRequest &&
      other.resume == resume &&
      other.jobDescription == jobDescription &&
      other.profile == profile &&
      other.hindi == hindi;
  @override
  int get hashCode => Object.hash(resume, jobDescription, profile, hindi);
}

enum InterviewRound {
  hr('hr'),
  technical('technical'),
  managerial('managerial'),
  behavioural('behavioural');

  const InterviewRound(this.id);
  final String id;
  static InterviewRound fromId(String? id) =>
      values.firstWhere((r) => r.id == id, orElse: () => InterviewRound.hr);
}

// ── Engine ───────────────────────────────────────────────────────────────────

/// Where answers come from. Online is opt-in: the candidate pastes their own
/// Gemini API key in Settings and everything they type is then sent to Google.
enum EngineKind { preview, onDevice, online }

abstract class CoachEngine {
  EngineKind get kind;
  Future<List<MockQuestion>> questions(QuestionsRequest r);
  Future<AnswerScore> score({
    required MockQuestion question,
    required String answer,
    required CoachProfile profile,
    required bool hindi,
  });
  Future<ResumeReview> reviewResume(ResumeRequest r);
  Future<String> ask(
      {required String question,
      required CoachProfile profile,
      required bool hindi});
}

/// Shared JSON plumbing on top of a single `String Function(String prompt)`.
abstract class _JsonCoachEngine implements CoachEngine {
  Future<String> generate(String prompt);

  Map<String, Object?> _json(String raw) {
    final j = Prompts.extractJson(raw);
    if (j == null) {
      throw const CounsellorException(
          'the model did not return a usable answer');
    }
    return j;
  }

  static List<String> _strings(Object? raw) => raw is List
      ? [
          for (final x in raw)
            if (x is String && x.trim().isNotEmpty) x.trim()
        ]
      : const [];

  @override
  Future<List<MockQuestion>> questions(QuestionsRequest r) async {
    final j = _json(await generate(CoachPrompts.questions(r)));
    final list = j['questions'];
    final qs = list is List
        ? [
            for (final x in list)
              if (MockQuestion.fromJson(x) case final q?) q
          ]
        : <MockQuestion>[];
    if (qs.isEmpty) throw const CounsellorException('no questions came back');
    return qs;
  }

  @override
  Future<AnswerScore> score(
      {required MockQuestion question,
      required String answer,
      required CoachProfile profile,
      required bool hindi}) async {
    final j = _json(
        await generate(CoachPrompts.score(question, answer, profile, hindi)));
    return AnswerScore.fromJson(j) ??
        const AnswerScore(
            structure: 3, specificity: 3, feedback: '', strongerAnswer: '');
  }

  @override
  Future<ResumeReview> reviewResume(ResumeRequest r) async {
    final j = _json(await generate(CoachPrompts.resume(r)));
    return ResumeReview(
      verdict: Prompts.stringField(j, 'verdict'),
      fixes: _strings(j['fixes']),
      rewrittenBullets: _strings(j['rewrittenBullets']),
      missingKeywords: _strings(j['missingKeywords']),
    );
  }

  @override
  Future<String> ask(
      {required String question,
      required CoachProfile profile,
      required bool hindi}) async {
    final out =
        (await generate(CoachPrompts.ask(question, profile, hindi))).trim();
    if (out.isEmpty) throw const CounsellorException('empty reply');
    return out;
  }
}

/// Scripted stand-in so every screen works and tests run without a model.
class MockCoachEngine extends _JsonCoachEngine {
  MockCoachEngine({this.delay = const Duration(milliseconds: 400)});
  final Duration delay;

  @override
  EngineKind get kind => EngineKind.preview;

  @override
  Future<String> generate(String prompt) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final hi = prompt.contains('in Hindi');
    if (prompt.contains('"questions"')) {
      return jsonEncode({
        'questions': [
          {
            'question': hi
                ? 'अपने बारे में बताइए और यह भूमिका क्यों?'
                : 'Tell me about yourself, and why this role?',
            'lookingFor': hi
                ? 'दो मिनट, वर्तमान → पिछला → क्यों यहाँ'
                : 'Two minutes: present, past, why here.'
          },
          {
            'question': hi
                ? 'एक मुश्किल तकनीकी समस्या जो आपने हल की?'
                : 'Describe a hard problem you solved recently.',
            'lookingFor': hi
                ? 'स्थिति, आपका फ़ैसला, नतीजा — संख्या के साथ'
                : 'Situation, your decision, the result — with a number.'
          },
          {
            'question': hi
                ? 'आप नौकरी क्यों छोड़ रहे हैं?'
                : 'Why are you leaving your current job?',
            'lookingFor': hi
                ? 'आगे की ओर, बिना शिकायत'
                : 'Forward-looking, no complaints about the employer.'
          },
          {
            'question': hi
                ? 'आपकी अपेक्षित सैलरी?'
                : 'What are your salary expectations?',
            'lookingFor': hi
                ? 'रेंज दीजिए, बाज़ार का आधार बताइए'
                : 'Give a range anchored to market data, not your current CTC.'
          },
          {
            'question':
                hi ? 'कोई सवाल हमारे लिए?' : 'Do you have questions for us?',
            'lookingFor': hi
                ? 'टीम, सफलता का मापदंड, अगला कदम'
                : 'Team, how success is measured, next steps.'
          },
        ]
      });
    }
    if (prompt.contains('"strongerAnswer"')) {
      return jsonEncode({
        'structure': 3,
        'specificity': 2,
        'feedback': hi
            ? 'ढाँचा ठीक है; एक ठोस संख्या या नाम जोड़िए।'
            : 'Structure is fine; add one concrete number or name.',
        'strongerAnswer': hi
            ? 'नमूना इंजन — असली मॉडल आपके जवाब को दोबारा लिखेगा।'
            : 'Sample engine — the real model rewrites your actual answer.',
      });
    }
    if (prompt.contains('"rewrittenBullets"')) {
      return jsonEncode({
        'verdict': hi
            ? 'रिज़्यूमे पढ़ने योग्य है; प्रभाव की संख्याएँ कम हैं।'
            : 'Readable resume; light on measurable impact.',
        'fixes': [
          hi ? 'हर बुलेट में एक संख्या' : 'One number per bullet',
          hi ? 'सारांश को 3 पंक्तियों में' : 'Cut the summary to 3 lines'
        ],
        'rewrittenBullets': [
          hi
              ? 'नमूना: 40% तेज़ रिलीज़ के लिए CI बनाया'
              : 'Sample: Built CI that cut release time 40%'
        ],
        'missingKeywords': ['Flutter', 'CI/CD'],
      });
    }
    return hi
        ? 'नमूना कोच: एक बात आज करें — एक आवेदन, एक मॉक। बाक़ी कल।'
        : 'Sample coach: do one thing today — one application, one mock. The rest is tomorrow.';
  }
}

/// On-device, via the shared LiteRT-LM plumbing.
class GemmaCoachEngine extends _JsonCoachEngine {
  GemmaCoachEngine(this.model);
  final SaathModel model;
  InferenceModel? _inference;
  Future<void> _queue = Future.value();

  @override
  EngineKind get kind => EngineKind.onDevice;

  Future<InferenceModel> _load() async {
    final existing = _inference;
    if (existing != null) return existing;
    try {
      final created = await FlutterGemma.getActiveModel(
          maxTokens: model.maxTokens, preferredBackend: PreferredBackend.gpu);
      _inference = created;
      return created;
    } on Object catch (e) {
      throw CounsellorException('could not load the model: $e');
    }
  }

  static String _asText(Object? r) {
    if (r == null) return '';
    if (r is String) return r;
    if (r is TextResponse) return r.token;
    return r.toString();
  }

  @override
  Future<String> generate(String prompt) {
    final completer = Completer<String>();
    _queue = _queue.then((_) async {
      try {
        final inference = await _load();
        final chat = await inference.openChat();
        await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
        completer.complete(await chat.generateChatResponse().then(_asText));
      } on CounsellorException catch (e, s) {
        completer.completeError(e, s);
      } on Object catch (e, s) {
        completer.completeError(
            CounsellorException('generation failed: $e'), s);
      }
    });
    return completer.future;
  }

  Future<void> dispose() async {
    final i = _inference;
    _inference = null;
    try {
      await i?.close();
    } on Object catch (e) {
      debugPrint('Vyuhbhed: closing the model failed: $e');
    }
  }
}

/// Online, with the candidate's own Gemini API key. Better answers, and the
/// trade is explicit in Settings: what they type leaves the phone.
class OnlineCoachEngine extends _JsonCoachEngine {
  OnlineCoachEngine(this.apiKey, {http.Client? client})
      : _client = client ?? http.Client();
  final String apiKey;
  final http.Client _client;
  static const modelName = 'gemini-2.0-flash';

  @override
  EngineKind get kind => EngineKind.online;

  @override
  Future<String> generate(String prompt) async {
    final uri = Uri.https('generativelanguage.googleapis.com',
        '/v1beta/models/$modelName:generateContent', {'key': apiKey});
    final http.Response res;
    try {
      res = await _client
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': prompt}
                    ]
                  }
                ],
                'generationConfig': {'temperature': 0.4},
              }))
          .timeout(const Duration(seconds: 45));
    } on Object catch (e) {
      throw CounsellorException('network: $e');
    }
    if (res.statusCode != 200) {
      throw CounsellorException('online engine returned ${res.statusCode}');
    }
    final body = jsonDecode(res.body);
    final text = ((((body as Map)['candidates'] as List?)?.firstOrNull
        as Map?)?['content'] as Map?)?['parts'] as List?;
    final out = text == null
        ? ''
        : [
            for (final p in text)
              if (p is Map && p['text'] is String) p['text'] as String
          ].join();
    if (out.trim().isEmpty) throw const CounsellorException('empty reply');
    return out;
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

const _apiKeyKey = 'vyuhbhed.geminiKey';

/// The candidate's own key, stored on the device only. Empty = offline only.
class ApiKeyStore extends StateNotifier<String> {
  ApiKeyStore(this._prefs) : super(_prefs.getString(_apiKeyKey) ?? '');
  final KeyValueStore _prefs;
  Future<void> set(String key) async {
    state = key.trim();
    if (state.isEmpty) {
      await _prefs.remove(_apiKeyKey);
    } else {
      await _prefs.setString(_apiKeyKey, state);
    }
  }
}

final apiKeyProvider = StateNotifierProvider<ApiKeyStore, String>(
    (ref) => ApiKeyStore(ref.watch(keyValueStoreProvider)));

final coachEngineProvider = Provider<CoachEngine>((ref) {
  final key = ref.watch(apiKeyProvider);
  if (key.isNotEmpty) return OnlineCoachEngine(key);
  final installed = ref.watch(modelManagerProvider.select((s) => s.installed));
  if (installed == null) return MockCoachEngine();
  final engine = GemmaCoachEngine(installed);
  ref.onDispose(engine.dispose);
  return engine;
});

final questionsProvider = FutureProvider.autoDispose
    .family<List<MockQuestion>, QuestionsRequest>(
        (ref, r) => ref.read(coachEngineProvider).questions(r));

final resumeReviewProvider = FutureProvider.autoDispose
    .family<ResumeReview, ResumeRequest>(
        (ref, r) => ref.read(coachEngineProvider).reviewResume(r));

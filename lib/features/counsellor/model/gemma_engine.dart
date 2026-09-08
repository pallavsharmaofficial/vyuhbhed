import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../../../core/journal.dart';
import '../engine.dart';
import '../safety.dart';
import 'model_catalogue.dart';
import 'prompts.dart';

/// The on-device counsellor.
///
/// Everything above [CounsellorEngine] is unchanged by this file existing —
/// that was the point of the interface. The UI still does not know which
/// engine is answering.
///
/// Two things are deliberate here:
///
/// * **The chat session is kept alive and fed incrementally.** Rebuilding it
///   per turn would re-prefill the whole conversation, which on a 4 GB phone
///   is the difference between a two-second wait and a fifteen-second one.
/// * **The safety guardrail is not the model's job.** It runs in
///   [CounsellorEngine], before anything reaches this class. A model cannot be
///   prompted out of a keyword screen it never sees.
class GemmaCounsellorEngine implements CounsellorEngine {
  GemmaCounsellorEngine(this.model);

  final SaathModel model;

  InferenceModel? _inference;
  InferenceChat? _chat;

  /// How many messages of the live conversation the session has already been
  /// fed, so a new turn adds only the delta.
  int _fedMessages = 0;
  String? _sessionPersona;

  /// Serialises access. LiteRT-LM runs one inference at a time; two features
  /// asking at once (a reply streaming while the weekly report generates in
  /// the background) would otherwise interleave tokens.
  Future<void> _queue = Future.value();

  @override
  bool get isPreview => false;

  @override
  bool needsSafetyInterrupt(String input) => safetyClassifier.fires(input);

  Future<InferenceModel> _model() async {
    final existing = _inference;
    if (existing != null) return existing;
    try {
      final created = await FlutterGemma.getActiveModel(
        maxTokens: model.maxTokens,
        preferredBackend: PreferredBackend.gpu,
      );
      _inference = created;
      return created;
    } on Object catch (error) {
      throw CounsellorException('could not load the model: $error');
    }
  }

  /// Runs [body] with exclusive access to the model.
  Future<T> _serialised<T>(Future<T> Function() body) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await body());
      } on Object catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  /// A throwaway session for one-shot, structured requests. Kept separate from
  /// the conversation so an Untangle never pollutes the chat's context.
  Future<String> _oneShot(String prompt, CounsellorContext ctx) async {
    final inference = await _model();
    InferenceChat? chat;
    try {
      chat = await inference.openChat();
      await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
      return await chat.generateChatResponse().then(_asText);
    } on CounsellorException {
      rethrow;
    } on Object catch (error) {
      throw CounsellorException('generation failed: $error');
    }
  }

  static String _asText(Object? response) {
    if (response == null) return '';
    if (response is String) return response;
    if (response is TextResponse) return response.token;
    return response.toString();
  }

  @override
  Stream<String> reply(List<ChatMessage> history, CounsellorContext ctx) {
    final controller = StreamController<String>();
    StreamSubscription<ModelResponse>? sub;

    controller.onCancel = () async {
      // Cancelling the UI subscription must actually stop generation, or the
      // model keeps burning battery for a conversation nobody is reading.
      await sub?.cancel();
    };

    unawaited(
      _serialised(() async {
        final chat = await _chatFor(ctx);
        // Feed only what the session has not seen.
        final pending = history.skip(_fedMessages).where((m) => m.fromUser);
        for (final m in pending) {
          await chat.addQueryChunk(Message.text(text: m.text, isUser: true));
        }
        _fedMessages = history.length;

        final done = Completer<void>();
        sub = chat.generateChatResponseAsync().listen(
          (response) {
            if (response is TextResponse) controller.add(response.token);
          },
          onError: (Object e, StackTrace s) {
            if (!controller.isClosed) {
              controller.addError(CounsellorException('$e'), s);
            }
            if (!done.isCompleted) done.complete();
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
          cancelOnError: true,
        );
        await done.future;
      }).catchError((Object error, StackTrace stack) {
        if (!controller.isClosed) controller.addError(error, stack);
      }).whenComplete(() async {
        await sub?.cancel();
        if (!controller.isClosed) await controller.close();
      }),
    );

    return controller.stream;
  }

  Future<InferenceChat> _chatFor(CounsellorContext ctx) async {
    final persona = Prompts.persona(ctx);
    final existing = _chat;
    // The persona carries the partner's name, the language and the origin
    // story. If any of those changed, the old session is stale.
    if (existing != null && _sessionPersona == persona) return existing;

    final inference = await _model();
    final chat = await inference.createChat(
      systemInstruction: persona,
      maxOutputTokens: 320,
    );
    _chat = chat;
    _sessionPersona = persona;
    _fedMessages = 0;
    return chat;
  }

  /// Drops the conversation session. Called when the user clears the chat.
  Future<void> resetConversation() async {
    _chat = null;
    _sessionPersona = null;
    _fedMessages = 0;
  }

  @override
  Future<Untangled> untangle(String vent, CounsellorContext ctx) async {
    if (vent.trim().isEmpty) {
      throw const CounsellorException('nothing to untangle');
    }
    final raw =
        await _serialised(() => _oneShot(Prompts.untangle(vent, ctx), ctx));
    final json = Prompts.extractJson(raw);
    if (json == null) {
      throw const CounsellorException(
          'the model did not return a usable answer');
    }

    final happened = Prompts.stringField(json, 'happened');
    final sentence = Prompts.stringField(json, 'sentence');
    // A breakdown with no facts and nothing to say is not a partial success.
    if (happened.isEmpty || sentence.isEmpty) {
      throw const CounsellorException(
          'the model returned an incomplete answer');
    }

    return Untangled(
      happened: happened,
      assumed: Prompts.stringField(json, 'assumed'),
      felt: Prompts.stringField(json, 'felt'),
      need: Prompts.stringField(json, 'need'),
      sentence: sentence,
      themes: _themes(json['themes']),
    );
  }

  static List<JournalTheme> _themes(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final t in raw)
        if (JournalTheme.fromId(t is String ? t.toLowerCase().trim() : null)
            case final theme?)
          theme,
    ];
  }

  @override
  Future<RepairMerge> mergeRepair(
      RepairSides sides, CounsellorContext ctx) async {
    if (!sides.isComplete) {
      throw const CounsellorException('both sides are needed');
    }
    final raw =
        await _serialised(() => _oneShot(Prompts.mergeRepair(sides, ctx), ctx));
    final json = Prompts.extractJson(raw);
    if (json == null) {
      throw const CounsellorException(
          'the model did not return a usable answer');
    }

    // The prompt asks the model to refuse rather than merge when either side
    // describes being hurt. The keyword screen already ran; this is the second
    // net, for the phrasing it cannot catch.
    if (json['unsafe'] == true) {
      throw const UnsafeToMergeException();
    }

    final title = Prompts.stringField(json, 'title');
    if (title.isEmpty) {
      throw const CounsellorException(
          'the model returned an incomplete answer');
    }

    return RepairMerge(
      title: title,
      agreed: Prompts.stringField(json, 'agreed'),
      sideA: Prompts.stringField(json, 'sideA'),
      sideB: Prompts.stringField(json, 'sideB'),
      split: Prompts.stringField(json, 'split'),
      firstTurn: Prompts.stringField(json, 'firstTurn'),
    );
  }

  @override
  Future<KinderRewrite> sayItKinder(String draft, CounsellorContext ctx) async {
    if (draft.trim().isEmpty) {
      throw const CounsellorException('nothing to rewrite');
    }
    final raw =
        await _serialised(() => _oneShot(Prompts.sayItKinder(draft, ctx), ctx));
    final json = Prompts.extractJson(raw);
    if (json == null) {
      throw const CounsellorException(
          'the model did not return a usable answer');
    }
    final rewrite = KinderRewrite(
      kinder: Prompts.stringField(json, 'kinder'),
      clearer: Prompts.stringField(json, 'clearer'),
      shorter: Prompts.stringField(json, 'shorter'),
      keep: Prompts.stringField(json, 'keep'),
    );
    if (rewrite.options(ctx.hindi).isEmpty) {
      throw const CounsellorException('the model returned no rewrites');
    }
    return rewrite;
  }

  @override
  Future<String> reflectOnEntry({
    required String title,
    required String body,
    required String ask,
    required DateTime savedAt,
    required CounsellorContext ctx,
  }) async {
    if (body.trim().isEmpty) {
      throw const CounsellorException('nothing to reflect on');
    }
    final raw = await _serialised(
      () => _oneShot(
        Prompts.reflectOnEntry(
          title: title,
          body: body,
          ask: ask,
          daysAgo: DateTime.now().difference(savedAt).inDays,
          ctx: ctx,
        ),
        ctx,
      ),
    );
    final json = Prompts.extractJson(raw);
    final reflection =
        json == null ? '' : Prompts.stringField(json, 'reflection');
    if (reflection.isEmpty) {
      throw const CounsellorException(
          'the model did not return a usable answer');
    }
    return reflection;
  }

  @override
  Future<WeeklyReflection> weeklyReflection({
    required List<int> scores,
    required List<String> words,
    required int untangles,
    required CounsellorContext ctx,
  }) async {
    if (scores.isEmpty) {
      throw const CounsellorException('no check-ins this week');
    }
    final raw = await _serialised(
      () => _oneShot(
        Prompts.weeklyReflection(
          scores: scores,
          words: words,
          untangles: untangles,
          ctx: ctx,
        ),
        ctx,
      ),
    );
    final json = Prompts.extractJson(raw);
    final reflection =
        json == null ? '' : Prompts.stringField(json, 'reflection');
    if (reflection.isEmpty) {
      throw const CounsellorException(
          'the model did not return a usable answer');
    }
    return WeeklyReflection(
      reflection: reflection,
      suggestion: json == null ? '' : Prompts.stringField(json, 'suggestion'),
    );
  }

  Future<void> dispose() async {
    _chat = null;
    final inference = _inference;
    _inference = null;
    try {
      await inference?.close();
    } on Object catch (error) {
      debugPrint('Saath: closing the model failed: $error');
    }
  }
}

/// Thrown when the merge prompt decides a Repair Room is the wrong place for
/// what was written. The screen shows the safety interrupt instead.
class UnsafeToMergeException extends CounsellorException {
  const UnsafeToMergeException() : super('unsafe to merge');
}

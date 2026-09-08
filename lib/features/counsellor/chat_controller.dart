import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart' show keyValueStoreProvider;
import '../../core/key_value_store.dart';
import 'engine.dart';
import 'safety.dart';

@immutable
class ChatState {
  const ChatState({
    this.messages = const [],
    this.streaming = false,
    this.pendingSafety,
  });

  final List<ChatMessage> messages;
  final bool streaming;

  /// Non-null when the last input tripped the safety screen and the interrupt
  /// has not been shown yet.
  final SafetySignal? pendingSafety;

  bool get canRetry =>
      !streaming && messages.isNotEmpty && messages.last.failed;

  /// The first thing the user said, which is what Untangle works from.
  String? get firstUserMessage {
    for (final m in messages) {
      if (m.fromUser) return m.text;
    }
    return null;
  }

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? streaming,
    SafetySignal? pendingSafety,
    bool clearPendingSafety = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      streaming: streaming ?? this.streaming,
      pendingSafety:
          clearPendingSafety ? null : (pendingSafety ?? this.pendingSafety),
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._ref)
      : super(ChatState(messages: load(_ref.read(keyValueStoreProvider))));

  final Ref _ref;
  StreamSubscription<String>? _sub;
  Completer<void>? _turn;

  static const _key = 'saath.chat';

  /// The conversation used to live only in memory: killing the app mid-thought
  /// lost it. Now it comes back the way the journal does. A half-streamed reply
  /// that never finished is restored as failed, so the UI offers Retry.
  @visibleForTesting
  static List<ChatMessage> load(KeyValueStore prefs) {
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [
        for (final m in list)
          if (m is Map && m['text'] is String && m['fromUser'] is bool)
            ChatMessage(
              fromUser: m['fromUser'] as bool,
              text: m['text'] as String,
              failed: m['failed'] == true,
            ),
      ];
    } on FormatException {
      return const [];
    }
  }

  void _persist() {
    final prefs = _ref.read(keyValueStoreProvider);
    if (state.messages.isEmpty) {
      unawaited(prefs.remove(_key));
      return;
    }
    // Write the messages as they stand; a bubble still streaming is stored
    // as failed so a cold start does not show a sentence that stops mid-word.
    unawaited(prefs.setString(
      _key,
      jsonEncode([
        for (final m in state.messages)
          {
            'fromUser': m.fromUser,
            'text': m.text,
            'failed': m.failed || (state.streaming && m == state.messages.last),
          },
      ]),
    ));
  }

  CounsellorContext get _ctx => _ref.read(counsellorContextProvider);

  Future<void> send(String text) async {
    final t = text.trim();
    if (t.isEmpty || state.streaming) return;

    final engine = _ref.read(counsellorEngineProvider);
    final history = [...state.messages, ChatMessage(fromUser: true, text: t)];

    // The guardrail runs before generation, and its result is not something the
    // model gets a vote on.
    final signal = safetyClassifier.screen(t);
    if (signal != null) {
      state = state.copyWith(messages: history, pendingSafety: signal);
      _persist();
      return;
    }

    await _generate(history, engine);
  }

  /// Re-runs the last turn after a failure. The failed placeholder is dropped
  /// first so a retry does not stack half-sentences.
  Future<void> retry() async {
    if (state.streaming || state.messages.isEmpty) return;
    final withoutFailure = [...state.messages]
      ..removeWhere((m) => !m.fromUser && m.failed);
    if (withoutFailure.isEmpty || !withoutFailure.last.fromUser) return;
    await _generate(withoutFailure, _ref.read(counsellorEngineProvider));
  }

  Future<void> _generate(List<ChatMessage> history, CounsellorEngine engine) {
    _abort();

    var buffer = '';
    state = state.copyWith(
      messages: [...history, const ChatMessage(fromUser: false, text: '')],
      streaming: true,
      clearPendingSafety: true,
    );

    _persist();

    final turn = _turn = Completer<void>();
    void finish() {
      if (!turn.isCompleted) turn.complete();
    }

    _sub = engine.reply(history, _ctx).listen(
      (chunk) {
        buffer += chunk;
        _replaceLast(ChatMessage(fromUser: false, text: buffer));
      },
      onDone: () {
        // An engine that closes without emitting anything is a failure, not an
        // empty reply — otherwise the user is left staring at a blank bubble.
        if (buffer.trim().isEmpty) {
          _replaceLast(
              const ChatMessage(fromUser: false, text: '', failed: true));
        }
        if (mounted) {
          state = state.copyWith(streaming: false);
          _persist();
        }
        finish();
      },
      onError: (Object error, StackTrace stack) {
        _replaceLast(ChatMessage(fromUser: false, text: buffer, failed: true));
        if (mounted) {
          state = state.copyWith(streaming: false);
          _persist();
        }
        finish();
      },
      cancelOnError: true,
    );
    return turn.future;
  }

  /// Detaches from the current generation without waiting for it.
  ///
  /// `StreamSubscription.cancel()` completes only once the producing generator
  /// has finished unwinding. An engine that is blocked on a native call — a
  /// model mid-token, say — will not unwind promptly, and awaiting it froze the
  /// UI on the one control whose whole job is to be instant. So the state moves
  /// now and the cancellation is left to land on its own.
  void _abort() {
    final sub = _sub;
    _sub = null;
    if (sub != null) unawaited(sub.cancel().catchError((Object _) {}));
    final turn = _turn;
    _turn = null;
    if (turn != null && !turn.isCompleted) turn.complete();
  }

  void _replaceLast(ChatMessage message) {
    if (!mounted || state.messages.isEmpty) return;
    final msgs = [...state.messages];
    msgs[msgs.length - 1] = message;
    state = state.copyWith(messages: msgs);
  }

  /// Stops generation and keeps whatever arrived, marked so the UI offers a
  /// retry rather than presenting a truncated sentence as the answer.
  void stop() {
    if (!state.streaming) return;
    _abort();
    if (state.messages.isNotEmpty && !state.messages.last.fromUser) {
      _replaceLast(state.messages.last.copyWith(failed: true));
    }
    state = state.copyWith(streaming: false);
    _persist();
  }

  /// Called once the safety screen has been shown.
  ///
  /// Before this existed, tripping the classifier left the user's message on
  /// screen with no reply at all: they came back from the helplines to a
  /// counsellor that had gone silent on the one thing that mattered most.
  void acknowledgeSafety({required bool hindi}) {
    if (state.pendingSafety == null) return;
    final reply = hindi
        ? 'मैं यहीं हूँ। जो आपने बताया, उस पर मैं सलाह नहीं दूँगा — क्योंकि सुरक्षा पहले आती है, और उसके लिए असली इंसान चाहिए। नंबर सेटिंग्स में हमेशा मौजूद हैं। जब आप चाहें, हम बात कर सकते हैं।'
        : 'I am still here. I am not going to give advice on what you just told me — safety comes before repair, and that needs a real person, not me. The numbers stay in Settings. When you want to talk, I am here.';
    state = state.copyWith(
      messages: [...state.messages, ChatMessage(fromUser: false, text: reply)],
      clearPendingSafety: true,
    );
    _persist();
  }

  void clear() {
    _abort();
    state = const ChatState();
    _persist();
  }

  /// Puts back a conversation handed out by [clear] — the Undo on its snackbar.
  void restore(List<ChatMessage> messages) {
    if (state.streaming || state.messages.isNotEmpty) return;
    state = ChatState(messages: messages);
    _persist();
  }

  @override
  void dispose() {
    _abort();
    super.dispose();
  }
}

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>(ChatController.new);

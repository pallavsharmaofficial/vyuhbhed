import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/app_state.dart';

/// Where speech input currently is.
enum VoiceStatus {
  /// Not started, or finished.
  idle,

  /// Waiting on the OS permission prompt.
  asking,

  /// Microphone is live.
  listening,

  /// No permission, or no recogniser on this device.
  unavailable,
}

@immutable
class VoiceState {
  const VoiceState({
    this.status = VoiceStatus.idle,
    this.transcript = '',
    this.error,
  });

  final VoiceStatus status;

  /// What has been heard so far, including partial results, so the field
  /// fills as the person speaks rather than after they stop.
  final String transcript;

  final String? error;

  bool get isListening => status == VoiceStatus.listening;

  VoiceState copyWith({
    VoiceStatus? status,
    String? transcript,
    String? error,
    bool clearError = false,
  }) =>
      VoiceState(
        status: status ?? this.status,
        transcript: transcript ?? this.transcript,
        error: clearError ? null : (error ?? this.error),
      );
}

/// On-device speech-to-text.
///
/// Uses the platform recogniser, which is what makes Hindi dictation work at
/// all without shipping a second model — and, on both platforms, can fall back
/// to a server-side recogniser. That is the one place Saath's "nothing leaves
/// the phone" promise has an asterisk, so [onDeviceOnly] is requested and the
/// UI says plainly that the keyboard is the private path.
class VoiceInput extends StateNotifier<VoiceState> {
  VoiceInput(this._ref) : super(const VoiceState());

  final Ref _ref;
  final SpeechToText _speech = SpeechToText();
  bool _initialised = false;

  Future<bool> _ensureInitialised() async {
    if (_initialised) return true;
    try {
      _initialised = await _speech.initialize(
        onError: (e) {
          if (!mounted) return;
          state = state.copyWith(
            status: VoiceStatus.idle,
            error: e.errorMsg,
          );
        },
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            state = state.copyWith(status: VoiceStatus.idle);
          }
        },
      );
    } on Object catch (error) {
      debugPrint('Saath: speech init failed: $error');
      _initialised = false;
    }
    if (!_initialised && mounted) {
      state = state.copyWith(status: VoiceStatus.unavailable);
    }
    return _initialised;
  }

  /// Starts listening. [seed] keeps whatever was already typed, so speaking
  /// adds to a half-written message instead of wiping it.
  Future<void> start({String seed = ''}) async {
    if (state.isListening) return;
    state = state.copyWith(status: VoiceStatus.asking, clearError: true);

    if (!await _ensureInitialised()) return;
    if (!mounted) return;

    final hindi = _ref.read(appStateProvider).isHindi;
    final prefix = seed.trim().isEmpty ? '' : '${seed.trim()} ';

    state = state.copyWith(status: VoiceStatus.listening, transcript: seed);
    try {
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: hindi ? 'hi_IN' : 'en_IN',
          // Ask the platform to keep it on the device. Honoured where the OS
          // supports it; ignored, silently, where it does not.
          onDevice: true,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          pauseFor: const Duration(seconds: 4),
          listenFor: const Duration(minutes: 2),
        ),
        onResult: (result) {
          if (!mounted) return;
          state =
              state.copyWith(transcript: '$prefix${result.recognizedWords}');
        },
      );
    } on Object catch (error) {
      if (!mounted) return;
      state = state.copyWith(status: VoiceStatus.idle, error: '$error');
    }
  }

  Future<void> stop() async {
    if (!state.isListening) return;
    try {
      await _speech.stop();
    } on Object catch (error) {
      debugPrint('Saath: speech stop failed: $error');
    }
    if (mounted) state = state.copyWith(status: VoiceStatus.idle);
  }

  Future<void> cancel() async {
    try {
      await _speech.cancel();
    } on Object catch (error) {
      debugPrint('Saath: speech cancel failed: $error');
    }
    if (mounted) state = const VoiceState();
  }

  void reset() {
    if (mounted) state = const VoiceState();
  }

  @override
  void dispose() {
    // Fire-and-forget, but never unguarded: on a platform with no recogniser
    // this rejects, and an unhandled async error takes down whatever else is
    // running.
    unawaited(_speech.cancel().catchError((Object _) {}));
    super.dispose();
  }
}

final voiceInputProvider = StateNotifierProvider<VoiceInput, VoiceState>(
  VoiceInput.new,
);

/// Read-aloud for the counsellor's replies.
///
/// The serif face was chosen so a reply reads like a letter; this is for the
/// times someone cannot look at the screen — driving home after the argument,
/// or crying.
class ReadAloud extends StateNotifier<bool> {
  ReadAloud(this._ref) : super(false) {
    _tts.setCompletionHandler(() {
      if (mounted) state = false;
    });
    _tts.setCancelHandler(() {
      if (mounted) state = false;
    });
    _tts.setErrorHandler((dynamic message) {
      debugPrint('Saath: tts error: $message');
      if (mounted) state = false;
    });
  }

  final Ref _ref;
  final FlutterTts _tts = FlutterTts();

  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (state) {
      await stop();
      return;
    }
    final hindi = _ref.read(appStateProvider).isHindi;
    try {
      await _tts.setLanguage(hindi ? 'hi-IN' : 'en-IN');
      // A counsellor does not read at newsreader speed.
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      if (mounted) state = true;
      await _tts.speak(trimmed);
    } on Object catch (error) {
      debugPrint('Saath: tts failed: $error');
      if (mounted) state = false;
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } on Object catch (error) {
      debugPrint('Saath: tts stop failed: $error');
    }
    if (mounted) state = false;
  }

  @override
  void dispose() {
    unawaited(_tts.stop().catchError((Object _) => null));
    super.dispose();
  }
}

final readAloudProvider = StateNotifierProvider<ReadAloud, bool>(ReadAloud.new);

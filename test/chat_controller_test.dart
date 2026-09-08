import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/core/app_state.dart';
import 'package:vyuhbhed/core/key_value_store.dart';
import 'package:vyuhbhed/features/counsellor/chat_controller.dart';
import 'package:vyuhbhed/features/counsellor/engine.dart';
import 'package:vyuhbhed/features/counsellor/safety.dart';

/// Engine that fails partway through, to exercise the retry path.
class _FailingEngine extends MockCounsellorEngine {
  const _FailingEngine() : super(tokenDelay: Duration.zero);

  @override
  Stream<String> reply(
      List<ChatMessage> history, CounsellorContext ctx) async* {
    yield 'word ';
    yield 'word ';
    throw StateError('model died');
  }
}

/// Engine that closes the stream without ever emitting.
class _SilentEngine extends MockCounsellorEngine {
  const _SilentEngine() : super(tokenDelay: Duration.zero);

  @override
  Stream<String> reply(List<ChatMessage> history, CounsellorContext ctx) =>
      const Stream<String>.empty();
}

/// Engine that never finishes, so `stop()` has something to stop.
class _HangingEngine extends MockCounsellorEngine {
  const _HangingEngine() : super(tokenDelay: Duration.zero);

  @override
  Stream<String> reply(
      List<ChatMessage> history, CounsellorContext ctx) async* {
    yield 'partial ';
    await Completer<void>().future;
  }
}

ProviderContainer makeContainer(
    {CounsellorEngine engine =
        const MockCounsellorEngine(tokenDelay: Duration.zero)}) {
  final container = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(InMemoryStore()),
      counsellorEngineProvider.overrideWithValue(engine),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('sending appends the user message and a streamed reply', () async {
    final c = makeContainer();
    final ctrl = c.read(chatControllerProvider.notifier);

    await ctrl.send('we keep having the same fight');

    final state = c.read(chatControllerProvider);
    expect(state.messages, hasLength(2));
    expect(state.messages.first.fromUser, isTrue);
    expect(state.messages.last.fromUser, isFalse);
    expect(state.messages.last.text.trim(), isNotEmpty);
    expect(state.streaming, isFalse);
  });

  test('ignores empty input', () async {
    final c = makeContainer();
    await c.read(chatControllerProvider.notifier).send('   ');
    expect(c.read(chatControllerProvider).messages, isEmpty);
  });

  group('safety', () {
    test('a disclosure raises the interrupt instead of generating a reply',
        () async {
      final c = makeContainer();
      final ctrl = c.read(chatControllerProvider.notifier);

      await ctrl.send('he hit me last night');

      final state = c.read(chatControllerProvider);
      expect(state.pendingSafety, isNotNull);
      expect(state.pendingSafety!.concern, SafetyConcern.violence);
      expect(state.messages, hasLength(1),
          reason: 'no counsellor reply is generated for a disclosure');
      expect(state.streaming, isFalse);
    });

    test('acknowledging leaves the counsellor saying something', () async {
      // The old flow cleared the flag and generated nothing at all: coming back
      // from the helplines showed a conversation that had gone silent.
      final c = makeContainer();
      final ctrl = c.read(chatControllerProvider.notifier);

      await ctrl.send('I am afraid of him');
      ctrl.acknowledgeSafety(hindi: false);

      final state = c.read(chatControllerProvider);
      expect(state.pendingSafety, isNull);
      expect(state.messages, hasLength(2));
      expect(state.messages.last.fromUser, isFalse);
      expect(state.messages.last.text, contains('still here'));
    });

    test('acknowledging replies in Hindi when the app is in Hindi', () async {
      final c = makeContainer();
      final ctrl = c.read(chatControllerProvider.notifier);

      await ctrl.send('मुझे उससे डर लगता है');
      ctrl.acknowledgeSafety(hindi: true);

      expect(
        RegExp(r'[ऀ-ॿ]')
            .hasMatch(c.read(chatControllerProvider).messages.last.text),
        isTrue,
      );
    });

    test('acknowledging twice does not stack replies', () async {
      final c = makeContainer();
      final ctrl = c.read(chatControllerProvider.notifier);

      await ctrl.send('he hit me');
      ctrl.acknowledgeSafety(hindi: false);
      ctrl.acknowledgeSafety(hindi: false);

      expect(c.read(chatControllerProvider).messages, hasLength(2));
    });
  });

  group('failure', () {
    test('a mid-stream error marks the reply retryable', () async {
      final c = makeContainer(engine: const _FailingEngine());
      final ctrl = c.read(chatControllerProvider.notifier);

      await ctrl.send('something');

      final state = c.read(chatControllerProvider);
      expect(state.streaming, isFalse);
      expect(state.messages.last.failed, isTrue);
      expect(state.canRetry, isTrue);
    });

    test('an engine that emits nothing counts as a failure, not a blank reply',
        () async {
      final c = makeContainer(engine: const _SilentEngine());
      await c.read(chatControllerProvider.notifier).send('something');

      expect(c.read(chatControllerProvider).messages.last.failed, isTrue);
    });

    test('retry replaces the failed placeholder rather than stacking',
        () async {
      final c = ProviderContainer(overrides: [
        keyValueStoreProvider.overrideWithValue(InMemoryStore()),
        counsellorEngineProvider.overrideWithValue(const _FailingEngine()),
      ]);
      addTearDown(c.dispose);

      final ctrl = c.read(chatControllerProvider.notifier);
      await ctrl.send('something');
      expect(c.read(chatControllerProvider).messages, hasLength(2));

      await ctrl.retry();
      expect(c.read(chatControllerProvider).messages, hasLength(2),
          reason: 'one user message, one reply — not three');
    });
  });

  group('stop', () {
    test('keeps the partial text and offers a retry', () async {
      final c = makeContainer(engine: const _HangingEngine());
      final ctrl = c.read(chatControllerProvider.notifier);

      unawaited(ctrl.send('something'));
      await Future<void>.delayed(Duration.zero);
      expect(c.read(chatControllerProvider).streaming, isTrue);

      ctrl.stop();

      final state = c.read(chatControllerProvider);
      expect(state.streaming, isFalse);
      expect(state.messages.last.text.trim(), 'partial');
      expect(state.canRetry, isTrue);
    });
  });

  test('clear empties the conversation', () async {
    final c = makeContainer();
    final ctrl = c.read(chatControllerProvider.notifier);

    await ctrl.send('hello');
    ctrl.clear();

    expect(c.read(chatControllerProvider).messages, isEmpty);
  });

  test('firstUserMessage is null before anyone speaks', () {
    expect(const ChatState().firstUserMessage, isNull);
    expect(
      const ChatState(messages: [ChatMessage(fromUser: false, text: 'hi')])
          .firstUserMessage,
      isNull,
      reason: 'Untangle used firstWhere here and threw on this shape',
    );
  });

  test('the conversation survives a restart', () async {
    final store = InMemoryStore();
    final c1 = ProviderContainer(overrides: [
      keyValueStoreProvider.overrideWithValue(store),
      counsellorEngineProvider.overrideWithValue(
          const MockCounsellorEngine(tokenDelay: Duration.zero)),
    ]);
    addTearDown(c1.dispose);
    await c1.read(chatControllerProvider.notifier).send('we keep fighting');
    expect(ChatController.load(store), hasLength(2));

    // A fresh container over the same store is what a cold start looks like.
    final c2 = ProviderContainer(overrides: [
      keyValueStoreProvider.overrideWithValue(store),
      counsellorEngineProvider.overrideWithValue(
          const MockCounsellorEngine(tokenDelay: Duration.zero)),
    ]);
    addTearDown(c2.dispose);
    final restored = c2.read(chatControllerProvider);
    expect(restored.messages, hasLength(2));
    expect(restored.messages.first.text, 'we keep fighting');
    expect(restored.streaming, isFalse);
  });

  test('a reply cut off by a crash is restored as failed, so Retry is offered',
      () async {
    final store = InMemoryStore();
    final c = ProviderContainer(overrides: [
      keyValueStoreProvider.overrideWithValue(store),
      counsellorEngineProvider.overrideWithValue(const _HangingEngine()),
    ]);
    addTearDown(c.dispose);
    final ctrl = c.read(chatControllerProvider.notifier);
    unawaited(ctrl.send('hello'));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(chatControllerProvider).streaming, isTrue);

    final onDisk = ChatController.load(store);
    expect(onDisk.first.text, 'hello');
    expect(onDisk.last.fromUser, isFalse);
    expect(onDisk.last.failed, isTrue);
    ctrl.stop();
  });

  test('clear wipes the disk and restore puts it back', () async {
    final store = InMemoryStore();
    final c = ProviderContainer(overrides: [
      keyValueStoreProvider.overrideWithValue(store),
      counsellorEngineProvider.overrideWithValue(
          const MockCounsellorEngine(tokenDelay: Duration.zero)),
    ]);
    addTearDown(c.dispose);
    final ctrl = c.read(chatControllerProvider.notifier);
    await ctrl.send('hi');
    final kept = c.read(chatControllerProvider).messages;

    ctrl.clear();
    expect(ChatController.load(store), isEmpty);

    ctrl.restore(kept);
    expect(c.read(chatControllerProvider).messages, hasLength(2));
    expect(ChatController.load(store), hasLength(2));
  });
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/core/key_value_store.dart';
import 'package:vyuhbhed/features/counsellor/model/model_catalogue.dart';
import 'package:vyuhbhed/features/counsellor/model/model_manager.dart';

import 'support/harness.dart';

void main() {
  // device_info_plus has no platform here, so the RAM probe fails and the
  // manager falls back to the small model. That fallback is the behaviour we
  // want on an unknown device, and the test below asserts it.
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryStore store;
  late FakeModelRuntime runtime;
  late ModelManager manager;

  setUp(() {
    store = InMemoryStore();
    runtime = FakeModelRuntime();
    manager = ModelManager(store, runtime: runtime);
    addTearDown(manager.dispose);
  });

  test('an unreadable device falls back to the small model, not the big one',
      () async {
    await manager.initialise();
    expect(manager.state.recommended, SaathModel.gemma31B);
    expect(manager.state.deviceRamMb, isNull);
  });

  test('starts with no model, so the preview engine answers', () {
    expect(manager.state.hasModel, isFalse);
    expect(manager.state.isDownloading, isFalse);
  });

  test('installing records the model and survives a relaunch', () async {
    await manager.install(SaathModel.gemma31B);

    expect(manager.state.installed, SaathModel.gemma31B);
    expect(runtime.installCalls, [SaathModel.gemma31B]);

    final relaunched = ModelManager(store, runtime: runtime);
    addTearDown(relaunched.dispose);
    await relaunched.initialise();
    expect(relaunched.state.installed, SaathModel.gemma31B);
  });

  test('a model that vanished between launches is forgotten, not trusted',
      () async {
    // The OS reclaims app storage, or the user clears it. Trusting the stored
    // preference would give them a counsellor that fails on first message.
    await manager.install(SaathModel.gemma31B);
    runtime.installed.clear();

    final relaunched = ModelManager(store, runtime: runtime);
    addTearDown(relaunched.dispose);
    await relaunched.initialise();

    expect(relaunched.state.installed, isNull);
    expect(store.getString('saath.model.installed'), isNull);
  });

  test('reports progress while downloading', () async {
    final seen = <int>[];
    manager.addListener((state) {
      if (state.download != null) seen.add(state.download!.percent);
    });

    await manager.install(SaathModel.gemma31B);

    expect(seen, containsAllInOrder([0, 50, 100]));
    expect(manager.state.isDownloading, isFalse, reason: 'cleared when done');
  });

  test('a failed download surfaces the error instead of pretending', () async {
    final failing = ModelManager(
      store,
      runtime: FakeModelRuntime(failWith: StateError('no space left')),
    );
    addTearDown(failing.dispose);

    await failing.install(SaathModel.gemma31B);

    expect(failing.state.hasModel, isFalse);
    expect(failing.state.isDownloading, isFalse);
    expect(failing.state.error, contains('no space left'));
  });

  test('a second install while one is running is ignored', () async {
    final gated = FakeModelRuntime()..gate = Completer<void>();
    final m = ModelManager(store, runtime: gated);
    addTearDown(m.dispose);

    final first = m.install(SaathModel.gemma31B);
    await Future<void>.delayed(Duration.zero);
    expect(m.state.isDownloading, isTrue);

    await m.install(SaathModel.gemma3nE2B);
    expect(gated.installCalls, hasLength(1),
        reason: 'two concurrent multi-gigabyte downloads is never right');

    gated.gate!.complete();
    await first;
  });

  test('uninstalling frees the model and drops back to preview', () async {
    await manager.install(SaathModel.gemma31B);
    await manager.uninstall();

    expect(manager.state.hasModel, isFalse);
    expect(runtime.uninstallCalls, [SaathModel.gemma31B.fileName]);
    expect(store.getString('saath.model.installed'), isNull);
  });

  test('an explicit choice overrides the RAM recommendation and persists',
      () async {
    await manager.choose(SaathModel.gemma3nE2B);
    expect(manager.state.recommended, SaathModel.gemma3nE2B);
    expect(store.getString('saath.model.preferred'), SaathModel.gemma3nE2B.id);

    final relaunched = ModelManager(store, runtime: runtime);
    addTearDown(relaunched.dispose);
    expect(relaunched.state.recommended, SaathModel.gemma3nE2B);
  });

  test('a load failure at generation time stops claiming a model is there',
      () async {
    await manager.install(SaathModel.gemma31B);
    manager.reportLoadFailure('GPU delegate unavailable');

    expect(manager.state.hasModel, isFalse);
    expect(manager.state.unavailable, ModelUnavailable.loadFailed);
    expect(manager.state.error, contains('GPU delegate'));
  });
}

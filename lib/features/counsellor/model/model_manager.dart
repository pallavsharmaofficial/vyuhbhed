import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_state.dart';
import '../../../core/key_value_store.dart';
import 'model_catalogue.dart';

/// Why the counsellor is not currently a real model.
enum ModelUnavailable {
  /// Nothing downloaded yet. The normal state on first run.
  notInstalled,

  /// The build has no host to download from — see [ModelHosting].
  notConfigured,

  /// Downloaded, but the runtime refused to load it.
  loadFailed,
}

@immutable
class ModelState {
  const ModelState({
    required this.recommended,
    this.installed,
    this.download,
    this.unavailable = ModelUnavailable.notInstalled,
    this.error,
    this.deviceRamMb,
  });

  /// Chosen from physical RAM, overridable by the user.
  final SaathModel recommended;

  /// Installed and believed loadable. Null means the preview engine is in use.
  final SaathModel? installed;

  /// Non-null while a download is running.
  final ModelDownload? download;

  final ModelUnavailable unavailable;

  /// Last failure, for the UI to show rather than swallow.
  final String? error;

  final int? deviceRamMb;

  bool get isDownloading => download != null;
  bool get hasModel => installed != null;

  /// True when the recommended model is the big one — worth saying out loud
  /// before someone starts a 3.7 GB download.
  bool get recommendsLargeModel => recommended == SaathModel.gemma3nE2B;

  ModelState copyWith({
    SaathModel? recommended,
    SaathModel? installed,
    bool clearInstalled = false,
    ModelDownload? download,
    bool clearDownload = false,
    ModelUnavailable? unavailable,
    String? error,
    bool clearError = false,
    int? deviceRamMb,
  }) {
    return ModelState(
      recommended: recommended ?? this.recommended,
      installed: clearInstalled ? null : (installed ?? this.installed),
      download: clearDownload ? null : (download ?? this.download),
      unavailable: unavailable ?? this.unavailable,
      error: clearError ? null : (error ?? this.error),
      deviceRamMb: deviceRamMb ?? this.deviceRamMb,
    );
  }
}

const _installedKey = 'saath.model.installed';
const _preferredKey = 'saath.model.preferred';

/// Owns which model is on the device and how it got there.
///
/// The app is fully usable while this is empty — that is the point of the
/// preview engine. Downloading is something the user chooses, on Wi-Fi,
/// knowing the size, and can cancel.
class ModelManager extends StateNotifier<ModelState> {
  ModelManager(this._store, {ModelRuntime? runtime})
      : _runtime = runtime ?? const GemmaModelRuntime(),
        super(
          ModelState(
            recommended: SaathModel.byId(_store.getString(_preferredKey)) ??
                SaathModel.gemma31B,
            installed: null,
          ),
        );

  final KeyValueStore _store;
  final ModelRuntime _runtime;
  CancelToken? _cancel;

  /// Reads device RAM and reconciles what we think is installed with what the
  /// runtime actually has. Called once at startup.
  Future<void> initialise() async {
    final ram = await _physicalRamMb();
    final preferred = SaathModel.byId(_store.getString(_preferredKey));
    final recommended = preferred ?? SaathModel.recommendedFor(ram);

    var next = state.copyWith(recommended: recommended, deviceRamMb: ram);

    final remembered = SaathModel.byId(_store.getString(_installedKey));
    if (remembered != null) {
      // A model can vanish between launches — the OS reclaims app storage, or
      // the user cleared it. Trusting the preference alone would give them a
      // counsellor that fails on first message instead of a clear prompt.
      final present = await _runtime.isInstalled(remembered.fileName);
      if (present) {
        next = next.copyWith(
            installed: remembered, unavailable: ModelUnavailable.notInstalled);
      } else {
        await _store.remove(_installedKey);
        next = next.copyWith(clearInstalled: true);
      }
    }

    if (next.installed == null && !ModelHosting.isConfigured) {
      next = next.copyWith(unavailable: ModelUnavailable.notConfigured);
    }
    state = next;
  }

  Future<void> choose(SaathModel model) async {
    state = state.copyWith(recommended: model);
    await _store.setString(_preferredKey, model.id);
  }

  /// Downloads and installs [model]. Safe to call while one is already running
  /// — it returns immediately rather than starting a second download.
  Future<void> install(SaathModel model) async {
    if (state.isDownloading) return;

    state = state.copyWith(
      download: ModelDownload(
          model: model, receivedBytes: 0, startedAt: DateTime.now()),
      clearError: true,
    );

    final cancel = _cancel = CancelToken();
    try {
      await _runtime.install(
        model: model,
        cancelToken: cancel,
        onProgress: (percent) {
          if (!mounted) return;
          final current = state.download;
          if (current == null) return;
          state = state.copyWith(
            download: current.copyWith(
              receivedBytes: (model.bytes * (percent / 100)).round(),
            ),
          );
        },
      );
      if (!mounted) return;
      await _store.setString(_installedKey, model.id);
      state = state.copyWith(
        installed: model,
        clearDownload: true,
        clearError: true,
        unavailable: ModelUnavailable.notInstalled,
      );
    } on Object catch (error) {
      if (!mounted) return;
      state = state.copyWith(clearDownload: true, error: _describe(error));
    } finally {
      _cancel = null;
    }
  }

  void cancelDownload() {
    _cancel?.cancel('cancelled by the user');
    _cancel = null;
    if (mounted) state = state.copyWith(clearDownload: true);
  }

  /// Removes the model and its ~600 MB–3.7 GB of storage.
  Future<void> uninstall() async {
    final installed = state.installed;
    if (installed == null) return;
    try {
      await _runtime.uninstall(installed.fileName);
    } on Object catch (error) {
      debugPrint('Saath: uninstall failed: $error');
    }
    await _store.remove(_installedKey);
    if (!mounted) return;
    state = state.copyWith(clearInstalled: true, clearError: true);
  }

  /// Called when loading the model fails at generation time, so the UI can
  /// stop claiming a counsellor is available.
  void reportLoadFailure(String message) {
    if (!mounted) return;
    state = state.copyWith(
      clearInstalled: true,
      unavailable: ModelUnavailable.loadFailed,
      error: message,
    );
  }

  static String _describe(Object error) {
    if (error is DownloadException) return error.error.toUserMessage();
    return error.toString();
  }

  static Future<int?> _physicalRamMb() async {
    try {
      final info = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        return (await info.androidInfo).physicalRamSize;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return (await info.iosInfo).physicalRamSize;
      }
    } on Object catch (error) {
      debugPrint('Saath: could not read device RAM: $error');
    }
    return null;
  }

  @override
  void dispose() {
    _cancel?.cancel('disposed');
    super.dispose();
  }
}

/// The bit of flutter_gemma the manager touches, behind an interface so the
/// manager is testable without a 3.7 GB download.
abstract class ModelRuntime {
  Future<bool> isInstalled(String fileName);

  Future<void> install({
    required SaathModel model,
    required CancelToken cancelToken,
    required void Function(int percent) onProgress,
  });

  Future<void> uninstall(String fileName);
}

class GemmaModelRuntime implements ModelRuntime {
  const GemmaModelRuntime();

  @override
  Future<bool> isInstalled(String fileName) =>
      FlutterGemma.isModelInstalled(fileName);

  @override
  Future<void> install({
    required SaathModel model,
    required CancelToken cancelToken,
    required void Function(int percent) onProgress,
  }) {
    return FlutterGemma.installModel(
      // Getting this wrong does not fail loudly — it applies the wrong chat
      // template and produces subtly worse answers, which on a counselling
      // app is the worst kind of bug.
      modelType: switch (model.engineType) {
        ModelEngineType.gemma => ModelType.gemmaIt,
        ModelEngineType.qwen => ModelType.qwen,
      },
      fileType: ModelFileType.litertlm,
    )
        .fromNetwork(
          model.downloadUrl,
          token: ModelHosting.huggingFaceToken.isEmpty
              ? null
              : ModelHosting.huggingFaceToken,
        )
        .withCancelToken(cancelToken)
        .withProgress(onProgress)
        .install();
  }

  @override
  Future<void> uninstall(String fileName) async {
    await FlutterGemma.uninstallModel(fileName);
    await FlutterGemma.clearActiveInferenceIdentity();
  }
}

/// The runtime the manager talks to. Overridden in tests so nothing reaches
/// the native engine, and so download behaviour is testable without a
/// multi-gigabyte file.
final modelRuntimeProvider = Provider<ModelRuntime>(
  (_) => const GemmaModelRuntime(),
);

final modelManagerProvider = StateNotifierProvider<ModelManager, ModelState>(
  (ref) => ModelManager(
    ref.watch(keyValueStoreProvider),
    runtime: ref.watch(modelRuntimeProvider),
  ),
);

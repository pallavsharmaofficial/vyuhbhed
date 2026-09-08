import 'package:flutter/foundation.dart';

/// A model Saath can run on the device.
///
/// Two, not ten. The choice is made for the user from their phone's RAM,
/// because "which quantisation would you like" is not a question to put to
/// someone who opened a relationship app at eleven at night.
enum SaathModel {
  /// Gemma 3n E2B, int4. Multilingual, noticeably better Hindi.
  gemma3nE2B(
    id: 'gemma-3n-e2b-int4',
    fileName: 'gemma-3n-E2B-it-int4.litertlm',
    repo: 'google/gemma-3n-E2B-it-litert-lm',
    bytes: 3655827456,
    minRamMb: 6144,
    maxTokens: 2048,
    engineType: ModelEngineType.gemma,
  ),

  /// Gemma 3 1B, int4. The fallback that makes the app usable on a 4 GB phone
  /// — which is most of the market this is aimed at.
  gemma31B(
    id: 'gemma-3-1b-int4',
    fileName: 'gemma3-1b-it-int4.litertlm',
    repo: 'litert-community/Gemma3-1B-IT',
    bytes: 584417280,
    minRamMb: 0,
    maxTokens: 1280,
    engineType: ModelEngineType.gemma,
  ),

  /// Qwen 2.5 1.5B, q8. The escape hatch.
  ///
  /// Both Gemma repos are gated: a first run against them needs a Hugging Face
  /// account that has accepted the licence. This one is not gated, and at
  /// 1.6 GB it fits inside a GitHub release asset — so a build can have a real
  /// counsellor with no second account and no payment card anywhere.
  ///
  /// It is not the default. It is nearly three times the download of Gemma 1B
  /// for a model that is not better at Hindi. Use it to get something working,
  /// then move to Gemma once the licence is accepted.
  qwen251_5B(
    id: 'qwen-2.5-1.5b-q8',
    fileName: 'Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm',
    repo: 'litert-community/Qwen2.5-1.5B-Instruct',
    bytes: 1597931520,
    // Never auto-selected: recommendedFor stops at the first match, and this
    // sits after gemma31B's catch-all threshold.
    minRamMb: 1 << 30,
    maxTokens: 2048,
    engineType: ModelEngineType.qwen,
  );

  const SaathModel({
    required this.id,
    required this.fileName,
    required this.repo,
    required this.bytes,
    required this.minRamMb,
    required this.maxTokens,
    required this.engineType,
  });

  final String id;
  final String fileName;

  /// Hugging Face repo, used to build the default download URL.
  final String repo;

  /// Exact download size. Shown to the user before anything is downloaded,
  /// because a 3.7 GB surprise on a metered connection is a betrayal.
  final int bytes;

  /// Physical RAM at or above which this model is the recommended default.
  final int minRamMb;

  /// Context window. The 1B model gets a smaller one so a long conversation
  /// does not push it into swap on the phones it exists for.
  final int maxTokens;

  /// Which prompt template family the runtime should apply. Getting this wrong
  /// does not fail loudly — it produces subtly worse answers, which on a
  /// counselling app is the worst kind of bug.
  final ModelEngineType engineType;

  double get gigabytes => bytes / (1000 * 1000 * 1000);

  String get sizeLabel => bytes >= 1000000000
      ? '${gigabytes.toStringAsFixed(1)} GB'
      : '${(bytes / (1000 * 1000)).round()} MB';

  /// Where the file comes from.
  ///
  /// The Gemma repos are gated, so a first run against Hugging Face needs a
  /// token. Point [ModelHosting.baseUrl] at somewhere you control instead —
  /// a GitHub release works and is free (see tool/publish-model.sh) — which
  /// also stops a rename upstream from breaking first-run for everyone.
  String get downloadUrl {
    const base = ModelHosting.baseUrl;
    if (base.isEmpty) {
      return 'https://huggingface.co/$repo/resolve/main/$fileName';
    }
    return '${base.endsWith('/') ? base.substring(0, base.length - 1) : base}/$fileName';
  }

  /// The models this build can actually download.
  ///
  /// A host usually carries a subset — the Gemma repos are gated, so a release
  /// built from a GitHub-hosted mirror may only have the ungated one. Offering
  /// a model the host does not have produces a 404 on the first thing a user
  /// ever taps, so the catalogue is narrowed to what is really there.
  ///
  /// Empty [ModelHosting.availableIds] means "all of them", which is right for
  /// a build pointed at Hugging Face with a token.
  static List<SaathModel> get available {
    final ids = ModelHosting.availableIds;
    if (ids.isEmpty) return values;
    final subset = [
      for (final m in values)
        if (ids.contains(m.id)) m,
    ];
    // Never return nothing: a typo in the define would otherwise leave the
    // model screen blank with no way to tell why.
    return subset.isEmpty ? values : subset;
  }

  /// The model recommended for a device with [ramMb] of physical RAM.
  ///
  /// Falls back to the smallest available model when RAM is unknown: shipping
  /// a 3.7 GB download to a phone that cannot hold it is the worse failure.
  static SaathModel recommendedFor(int? ramMb) {
    final options = available;
    final smallest = options.reduce((a, b) => a.bytes <= b.bytes ? a : b);
    if (ramMb == null) return smallest;
    for (final m in options) {
      if (ramMb >= m.minRamMb) return m;
    }
    return smallest;
  }

  static SaathModel? byId(String? id) {
    if (id == null) return null;
    for (final m in values) {
      if (m.id == id) return m;
    }
    return null;
  }
}

/// Which prompt template the LiteRT-LM runtime applies to a model.
enum ModelEngineType { gemma, qwen }

/// Where model files are served from.
///
/// Set at build time:
/// `flutter build --dart-define=SAATH_MODEL_BASE_URL=https://models.saathhamesha.in`
///
/// Left empty, Saath falls back to Hugging Face, which needs
/// `--dart-define=HUGGINGFACE_TOKEN=...` because both repos are gated. That is
/// fine for development and is **not** how this should ship — point
/// [baseUrl] at a host you control.
class ModelHosting {
  ModelHosting._();

  static const baseUrl = String.fromEnvironment('SAATH_MODEL_BASE_URL');
  static const huggingFaceToken = String.fromEnvironment('HUGGINGFACE_TOKEN');

  /// Comma-separated [SaathModel.id]s the configured host actually serves.
  /// Empty means all of them.
  ///
  ///     --dart-define=SAATH_MODEL_IDS=qwen-2.5-1.5b-q8
  static const _modelIds = String.fromEnvironment('SAATH_MODEL_IDS');

  static Set<String> get availableIds => {
        for (final id in _modelIds.split(','))
          if (id.trim().isNotEmpty) id.trim(),
      };

  /// True when the build is pointed at a host that can actually serve the
  /// files without a per-user token.
  static bool get isConfigured =>
      baseUrl.isNotEmpty || huggingFaceToken.isNotEmpty;
}

/// Progress of an in-flight download.
@immutable
class ModelDownload {
  const ModelDownload({
    required this.model,
    required this.receivedBytes,
    required this.startedAt,
  });

  final SaathModel model;
  final int receivedBytes;
  final DateTime startedAt;

  double get fraction =>
      model.bytes == 0 ? 0 : (receivedBytes / model.bytes).clamp(0.0, 1.0);

  int get percent => (fraction * 100).round();

  /// Bytes per second so far, or null before there is enough to be meaningful.
  double? get bytesPerSecond {
    final seconds = DateTime.now().difference(startedAt).inMilliseconds / 1000;
    if (seconds < 2 || receivedBytes <= 0) return null;
    return receivedBytes / seconds;
  }

  Duration? get remaining {
    final rate = bytesPerSecond;
    if (rate == null || rate <= 0) return null;
    final left = model.bytes - receivedBytes;
    if (left <= 0) return Duration.zero;
    return Duration(seconds: (left / rate).round());
  }

  ModelDownload copyWith({int? receivedBytes}) => ModelDownload(
        model: model,
        receivedBytes: receivedBytes ?? this.receivedBytes,
        startedAt: startedAt,
      );
}

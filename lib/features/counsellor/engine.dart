import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/journal.dart';
import 'model/gemma_engine.dart';
import 'model/model_manager.dart';
import 'safety.dart';

/// One message in a counsellor conversation.
@immutable
class ChatMessage {
  const ChatMessage(
      {required this.fromUser, required this.text, this.failed = false});

  final bool fromUser;
  final String text;

  /// True when generation stopped before the reply was finished, so the UI can
  /// offer a retry instead of leaving a half-sentence on screen.
  final bool failed;

  ChatMessage copyWith({String? text, bool? failed}) => ChatMessage(
      fromUser: fromUser,
      text: text ?? this.text,
      failed: failed ?? this.failed);
}

/// Result of the Untangle feature: a vent sorted into four columns plus one
/// sentence the user could actually say.
@immutable
class Untangled {
  const Untangled({
    required this.happened,
    required this.assumed,
    required this.felt,
    required this.need,
    required this.sentence,
    this.themes = const [],
  });

  final String happened;
  final String assumed;
  final String felt;
  final String need;
  final String sentence;

  /// What the vent was about, for the journal's 30-day trends.
  final List<JournalTheme> themes;
}

/// The two private accounts that go into a Repair Room merge.
@immutable
class RepairSides {
  const RepairSides(this.a, this.b);
  final String a;
  final String b;

  bool get isComplete => a.trim().length >= 10 && b.trim().length >= 10;

  @override
  bool operator ==(Object other) =>
      other is RepairSides && other.a == a && other.b == b;

  @override
  int get hashCode => Object.hash(a, b);
}

/// Neutral merge of two private accounts of the same incident.
@immutable
class RepairMerge {
  const RepairMerge({
    required this.title,
    required this.agreed,
    required this.sideA,
    required this.sideB,
    required this.split,
    required this.firstTurn,
  });

  final String title;
  final String agreed;

  /// What each side heard/said, already neutralised. Neither contains the
  /// other person's raw words — that is the whole promise of the room.
  final String sideA;
  final String sideB;
  final String split;
  final String firstTurn;
}

/// Three rewrites of a message the user is about to send, plus what was worth
/// keeping from their original.
@immutable
class KinderRewrite {
  const KinderRewrite({
    required this.kinder,
    required this.clearer,
    required this.shorter,
    required this.keep,
  });

  final String kinder;
  final String clearer;
  final String shorter;
  final String keep;

  /// The three options, labelled, for a picker.
  List<(String, String)> options(bool hindi) => [
        (hindi ? 'नरम' : 'Kinder', kinder),
        (hindi ? 'साफ़' : 'Clearer', clearer),
        (hindi ? 'छोटा' : 'Shorter', shorter),
      ].where((o) => o.$2.trim().isNotEmpty).toList();
}

/// The on-device reflection on a week of check-ins.
@immutable
class WeeklyReflection {
  const WeeklyReflection({required this.reflection, required this.suggestion});

  final String reflection;
  final String suggestion;
}

/// Context the engine gets on every call. The origin story is what keeps
/// advice anchored to why the couple started.
@immutable
class CounsellorContext {
  const CounsellorContext({
    required this.userName,
    required this.partnerName,
    required this.originStory,
    required this.hindi,
  });

  final String userName;
  final String partnerName;
  final String originStory;
  final bool hindi;

  String get partnerOrDefault => partnerName.trim().isEmpty
      ? (hindi ? 'आपका साथी' : 'your partner')
      : partnerName.trim();

  String get userOrDefault =>
      userName.trim().isEmpty ? (hindi ? 'आप' : 'You') : userName.trim();

  /// Value equality, so a provider that `select`s this from app state does not
  /// re-run a 20-second generation because someone tapped a check-in score.
  @override
  bool operator ==(Object other) =>
      other is CounsellorContext &&
      other.userName == userName &&
      other.partnerName == partnerName &&
      other.originStory == originStory &&
      other.hindi == hindi;

  @override
  int get hashCode => Object.hash(userName, partnerName, originStory, hindi);
}

/// Thrown when the engine cannot produce a result. The UI turns this into a
/// retry, never into a stack trace.
class CounsellorException implements Exception {
  const CounsellorException(this.message);
  final String message;

  @override
  String toString() => 'CounsellorException: $message';
}

/// The AI layer sits behind this one interface so the on-device Gemma
/// engine (and later an optional cloud engine) are implementations, not
/// rewrites. The UI never knows which one is answering.
abstract class CounsellorEngine {
  /// Streams the reply token by token. Cancelling the subscription must stop
  /// generation — the Gemma implementation has to honour that too, or "Stop"
  /// will keep burning battery after the user has moved on.
  Stream<String> reply(List<ChatMessage> history, CounsellorContext ctx);

  Future<Untangled> untangle(String vent, CounsellorContext ctx);

  Future<RepairMerge> mergeRepair(RepairSides sides, CounsellorContext ctx);

  /// Rewrites a message the user is about to send. Never sends anything —
  /// the user still chooses, including choosing their original words.
  Future<KinderRewrite> sayItKinder(String draft, CounsellorContext ctx);

  /// One short paragraph on a saved journal entry, read back later.
  ///
  /// Deliberately not generated at save time: the value is in what an entry
  /// looks like from a week's distance, not in another opinion in the moment.
  Future<String> reflectOnEntry({
    required String title,
    required String body,
    required String ask,
    required DateTime savedAt,
    required CounsellorContext ctx,
  });

  /// Turns a week of check-ins into two short paragraphs. Generated on the
  /// device, from data that never left it.
  Future<WeeklyReflection> weeklyReflection({
    required List<int> scores,
    required List<String> words,
    required int untangles,
    required CounsellorContext ctx,
  });

  /// True when the input suggests coercion, abuse or self-harm and the safety
  /// interrupt should show instead of a normal reply.
  ///
  /// This runs *before* any generation, on every entry point. It is not the
  /// model's judgement — a guardrail the model cannot talk its way past.
  bool needsSafetyInterrupt(String input) => safetyClassifier.fires(input);

  /// Whether a real model is loaded. False for the preview engine, which
  /// Settings surfaces rather than implying an AI is answering.
  bool get isPreview => false;
}

/// Scripted engine for simulator and device testing. Replies are deliberately
/// in the counsellor's voice so the UI can be judged on feel, not just layout.
///
/// Replaced wholesale by the Gemma engine after the model spike; nothing above
/// this line changes when that happens.
class MockCounsellorEngine implements CounsellorEngine {
  const MockCounsellorEngine(
      {this.tokenDelay = const Duration(milliseconds: 45)});

  /// Zero in tests, so a widget test does not spend four seconds streaming.
  final Duration tokenDelay;

  @override
  bool get isPreview => true;

  @override
  bool needsSafetyInterrupt(String input) => safetyClassifier.fires(input);

  @override
  Stream<String> reply(
      List<ChatMessage> history, CounsellorContext ctx) async* {
    final turn = history.where((m) => m.fromUser).length;
    final p = ctx.partnerOrDefault;
    final text = switch (turn) {
      0 || 1 => ctx.hindi
          ? '"जो करना है करो" शायद ही कभी इजाज़त होती है। इसका मतलब अक्सर होता है — मैंने सुने जाने की कोशिश छोड़ दी। और अगर यह कल भी हुआ था, तो यह झगड़ा नहीं, एक पैटर्न है।'
          : '“Do whatever you want” is rarely permission. It usually means I gave up trying to be heard. And if it happened yesterday too, that is a pattern, not a fight.',
      2 => ctx.hindi
          ? 'आगे बढ़ने से पहले: जब $p कमरे से चले गए, पहले दो मिनट में आपने क्या किया?'
          : 'Before we go further: when $p walked away, what did you do in the first two minutes?',
      3 => ctx.hindi
          ? 'यह पूरी तरह समझ में आता है। यह दो लोग हैं जो दोनों "मुझे देखो" कह रहे हैं, ऐसे तरीकों से जो दूसरे को अनदेखा महसूस कराते हैं। चाहें तो मैं इसे सुलझा दूँ?'
          : 'That makes complete sense. That is two people both saying “notice me” in ways that make the other feel unnoticed. Want me to untangle this into what happened versus what you each assumed?',
      _ => ctx.hindi
          ? 'याद रखिए आपने शुरुआत क्यों की थी — ${ctx.originStory.isEmpty ? 'वह वजह अभी भी वहीं है।' : '"${ctx.originStory}"'} इसी से आज की बात को जोड़ते हैं।'
          : 'Remember why you started — ${ctx.originStory.isEmpty ? 'that reason is still there.' : '“${ctx.originStory}”'} Let us connect tonight back to that.',
    };

    for (final word in text.split(' ')) {
      if (tokenDelay > Duration.zero) await Future<void>.delayed(tokenDelay);
      yield '$word ';
    }
  }

  @override
  Future<Untangled> untangle(String vent, CounsellorContext ctx) async {
    if (vent.trim().isEmpty) {
      throw const CounsellorException('nothing to untangle');
    }
    await Future<void>.delayed(tokenDelay * 20);
    final p = ctx.partnerOrDefault;
    // Scripted in both languages. A Hindi tester seeing Hindi chrome wrapped
    // around English content is not testing the Hindi experience.
    if (ctx.hindi) {
      return Untangled(
        happened:
            'आपने कुछ कहना चाहा जब $p व्यस्त थे। $p ने कहा "जो करना है करो" और कमरे से चले गए।',
        assumed: 'कि $p को आपके साथ बिताए वक़्त की परवाह नहीं।',
        felt: 'अनदेखा। फिर गुस्सा — उस अनदेखेपन को ढँकने के लिए।',
        need: 'यह जानना कि $p के लिए भी यह मायने रखता है।',
        sentence:
            '"मैंने ग़लत वक़्त पर कहा। मैं ज़बरदस्ती नहीं कर रहा था — बस चाहता हूँ कि यह हम दोनों का हो। आज रात कोई वक़्त तय कर लें?"',
        themes: inferThemes(vent),
      );
    }
    return Untangled(
      happened:
          'You raised something while $p was busy. $p said “do whatever you want” and left the room.',
      assumed: 'That $p does not care about your time together.',
      felt: 'Dismissed. Then angry, to cover the dismissed part.',
      need: 'To know it matters to $p too.',
      sentence:
          '“I asked at a bad moment. I wasn’t trying to push — I just want this to be ours. Can we pick a time tonight?”',
      themes: inferThemes(vent),
    );
  }

  @override
  Future<RepairMerge> mergeRepair(
      RepairSides sides, CounsellorContext ctx) async {
    if (!sides.isComplete) {
      throw const CounsellorException('both sides are needed');
    }
    await Future<void>.delayed(tokenDelay * 26);
    final me = ctx.userOrDefault;
    final p = ctx.partnerOrDefault;
    if (ctx.hindi) {
      return RepairMerge(
        title: 'गुरुवार की रात, बर्तन',
        agreed:
            'देर हो चुकी थी। आप दोनों थके हुए थे। बात असल में बर्तनों की थी ही नहीं।',
        sideA: 'तुम कभी मदद नहीं करते।',
        sideB: 'मैं थक चुका हूँ और इसमें ख़ुद को अकेला महसूस करता हूँ।',
        split: 'एक आज रात की बात कर रहा था। दूसरा पिछले तीन महीनों की।',
        firstTurn:
            '$me, दो मिनट के लिए बस इतना: जो सुना वही दोहराइए, सफ़ाई दिए बिना। शुरू कीजिए — "मैं जो सुन रहा/रही हूँ वह यह है…" — फिर $p की बारी।',
      );
    }
    return RepairMerge(
      title: 'Thursday night, the dishes',
      agreed:
          'It was late. You were both tired. The dishes were not really about the dishes.',
      sideA: 'You never help.',
      sideB: 'I’m exhausted and I feel alone in this.',
      split:
          'One of you was talking about tonight. The other was talking about the last three months.',
      firstTurn:
          '$me, your only job for two minutes: repeat back what you heard, without defending. Start with “What I’m hearing is…” — $p goes second.',
    );
  }

  @override
  Future<KinderRewrite> sayItKinder(String draft, CounsellorContext ctx) async {
    if (draft.trim().isEmpty) {
      throw const CounsellorException('nothing to rewrite');
    }
    await Future<void>.delayed(tokenDelay * 18);
    final p = ctx.partnerOrDefault;
    if (ctx.hindi) {
      return const KinderRewrite(
        kinder:
            'मुझे बुरा लगा जब यह हुआ। मैं समझना चाहता हूँ कि तुम्हारी तरफ़ से क्या था।',
        clearer:
            'जब ऐसा होता है तो मुझे अनदेखा महसूस होता है। क्या हम आज रात दस मिनट बात कर सकते हैं?',
        shorter: 'मुझे तुम्हारी ज़रूरत है — आज रात दस मिनट?',
        keep:
            'आपकी बात में जो ज़रूरत है, वह जायज़ है। बस उसे सुनने लायक़ बनाइए।',
      );
    }
    return KinderRewrite(
      kinder:
          'That landed badly with me, and I would rather tell you than sit on it. What was it like from your side?',
      clearer:
          'When that happens I feel unnoticed. Can we take ten minutes tonight?',
      shorter: 'I need ten minutes with you tonight. Can we?',
      keep:
          'The need underneath this is fair, and $p should hear it. Only the edge is worth losing.',
    );
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
    await Future<void>.delayed(tokenDelay * 18);
    final days = DateTime.now().difference(savedAt).inDays;
    if (ctx.hindi) {
      return days >= 7
          ? 'एक हफ़्ता पहले यह बहुत बड़ा लग रहा था। अब पढ़िए — जो ज़रूरत आपने लिखी थी, वह अब भी वही है। सवाल यह है कि क्या आपने उसे कहा।'
          : 'आपने जो ज़रूरत लिखी, वह साफ़ है। अब भी वही एक वाक्य बाक़ी है — कहा या नहीं?';
    }
    return days >= 7
        ? 'A week ago this felt enormous. Reading it back, the need you wrote down is still the same one. The question is whether you ever said it out loud.'
        : 'The need in this is clear on the page. The one sentence is still sitting there — did it get said?';
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
    await Future<void>.delayed(tokenDelay * 22);
    final average = scores.reduce((a, b) => a + b) / scores.length;
    final rising = scores.length > 1 && scores.last > scores.first;

    if (ctx.hindi) {
      return WeeklyReflection(
        reflection: rising
            ? 'हफ़्ते की शुरुआत दूरी से हुई और अंत क़रीब आते हुए। यह अपने आप नहीं हुआ — आप दोनों ने कुछ किया।'
            : 'यह हफ़्ता ज़्यादातर एक जैसा रहा, औसत ${average.toStringAsFixed(1)} पर। न गिरावट, न उछाल — बस एक सादा हफ़्ता।',
        suggestion:
            'इस हफ़्ते एक छोटी चीज़: दिन में एक बार दस मिनट, बिना फ़ोन के।',
      );
    }
    return WeeklyReflection(
      reflection: rising
          ? 'The week started further apart than it ended. That did not happen on its own — one of you reached, and the other turned toward it.'
          : 'Mostly a level week, averaging ${average.toStringAsFixed(1)}. No slide, no leap. A plain week is not a failed one.',
      suggestion: 'One small thing this week: ten minutes a day, phones down.',
    );
  }

  /// Cheap keyword pass so saved entries carry themes for the 30-day trend.
  /// The Gemma engine returns these in its JSON instead.
  @visibleForTesting
  static List<JournalTheme> inferThemes(String vent) {
    final t = vent.toLowerCase();
    bool any(List<String> words) => words.any(t.contains);
    return [
      if (any([
        'money',
        'salary',
        'kharcha',
        'खर्च',
        'पैसे',
        'paise',
        'rent',
        'emi'
      ]))
        JournalTheme.money,
      if (any([
        'mother',
        'father',
        'in-law',
        'inlaw',
        'saas',
        'sasural',
        'family',
        'माँ',
        'पिता',
        'सास',
        'ससुराल',
        'परिवार',
      ]))
        JournalTheme.family,
      if (any(['intimacy', 'sex', 'touch', 'affection', 'नज़दीक', 'प्यार']))
        JournalTheme.intimacy,
      if (any(
          ['time', 'busy', 'late', 'work', 'office', 'वक्त', 'व्यस्त', 'देर']))
        JournalTheme.time,
      if (any(
          ['lie', 'lied', 'trust', 'phone', 'secret', 'झूठ', 'भरोसा', 'छुपा']))
        JournalTheme.trust,
    ];
  }
}

/// Whichever engine can actually answer right now.
///
/// Gemma when a model is installed, the scripted preview engine otherwise.
/// The app is fully usable in both states — that is deliberate: onboarding,
/// Learn and the safety screen all have to work before a 3.7 GB download
/// finishes, and on a phone where it never will.
///
/// Tests override this provider, so nothing here reaches the native runtime
/// under `flutter test`.
final counsellorEngineProvider = Provider<CounsellorEngine>((ref) {
  final installed = ref.watch(modelManagerProvider.select((s) => s.installed));
  if (installed == null) return const MockCounsellorEngine();

  final engine = GemmaCounsellorEngine(installed);
  ref.onDispose(engine.dispose);
  return engine;
});


/// The slice of app state the counsellor actually needs. Screens that generate
/// something expensive watch this, not [appStateProvider]: a theme flip or a
/// check-in must not throw away a finished reflection.
final counsellorContextProvider = Provider<CounsellorContext>((ref) {
  return ref.watch(appStateProvider.select((a) => CounsellorContext(
        userName: a.userName,
        partnerName: a.partnerName,
        originStory: a.originStory,
        hindi: a.isHindi,
      )));
});

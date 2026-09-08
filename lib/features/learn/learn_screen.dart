import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/journal.dart';
import '../../core/key_value_store.dart';
import '../../core/strings.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../ui/atmosphere.dart';
import '../../ui/glass.dart';

/// One evidence-based idea and the two-minute thing to do about it.
///
/// The deck is 15 cards. The header counts the ones the person has marked
/// done, not the size of the deck.
class LearnCard {
  const LearnCard({
    required this.title,
    required this.titleHi,
    required this.body,
    required this.bodyHi,
    required this.exercise,
    required this.exerciseHi,
  });

  final String title;
  final String titleHi;
  final String body;
  final String bodyHi;
  final String exercise;
  final String exerciseHi;

  String t(bool hindi) => hindi ? titleHi : title;
  String b(bool hindi) => hindi ? bodyHi : body;
  String e(bool hindi) => hindi ? exerciseHi : exercise;
}

const learnCards = <LearnCard>[
  LearnCard(
    title: 'The four horsemen',
    titleHi: 'चार घुड़सवार',
    body:
        'Criticism, contempt, defensiveness and stonewalling predict a breakup better than how often a couple fights. Contempt — eye-rolling, mocking — is the worst of the four.',
    bodyHi:
        'आलोचना, तिरस्कार, सफ़ाई देना और चुप्पी — ये चार चीज़ें रिश्ते के टूटने का अंदाज़ा इससे बेहतर देती हैं कि झगड़े कितने होते हैं। तिरस्कार — आँखें घुमाना, मज़ाक़ उड़ाना — सबसे ख़तरनाक है।',
    exercise:
        'Two minutes: name the horseman you reach for first. Just name it.',
    exerciseHi:
        'दो मिनट: सोचिए आप सबसे पहले किसका सहारा लेते हैं। बस नाम दे दीजिए।',
  ),
  LearnCard(
    title: 'Repair attempts',
    titleHi: 'सुलह की कोशिशें',
    body:
        'Happy couples fight too. The difference is a small move — a joke, a hand on the arm, “can we start over?” — that stops the escalation. Repair attempts fail when the other person doesn’t notice them.',
    bodyHi:
        'ख़ुश जोड़े भी झगड़ते हैं। फ़र्क़ एक छोटी-सी बात का होता है — एक मज़ाक़, कंधे पर हाथ, "फिर से शुरू करें?" — जो बात बढ़ने से रोक देती है। ये कोशिशें तब नाकाम होती हैं जब सामने वाला उन्हें पहचानता ही नहीं।',
    exercise:
        'Agree on one signal you will both recognise as “I’m trying to fix this.”',
    exerciseHi:
        'एक इशारा तय कीजिए जिसे आप दोनों समझें — "मैं इसे ठीक करना चाहता/चाहती हूँ।"',
  ),
  LearnCard(
    title: 'Bids for connection',
    titleHi: 'जुड़ाव की पुकार',
    body:
        '“Look at that bird.” It’s never about the bird. Turning toward small bids — even with a grunt — is what keeps a relationship alive between the big talks.',
    bodyHi:
        '"वो चिड़िया देखो।" बात कभी चिड़िया की नहीं होती। ऐसी छोटी पुकारों की तरफ़ मुड़ना — चाहे बस "हूँ" कहकर — यही रिश्ते को बड़ी बातचीतों के बीच ज़िंदा रखता है।',
    exercise: 'Tonight, count the bids. Turn toward three of them on purpose.',
    exerciseHi: 'आज रात ऐसी पुकारें गिनिए। तीन की तरफ़ जान-बूझकर मुड़िए।',
  ),
  LearnCard(
    title: 'Family boundaries, Indian edition',
    titleHi: 'परिवार की सीमाएँ, भारतीय संदर्भ',
    body:
        'In a joint family “my parents” and “our marriage” overlap by design. The couple has to be a team first, then negotiate with everyone else — not the other way round.',
    bodyHi:
        'संयुक्त परिवार में "मेरे माता-पिता" और "हमारी शादी" का घुलना-मिलना स्वाभाविक है। जोड़े को पहले एक टीम बनना होता है, फिर बाक़ी सबसे बात — उल्टा नहीं।',
    exercise: 'Write one sentence you would both say to a parent, together.',
    exerciseHi: 'एक वाक्य लिखिए जो आप दोनों मिलकर किसी बड़े से कहेंगे।',
  ),
  LearnCard(
    title: 'The flooded brain',
    titleHi: 'उबला हुआ दिमाग़',
    body:
        'Above ~100 bpm you can’t hear anyone. This is biology, not stubbornness. Twenty minutes apart, doing something boring, resets it.',
    bodyHi:
        'दिल की धड़कन 100 से ऊपर जाते ही आप किसी की सुन नहीं सकते। यह ज़िद नहीं, शरीर विज्ञान है। बीस मिनट अलग रहकर कोई नीरस काम करना इसे वापस सामान्य कर देता है।',
    exercise: 'Agree on a time-out word neither of you will argue with.',
    exerciseHi: 'एक ऐसा शब्द तय कीजिए जिस पर आप दोनों में से कोई बहस न करे।',
  ),
  LearnCard(
    title: 'Start the conversation soft',
    titleHi: 'बात नरमी से शुरू कीजिए',
    body:
        'How a conversation begins predicts how it ends about 96% of the time. A hard start — "you always", "why do you never" — cannot be recovered by a good middle. Start with what you feel and what you need, not with what they are.',
    bodyHi:
        'बातचीत जैसे शुरू होती है, लगभग वैसे ही ख़त्म होती है — दस में नौ बार। कड़ी शुरुआत — "तुम हमेशा", "तुम कभी नहीं" — को बीच में सुधारा नहीं जा सकता। शुरुआत इससे कीजिए कि आपको क्या महसूस हुआ और क्या चाहिए, इससे नहीं कि वे कैसे हैं।',
    exercise:
        'Take your last complaint and rewrite it starting with "I felt" instead of "you".',
    exerciseHi:
        'अपनी पिछली शिकायत को "मुझे लगा" से शुरू करके दोबारा लिखिए, "तुम" से नहीं।',
  ),
  LearnCard(
    title: 'The 5:1 ratio',
    titleHi: 'पाँच बनाम एक',
    body:
        'In relationships that last, there are about five warm moments for every sharp one — during the argument, not just afterwards. It is not about arguing less. It is about the ordinary kindness around the argument staying intact.',
    bodyHi:
        'जो रिश्ते टिकते हैं, उनमें हर एक कड़वे पल के मुक़ाबले लगभग पाँच गर्मजोशी वाले पल होते हैं — झगड़े के दौरान भी, सिर्फ़ बाद में नहीं। बात कम झगड़ने की नहीं है। बात यह है कि झगड़े के आसपास की रोज़मर्रा की नरमी बची रहे।',
    exercise:
        'Count today: how many warm exchanges, how many sharp ones? Do not fix it yet. Just count.',
    exerciseHi:
        'आज गिनिए: कितने गर्मजोशी वाले पल, कितने कड़वे? अभी सुधारिए मत। बस गिनिए।',
  ),
  LearnCard(
    title: 'Most problems never get solved',
    titleHi: 'ज़्यादातर मसले कभी हल नहीं होते',
    body:
        'About two-thirds of a couple\'s disagreements are perpetual — rooted in personality, not in a misunderstanding. The task is not to solve them but to talk about them without contempt, again and again, for years. Couples who manage that are not the ones who agree.',
    bodyHi:
        'किसी भी जोड़े के लगभग दो-तिहाई मतभेद स्थायी होते हैं — वे स्वभाव से आते हैं, किसी ग़लतफ़हमी से नहीं। काम उन्हें हल करना नहीं, बल्कि बिना तिरस्कार के बार-बार, सालों तक उन पर बात करते रहना है। जो जोड़े यह कर पाते हैं, वे सहमत होने वाले जोड़े नहीं होते।',
    exercise:
        'Name one thing you will probably argue about for the rest of your lives. Saying it out loud takes some of its weight.',
    exerciseHi:
        'एक ऐसी बात बताइए जिस पर आप शायद ज़िंदगी भर बहस करेंगे। इसे कह देने भर से उसका बोझ कुछ कम हो जाता है।',
  ),
  LearnCard(
    title: 'What is under the position',
    titleHi: 'रुख़ के नीचे क्या है',
    body:
        '"I want to move" and "I want to stay" are positions. Underneath are needs — closeness to a parent, a career, safety, adventure. Two positions cannot both win. Two needs usually can, once they are named.',
    bodyHi:
        '"मुझे जाना है" और "मुझे रुकना है" — ये रुख़ हैं। इनके नीचे ज़रूरतें होती हैं — माता-पिता के पास रहना, करियर, सुरक्षा, कुछ नया। दो रुख़ एक साथ नहीं जीत सकते। दो ज़रूरतें अक्सर जीत सकती हैं, बशर्ते उन्हें नाम दिया जाए।',
    exercise:
        'On your current standoff, each of you says one need — not one demand.',
    exerciseHi:
        'अभी जिस बात पर अड़े हैं, उस पर दोनों एक-एक ज़रूरत बताइए — माँग नहीं।',
  ),
  LearnCard(
    title: 'Accepting influence',
    titleHi: 'दूसरे की बात मानना',
    body:
        'The single strongest predictor of a marriage lasting is whether each partner can let the other change their mind. Not lose an argument — genuinely be moved by them. Refusing to be influenced reads as contempt, however politely it is done.',
    bodyHi:
        'शादी के टिकने का सबसे मज़बूत संकेत यह है कि क्या दोनों एक-दूसरे की बात से अपना मन बदल सकते हैं। बहस हारना नहीं — सचमुच उनकी बात से प्रभावित होना। प्रभावित होने से इनकार तिरस्कार जैसा लगता है, चाहे कितनी ही शालीनता से किया जाए।',
    exercise:
        'Find one thing your partner is right about that you have been resisting. Say so today.',
    exerciseHi:
        'एक बात ढूँढिए जिसमें आपका साथी सही है और आप अड़े हुए थे। आज यह कह दीजिए।',
  ),
  LearnCard(
    title: 'The stonewaller is not calm',
    titleHi: 'चुप्पी शांति नहीं है',
    body:
        'The partner who goes silent usually looks the calmer one and is not — heart rate above 100, unable to take anything in. Silence is not stubbornness or strategy; it is a nervous system that has stopped listening. Pushing harder makes it worse.',
    bodyHi:
        'जो चुप हो जाता है, वह अक्सर ज़्यादा शांत दिखता है — होता नहीं। धड़कन सौ के पार, कुछ भी अंदर नहीं जा रहा। चुप्पी ज़िद या चाल नहीं है; यह वह शरीर है जिसने सुनना बंद कर दिया। और ज़ोर डालने से हालत बिगड़ती ही है।',
    exercise:
        'Agree now, while calm: the person who goes quiet says "I need twenty minutes" and then actually comes back.',
    exerciseHi:
        'अभी, शांत मन से तय कीजिए: जो चुप हो जाए वह कहे "मुझे बीस मिनट चाहिए" — और फिर सचमुच लौटे।',
  ),
  LearnCard(
    title: 'Rituals beat resolutions',
    titleHi: 'रस्में इरादों से बेहतर हैं',
    body:
        '"We should spend more time together" fails. "We have chai on the balcony before anyone else is up" works, because it does not need a decision each time. Small, boring, repeated things carry more weight than grand ones.',
    bodyHi:
        '"हमें साथ ज़्यादा वक़्त बिताना चाहिए" — यह नाकाम होता है। "हम सबके उठने से पहले बालकनी में चाय पीते हैं" — यह चलता है, क्योंकि हर बार तय नहीं करना पड़ता। छोटी, नीरस, दोहराई जाने वाली चीज़ें बड़ी चीज़ों से ज़्यादा वज़न रखती हैं।',
    exercise:
        'Pick one two-minute ritual and attach it to something that already happens every day.',
    exerciseHi:
        'दो मिनट की एक रस्म चुनिए और उसे किसी ऐसी चीज़ से जोड़िए जो रोज़ होती ही है।',
  ),
  LearnCard(
    title: 'Attachment, briefly',
    titleHi: 'लगाव, संक्षेप में',
    body:
        'Under stress some people move toward and some move away. Neither is the healthy one. The trouble is the pattern they make together: the more one pursues, the further the other withdraws, and both are certain the other started it.',
    bodyHi:
        'तनाव में कुछ लोग पास आते हैं, कुछ दूर हट जाते हैं। इनमें से कोई भी "सही" नहीं है। दिक़्क़त वह चक्र है जो दोनों मिलकर बनाते हैं: जितना एक पीछा करता है, उतना दूसरा दूर होता है — और दोनों को यक़ीन होता है कि शुरुआत सामने वाले ने की।',
    exercise:
        'Name the pattern out loud together — "you chase, I go quiet" — without deciding whose fault it is.',
    exerciseHi:
        'इस चक्र को साथ मिलकर नाम दीजिए — "तुम पीछे आते हो, मैं चुप हो जाता हूँ" — बिना यह तय किए कि ग़लती किसकी है।',
  ),
  LearnCard(
    title: 'Money is rarely about money',
    titleHi: 'पैसा शायद ही पैसे के बारे में होता है',
    body:
        'A fight about a purchase is usually a fight about safety, or fairness, or who is allowed to decide. In households where one income supports many people, it is also about duty. Argue about the meaning and the numbers get easier.',
    bodyHi:
        'किसी ख़र्च पर झगड़ा असल में सुरक्षा, इंसाफ़, या यह तय करने के हक़ का झगड़ा होता है कि फ़ैसला कौन करेगा। जिन घरों में एक कमाई से कई लोग चलते हैं, वहाँ यह फ़र्ज़ का भी सवाल है। मतलब पर बात कीजिए, आँकड़े अपने आप आसान हो जाएँगे।',
    exercise:
        'Each of you finishes this: "Money in my family growing up meant ___."',
    exerciseHi:
        'दोनों यह वाक्य पूरा कीजिए: "बचपन में मेरे घर में पैसे का मतलब था ___।"',
  ),
  LearnCard(
    title: 'Repair is a skill, not a feeling',
    titleHi: 'सुलह हुनर है, भावना नहीं',
    body:
        'You do not have to feel warm to make a repair. Saying "that came out harsher than I meant" while still angry is not dishonest — it is the skill. The feeling tends to follow the sentence rather than precede it.',
    bodyHi:
        'सुलह के लिए दिल का नरम होना ज़रूरी नहीं। ग़ुस्से में रहते हुए भी यह कहना कि "यह जितना कड़ा निकला, उतना कहना नहीं चाहता था" — यह बेईमानी नहीं, यही हुनर है। भावना अक्सर वाक्य के पीछे आती है, आगे नहीं।',
    exercise:
        'Learn one repair sentence by heart, so it is there when you are too angry to compose one.',
    exerciseHi:
        'सुलह का एक वाक्य याद कर लीजिए, ताकि जब ग़ुस्से में कुछ सूझे नहीं, तब वह मौजूद हो।',
  ),
];

/// Which cards the person has marked done. Persisted, so the header can count
/// their progress rather than restating the size of the deck.
class LearnProgress extends StateNotifier<Set<String>> {
  LearnProgress(this._store) : super(load(_store));

  final KeyValueStore _store;
  static const _key = 'saath.learnDone';

  @visibleForTesting
  static Set<String> load(KeyValueStore store) {
    final raw = store.getString(_key);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final list = jsonDecode(raw);
      return list is List ? {for (final t in list) if (t is String) t} : const {};
    } on FormatException {
      return const {};
    }
  }

  Future<void> toggle(String title) async {
    final next = {...state};
    if (!next.remove(title)) next.add(title);
    state = next;
    await _store.setString(_key, jsonEncode(next.toList()));
  }

  Future<void> clear() async {
    state = const {};
    await _store.remove(_key);
  }
}

final learnProgressProvider =
    StateNotifierProvider<LearnProgress, Set<String>>(
  (ref) => LearnProgress(ref.watch(keyValueStoreProvider)),
);

class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context, ref);
    final hindi = s.isHindi;
    final t = Theme.of(context).textTheme;
    final surface = context.surface;
    final done = ref.watch(learnProgressProvider);

    return StageTheme(
      stage: ResolutionStage.calm,
      child: Atmosphere(
        background: Backgrounds.origin,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              24, MediaQuery.paddingOf(context).top + 12, 24, 140),
          children: [
            Eyebrow(s.learnCount(done.length, learnCards.length),
                color: surface.ink2),
            const SizedBox(height: 4),
            Text(s.learnTitle, style: t.headlineMedium),
            if (done.length == learnCards.length) ...[
              const SizedBox(height: 8),
              Text(s.learnAllDone,
                  style: t.bodyMedium?.copyWith(color: surface.ink2)),
            ],
            const SizedBox(height: 18),
            for (final c in learnCards) ...[
              _LearnCardView(card: c, done: done.contains(c.title)),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

/// One card. The idea is always visible; the exercise — the actionable half —
/// is behind a tap, so fifteen cards are a scannable list rather than a wall.
class _LearnCardView extends ConsumerStatefulWidget {
  const _LearnCardView({required this.card, required this.done});

  final LearnCard card;
  final bool done;

  @override
  ConsumerState<_LearnCardView> createState() => _LearnCardViewState();
}

class _LearnCardViewState extends ConsumerState<_LearnCardView> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context, ref);
    final hindi = s.isHindi;
    final t = Theme.of(context).textTheme;
    final c = widget.card;
    final sage = Theme.of(context).colorScheme.secondary;
    final showExercise = _open || widget.done;

    return GlassPanel(
      strong: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(c.t(hindi), style: t.titleMedium),
                ),
              ),
              if (widget.done)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Icon(Icons.check_circle_rounded, size: 20, color: sage),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(c.b(hindi), style: t.bodySmall?.copyWith(fontSize: 15)),
          const SizedBox(height: 12),
          if (!showExercise)
            GlassChip(
              label: s.learnShowExercise,
              icon: Icons.timer_outlined,
              onTap: () => setState(() => _open = true),
            )
          else ...[
            TintPanel(
              label: s.twoMinuteExercise,
              color: context.stage.accent,
              child: Text(c.e(hindi)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GlassChip(
                  label: widget.done ? s.learnDone : s.learnMarkDone,
                  icon: widget.done
                      ? Icons.check_rounded
                      : Icons.radio_button_unchecked_rounded,
                  active: widget.done,
                  selectable: true,
                  onTap: () =>
                      ref.read(learnProgressProvider.notifier).toggle(c.title),
                ),
                GlassChip(
                  label: s.learnSaveToJournal,
                  icon: Icons.bookmark_border_rounded,
                  onTap: () async {
                    await ref.read(journalProvider.notifier).add(
                          kind: JournalKind.note,
                          title: c.t(hindi),
                          body: c.e(hindi),
                        );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(s.saved)));
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state.dart';

/// EN/HI string table.
///
/// Still a hand-written map rather than ARB + `gen_l10n`: the copy is the
/// product here and it is still moving. The rule that keeps it honest is that
/// **every** user-visible string lives in this file — a literal in a widget is
/// a string that will ship in English to a Hindi user, which is what half of
/// this app used to do.
///
/// Read it with `S.of(context, ref)`. That watches only the language, so
/// changing a check-in score does not rebuild every screen that reads copy.
class S {
  const S._(this._lang);

  final AppLanguage _lang;

  static S of(BuildContext context, WidgetRef ref) =>
      S._(ref.watch(appStateProvider.select((s) => s.language)));

  /// For code that has a [Ref] but no [BuildContext] (controllers, engines).
  static S read(Ref ref) => S._(ref.read(appStateProvider).language);

  /// For widget code that has a [WidgetRef] but must not subscribe — a
  /// callback firing outside build, for instance.
  static S readWidget(WidgetRef ref) =>
      S._(ref.read(appStateProvider).language);

  @visibleForTesting
  static S forLanguage(AppLanguage l) => S._(l);

  bool get isHindi => _lang == AppLanguage.hi;
  AppLanguage get appLanguage => _lang;

  String _t(String en, String hi) => _lang == AppLanguage.hi ? hi : en;

  // ── Identity ──────────────────────────────────────────────────────────────
  String get appName => 'Vyuhbhed';
  String get appNameDevanagari => 'व्यूहभेद';
  String get tagline => _t(
      'Most problems are simple. Your brain makes them big.',
      'ज़्यादातर मसले आसान होते हैं। दिमाग़ उन्हें बड़ा बना देता है।');
  String get taglineSub => _t(
      'A counsellor that lives on your phone, never leaves it, and remembers why you two started.',
      'एक काउंसलर जो आपके फ़ोन में रहता है, कहीं नहीं जाता, और याद रखता है कि आप दोनों ने शुरुआत क्यों की थी।');
  String get freePrivateOffline =>
      _t('Free. Private. Works offline.', 'मुफ़्त। निजी। बिना इंटरनेट भी।');
  String get startEnglish => 'Start in English';
  String get startHindi => 'हिंदी में शुरू करें';

  // ── Web build ─────────────────────────────────────────────────────────────
  String get webPreviewBanner => _t(
        'A preview. The coach here gives sample replies — the real one runs on your phone, offline.',
        'यह एक झलक है। यहाँ कोच के जवाब नमूने हैं — असली कोच आपके फ़ोन पर, बिना इंटरनेट चलता है।',
      );
  String get webPreviewShort => _t(
        'Preview — sample replies, not the real coach.',
        'झलक — नमूने के जवाब, असली कोच नहीं।',
      );
  String get webWhyNoModel => _t(
        'The counsellor is a model that runs on your phone. A browser is the wrong place for a download that size, so this preview uses written sample replies instead. Everything else here is the real app.',
        'काउंसलर एक मॉडल है जो आपके फ़ोन पर चलता है। इतने बड़े डाउनलोड के लिए ब्राउज़र सही जगह नहीं, इसलिए इस झलक में लिखे हुए नमूना जवाब हैं। बाक़ी सब असली ऐप ही है।',
      );

  // ── Common ────────────────────────────────────────────────────────────────
  String get continueLabel => _t('Continue', 'आगे');
  String get cancel => _t('Cancel', 'रहने दें');
  String get close => _t('Close', 'बंद करें');
  String get done => _t('Done', 'हो गया');
  String get save => _t('Save', 'सहेजें');
  String get saved => _t('Saved to your journal', 'आपकी डायरी में सहेजा गया');
  String get copy => _t('Copy', 'कॉपी करें');
  String get copied => _t('Copied', 'कॉपी हो गया');
  String get delete => _t('Delete', 'मिटाएँ');
  String get back => _t('Back', 'वापस');
  String get retry => _t('Try again', 'फिर कोशिश करें');
  String get notYet =>
      _t('Not in this build yet', 'यह अभी इस बिल्ड में नहीं है');

  // ── Tabs ──────────────────────────────────────────────────────────────────
  String get tabToday => _t('Today', 'आज');
  String get tabCounsellor => _t('Counsellor', 'काउंसलर');
  String get tabUs => _t('Us', 'हम');
  String get tabLearn => _t('Learn', 'सीखें');

  // ── Onboarding ────────────────────────────────────────────────────────────
  // Intro slides on the welcome screen. Swipeable; the start buttons stay
  // visible under every slide so nobody is forced to read them.
  String get introPrivateTitle => _t('Nothing you say leaves your phone.',
      'आप जो कहते हैं, फ़ोन से बाहर नहीं जाता।');
  String get introPrivateBody => _t(
      'The counsellor is a small AI model downloaded once and run on the phone itself. No account, no server, nobody reading along. Delete the app and it is all gone.',
      'काउंसलर एक छोटा AI मॉडल है जो एक बार डाउनलोड होकर फ़ोन पर ही चलता है। न कोई खाता, न सर्वर, न कोई पढ़ने वाला। ऐप हटाइए, सब मिट जाता है।');
  String get introToolsTitle =>
      _t('Three tools for the hard moments.', 'मुश्किल पलों के लिए तीन औज़ार।');
  String get introUntangle => _t(
      'Untangle — pour it out, get back what is actually going on.',
      'उलझन सुलझाएँ — जो मन में है लिखिए, जो सच में चल रहा है वह वापस पाइए।');
  String get introRepair => _t(
      'Repair Room — both sides, one phone passed across, a fair way through.',
      'सुलह कक्ष — दोनों पक्ष, एक फ़ोन आपस में, एक निष्पक्ष रास्ता।');
  String get introPulse => _t(
      'Weekly pulse — a one-tap daily check-in and a Sunday reflection.',
      'साप्ताहिक नब्ज़ — रोज़ एक टैप की जाँच और रविवार को एक सोच।');
  String get introOriginTitle => _t('It remembers why you two started.',
      'यह याद रखता है कि आप दोनों ने शुरुआत क्यों की।');
  String get introOriginBody => _t(
      'You write, once, why you chose each other. Every hard conversation ends by coming back to it.',
      'आप एक बार लिखते हैं कि आपने एक-दूसरे को क्यों चुना। हर मुश्किल बातचीत उसी पर लौटकर ख़त्म होती है।');
  String introSlide(int n, int total) =>
      _t('Slide $n of $total', 'स्लाइड $n / $total');
  String get introNext => _t('Next', 'अगला');

  String stepOf(int step, int total) =>
      _t('Step $step of $total', 'चरण $step / $total');
  String get namesTitle =>
      _t('Who are we talking about?', 'बात किसके बारे में है?');
  String get yourName => _t('Your name', 'आपका नाम');
  String get partnerName => _t('Partner’s name', 'साथी का नाम');
  String get whereAreYou =>
      _t('Where are you two right now?', 'आप दोनों अभी कहाँ हैं?');
  String stageLabel(RelationshipStage s) => switch (s) {
        RelationshipStage.dating => _t('Dating', 'डेटिंग'),
        RelationshipStage.engaged => _t('Engaged', 'सगाई हो चुकी'),
        RelationshipStage.married => _t('Married', 'शादीशुदा'),
        RelationshipStage.longDistance => _t('Long-distance', 'दूर-दूर'),
        RelationshipStage.roughPatch => _t('Rough patch', 'मुश्किल दौर'),
      };
  String get whyWeStarted => _t('Why we started', 'हमने शुरुआत क्यों की');
  String whyChoose(String p) =>
      _t('Why did you choose $p?', 'आपने $p को क्यों चुना?');
  String get originHint => _t(
      'Say it the way you would tell a friend. Only you can see this — until you both choose to share it.',
      'वैसे ही कहिए जैसे किसी दोस्त को बताते। इसे सिर्फ़ आप देख सकते हैं — जब तक आप दोनों साझा न करना चाहें।');
  String get originPlaceholder =>
      _t('The first thing that comes to mind…', 'जो पहली बात मन में आए…');
  String get keepThis => _t('Keep this', 'इसे रखें');
  String get originLater =>
      _t('I’ll write this later', 'मैं बाद में लिखूँगा/लिखूँगी');
  String get originFooter => _t(
      'Saath brings this back to you at the end of every hard conversation.',
      'हर मुश्किल बातचीत के अंत में साथ इसे आपके सामने लाता है।');
  String typedWords(int n) => _t('Typed · $n words', 'लिखा हुआ · $n शब्द');
  String get sayItInstead => _t('Say it instead', 'बोलकर कहें');
  String get voiceComingSoon => _t(
      'Voice input arrives with the on-device model. Typing works today.',
      'बोलकर कहने की सुविधा ऑन-डिवाइस मॉडल के साथ आएगी। अभी टाइप करें।');

  // ── The on-device model ───────────────────────────────────────────────────
  String get modelTitle => _t('Bring the coach home', 'कोच को घर ले आइए');
  String get modelBody => _t(
        'The coach is a model that runs on this phone. Download it once and it never needs the internet again — and nothing you type leaves the device.',
        'कोच एक मॉडल है जो इसी फ़ोन पर चलता है। एक बार डाउनलोड कीजिए, फिर कभी इंटरनेट की ज़रूरत नहीं — और आपकी कोई बात फ़ोन से बाहर नहीं जाती।',
      );
  String modelSize(String size) => _t('$size download', '$size डाउनलोड');
  String get modelWifiLabel => _t('Before you start', 'शुरू करने से पहले');
  String get modelWifi => _t(
        'Use Wi-Fi. This is a large file and it will not resume on its own if the connection drops.',
        'वाई-फ़ाई पर कीजिए। फ़ाइल बड़ी है और कनेक्शन टूटने पर अपने आप दोबारा शुरू नहीं होगी।',
      );
  String get modelDownload => _t('Download', 'डाउनलोड करें');
  String get modelDownloading => _t('Downloading…', 'डाउनलोड हो रहा है…');

  /// Not routed through _t: a percentage reads the same in both.
  String modelPercent(int percent) => '$percent%';
  String modelRemaining(String time) =>
      _t('about $time left', 'लगभग $time बाक़ी');
  String get modelCancel => _t('Cancel download', 'डाउनलोड रोकें');
  String get modelLater => _t('Not now', 'अभी नहीं');
  String get modelSkipNote => _t(
        'You can start without it. Planning and tracking work today; the coach gives sample replies until a model is here or you add a Gemini key in Settings.',
        'आप इसके बिना भी शुरू कर सकते हैं। योजना और ट्रैकिंग आज भी चलती है; मॉडल या Gemini key आने तक कोच नमूना जवाब देगा।',
      );
  String get modelReady =>
      _t('The coach is on your phone', 'कोच आपके फ़ोन पर है');
  String modelReadyBody(String name) => _t(
        '$name is running here, offline. Nothing you say to it is sent anywhere.',
        '$name यहीं चल रहा है, बिना इंटरनेट। आप जो कहेंगे वह कहीं नहीं भेजा जाएगा।',
      );
  String get modelRemove => _t('Remove the model', 'मॉडल हटाएँ');
  String modelRemoveBody(String size) => _t(
        'Frees $size. The counsellor goes back to its scripted preview until you download it again.',
        '$size खाली होगा। जब तक आप दोबारा डाउनलोड न करें, काउंसलर अपने लिखे हुए प्रीव्यू पर लौट जाएगा।',
      );
  String get modelRemoveConfirm => _t('Remove it?', 'हटा दें?');
  String get modelChoose => _t('Which model', 'कौन-सा मॉडल');
  String get modelRecommended =>
      _t('Recommended for this phone', 'इस फ़ोन के लिए सुझाया गया');
  String modelRamNote(int gb) => _t(
        'This phone has about $gb GB of RAM.',
        'इस फ़ोन में लगभग $gb GB RAM है।',
      );
  String get modelBigName =>
      _t('Better Hindi, needs 6 GB', 'बेहतर हिंदी, 6 GB चाहिए');
  String get modelSmallName =>
      _t('Lighter, works on 4 GB', 'हल्का, 4 GB पर चलता है');
  String get modelOpenName =>
      _t('No licence needed, larger', 'बिना लाइसेंस, बड़ा');
  String get modelNotConfigured => _t(
        'This build has no download host configured, so the counsellor stays in preview.',
        'इस बिल्ड में डाउनलोड होस्ट सेट नहीं है, इसलिए काउंसलर प्रीव्यू में ही रहेगा।',
      );
  String get modelFailed =>
      _t('The download did not finish.', 'डाउनलोड पूरा नहीं हुआ।');

  // ── Say it kinder ─────────────────────────────────────────────────────────
  String get sayItKinder => _t('Say it kinder', 'नरमी से कहें');
  String get sayItKinderTitle => _t('Before you send it', 'भेजने से पहले');
  String get sayItKinderHint => _t(
        'Paste what you are about to send. Saath will offer three ways to say the same thing — you still choose, including your own words.',
        'जो भेजने वाले हैं वह यहाँ रखिए। साथ उसी बात को कहने के तीन तरीक़े देगा — चुनाव आपका ही रहेगा, अपने शब्दों समेत।',
      );
  String get sayItKinderAction => _t('Rewrite it', 'दोबारा लिखें');
  String get sayItKinderWorking =>
      _t('Finding softer words…', 'नरम शब्द ढूँढ रहा हूँ…');
  String get sayItKinderKeep => _t('Worth keeping', 'यह रखने लायक़ है');
  String get sayItKinderEmpty =>
      _t('Write the message first.', 'पहले संदेश लिखिए।');

  // ── Weekly pulse ──────────────────────────────────────────────────────────
  String get weeklyPulse => _t('Your week', 'आपका हफ़्ता');
  String get weeklyPulseSub => _t(
        'Made on this phone, from check-ins that never left it.',
        'इसी फ़ोन पर बना, उन चेक-इन से जो कभी बाहर नहीं गए।',
      );
  String get weeklyPulseEmpty => _t(
        'Check in a few days this week and Saath will have something to show you.',
        'इस हफ़्ते कुछ दिन चेक-इन कीजिए, फिर साथ आपको कुछ दिखा पाएगा।',
      );
  String get weeklyPulseWorking =>
      _t('Reading your week…', 'आपका हफ़्ता पढ़ रहा हूँ…');
  String weeklyAverage(String value) => _t('Average $value', 'औसत $value');
  String get weeklyOneThing => _t('One thing this week', 'इस हफ़्ते एक चीज़');
  String get weeklyWords => _t('Your words', 'आपके शब्द');
  String get openWeeklyPulse => _t('See your week', 'अपना हफ़्ता देखें');

  // ── Today ─────────────────────────────────────────────────────────────────
  String greeting(String name) {
    final h = DateTime.now().hour;
    final en = h < 12 ? 'Morning' : (h < 17 ? 'Afternoon' : 'Evening');
    final hi = h < 12 ? 'सुप्रभात' : (h < 17 ? 'नमस्ते' : 'शुभ संध्या');
    return _t('$en, $name', '$hi, $name');
  }

  /// Fallback when the user skipped their own name.
  String get friend => _t('there', 'दोस्त');

  String get checkinLabel => _t('30-second check-in', '30 सेकंड का चेक-इन');
  String get checkinQ => _t('How connected do you feel today?',
      'आज आप कितना जुड़ा हुआ महसूस कर रहे हैं?');
  String get connectionLow => _t('Far apart', 'बहुत दूर');
  String get connectionHigh => _t('Close', 'बहुत क़रीब');
  String get oneWord => _t('One word for today?', 'आज के लिए एक शब्द?');
  String get oneWordHint =>
      _t('e.g. tired, warm, tense', 'जैसे थका, गर्मजोशी, तनाव');
  String get savedForToday => _t('Saved for today.', 'आज के लिए सहेजा गया।');
  String get talkToSaath => _t('Talk to Saath', 'साथ से बात करें');
  String get undo => _t('Undo', 'वापस लाएँ');
  String get talkPreviewChip => _t('Sample replies · get the real counsellor',
      'नमूना जवाब · असली काउंसलर लाएँ');
  String get firstDayTitle => _t('Your first day here', 'यहाँ आपका पहला दिन');
  String get firstDayBody => _t(
      'Two small things are enough today: tap how connected you feel, and tell Saath one thing that is on your mind. Everything else follows from those.',
      'आज दो छोटी बातें काफ़ी हैं: टैप करके बताइए कितना जुड़ा महसूस कर रहे हैं, और साथ को एक बात बताइए जो मन में है। बाक़ी सब इसी से निकलता है।');
  String talkPrompt(String partner) => _t(
      'Something on your mind about $partner? Say it messy — I will untangle it.',
      '$partner को लेकर कुछ मन में है? जैसे भी हो, कह दीजिए — मैं सुलझा दूँगा।');
  String get promptSameFight => _t('Same fight again', 'फिर वही झगड़ा');
  String get promptRegret => _t('About to say something I’ll regret',
      'कुछ ऐसा कहने वाला हूँ जिसका पछतावा होगा');
  String get promptStoppedTalking => _t('We stopped talking about real things',
      'हमने असली बातें करना बंद कर दिया');
  String fromPartner(String p) => _t('From $p', '$p की ओर से');
  String get notPairedYet => _t(
      'Not paired yet · pairing arrives with the couple layer',
      'अभी जोड़ा नहीं गया · पेयरिंग कपल-लेयर के साथ आएगी');
  String get thisWeek => _t('This week', 'इस हफ़्ते');
  String checkinsThisWeek(int n) =>
      _t('$n of 7 check-ins', '7 में से $n चेक-इन');
  String get pulseReportSunday =>
      _t('Pulse report ready Sunday', 'पल्स रिपोर्ट रविवार को');
  String get openSettings => _t('Settings', 'सेटिंग्स');
  String get openJournal => _t('Journal', 'डायरी');

  // ── Counsellor ────────────────────────────────────────────────────────────
  String get onThisPhoneOnly => _t('On this phone only', 'सिर्फ़ इसी फ़ोन पर');
  String get sayItMessy => _t('Say it messy…', 'जैसे भी हो, कह दीजिए…');
  String get sendMessage => _t('Send', 'भेजें');
  String get counsellorEmptyTitle => _t(
      'Say it messy. I will find the simple thing underneath.',
      'जैसे भी हो, कह दीजिए। मैं उसके नीचे की आसान बात ढूँढ लूँगा।');
  String get untangleIt => _t('Untangle it', 'सुलझाओ');
  String get helpMeSaySorry =>
      _t('Help me say sorry', 'माफ़ी माँगने में मदद करो');
  String get thinking => _t('Thinking…', 'सोच रहा हूँ…');
  String get stopGenerating => _t('Stop', 'रोकें');
  String get counsellorFailed => _t('I lost my thread there. Say that again?',
      'मेरी बात टूट गई। एक बार फिर कहिए?');
  String get clearConversation =>
      _t('Clear this conversation', 'यह बातचीत मिटाएँ');
  String get conversationCleared => _t('Conversation cleared', 'बातचीत मिट गई');

  // ── Voice ─────────────────────────────────────────────────────────────────
  String get voiceStart => _t('Speak instead', 'बोलकर कहें');
  String get voiceListening => _t('Listening…', 'सुन रहा हूँ…');
  String get voiceStop => _t('Stop listening', 'सुनना बंद करें');
  String get voiceUnavailable => _t(
        'This phone has no speech recogniser Saath can use. The keyboard still works.',
        'इस फ़ोन में ऐसा स्पीच रिकॉग्नाइज़र नहीं जिसे साथ इस्तेमाल कर सके। कीबोर्ड फिर भी चलेगा।',
      );
  String get voiceDenied => _t(
        'Saath needs the microphone to hear you. You can turn it on in your phone’s settings.',
        'सुनने के लिए साथ को माइक्रोफ़ोन चाहिए। इसे फ़ोन की सेटिंग्स में चालू कर सकते हैं।',
      );
  String get voicePrivacyNote => _t(
        'Your phone does the listening, not Saath’s servers — there are none. Some phones still send audio to the OS maker to transcribe it. If that matters to you, type instead.',
        'सुनने का काम आपका फ़ोन करता है, साथ के सर्वर नहीं — वे हैं ही नहीं। कुछ फ़ोन फिर भी ऑडियो अपने OS निर्माता को भेजते हैं। अगर यह चिंता की बात है, तो टाइप कीजिए।',
      );
  String get readAloud => _t('Read aloud', 'पढ़कर सुनाएँ');
  String get readAloudStop => _t('Stop reading', 'पढ़ना रोकें');

  // ── Untangle ──────────────────────────────────────────────────────────────
  String get untangled => _t('Untangled', 'सुलझा हुआ');
  String get simpleVersion => _t('The simple version', 'आसान रूप');
  String get untangleSub => _t(
      'Your vent, sorted. Nothing here is a verdict — check what feels true.',
      'आपकी बात, छाँटी हुई। यह कोई फ़ैसला नहीं है — देखिए क्या सच लगता है।');
  String get untangleSorting =>
      _t('Sorting the story from the facts…', 'कहानी और तथ्य अलग कर रहा हूँ…');
  String get untangleFailed =>
      _t('I could not untangle that one.', 'मैं इसे सुलझा नहीं पाया।');
  String get whatHappened => _t('What happened', 'क्या हुआ');
  String get whatIAssumed => _t('What I assumed', 'मैंने क्या मान लिया');
  String get whatIFelt => _t('What I felt', 'मुझे क्या महसूस हुआ');
  String get whatINeed => _t('What I need', 'मुझे क्या चाहिए');
  String get oneSentence =>
      _t('One sentence you could say', 'एक वाक्य जो आप कह सकते हैं');
  String sendTo(String p) => _t('Send to $p', '$p को भेजें');
  String get copyTheAsk => _t('Copy the sentence', 'वाक्य कॉपी करें');
  String get notRight => _t(
      'Not quite right? That is fine — it is a draft, not a verdict.',
      'ठीक नहीं लगा? कोई बात नहीं — यह मसौदा है, फ़ैसला नहीं।');
  String get nothingToUntangle => _t(
      'Tell Saath what happened first, then I can untangle it.',
      'पहले साथ को बताइए क्या हुआ, फिर मैं इसे सुलझाऊँगा।');
  String get pairingComingSoon => _t(
      'Sending to your partner needs pairing — that is the couple-layer build.',
      'साथी को भेजने के लिए पेयरिंग चाहिए — वह कपल-लेयर बिल्ड में आएगी।');

  // ── Repair Room ───────────────────────────────────────────────────────────
  String get repairRoom => _t('Repair Room', 'रिपेयर रूम');
  String get yourSidePrivate => _t('Your side · private', 'आपका पक्ष · निजी');
  String partnerSidePrivate(String p) =>
      _t('$p’s side · private', '$p का पक्ष · निजी');
  String whatHappenedAs(String who) =>
      _t('What happened, as $who saw it?', '$who की नज़र से क्या हुआ?');
  String get onlySaathReads => _t(
      'Only Saath reads this. Your partner sees the neutral version, never your words.',
      'इसे सिर्फ़ साथ पढ़ता है। आपका साथी तटस्थ रूप देखेगा, आपके शब्द कभी नहीं।');
  String get startAnywhere => _t('Start anywhere…', 'कहीं से भी शुरू करें…');
  String get submitMySide => _t('Submit my side', 'मेरा पक्ष दर्ज करें');
  String get bothSidesMerge =>
      _t('Both sides in — merge', 'दोनों पक्ष आ गए — मिलाएँ');
  String get sideSealed => _t('Your side is sealed.', 'आपका पक्ष सील हो गया।');
  String handToPartner(String p) => _t(
      'Hand the phone to $p. They will not see what you wrote.',
      'फ़ोन $p को दीजिए। वे नहीं देख पाएँगे कि आपने क्या लिखा।');
  String iAmPartner(String p) => _t('I am $p', 'मैं $p हूँ');
  String get needBothSides => _t(
      'Both sides need a few words before Saath can find the middle.',
      'बीच का रास्ता निकालने के लिए दोनों पक्षों का कुछ लिखा होना ज़रूरी है।');
  String get bothSidesIn => _t('Both sides are in', 'दोनों पक्ष आ गए');
  String get youBothAgree => _t('You both agree', 'आप दोनों सहमत हैं');
  String get storiesSplit =>
      _t('Where the stories split', 'जहाँ कहानियाँ अलग होती हैं');
  String heardLabel(String who) => _t('$who heard', '$who ने सुना');
  String saidLabel(String who) => _t('$who said', '$who ने कहा');
  String get repairMerging =>
      _t('Finding the shared facts…', 'साझा तथ्य ढूँढ रहा हूँ…');
  String get repairMergeFailed =>
      _t('I could not merge those two.', 'मैं इन दोनों को मिला नहीं पाया।');
  String turnHeader(int turn, int total, String speaker, String listener) => _t(
      'Turn $turn of $total · $speaker speaks, $listener listens',
      'बारी $turn / $total · $speaker बोलेंगे, $listener सुनेंगे');
  String turnInstruction(String listener) => _t(
      '$listener, repeat back what you heard, without defending. Then say one thing you need.',
      '$listener, जो सुना वही दोहराइए, सफ़ाई दिए बिना। फिर एक चीज़ बताइए जो आपको चाहिए।');
  String get startTurn => _t('Start turn', 'बारी शुरू करें');
  String get turnRunning => _t('Turn running', 'बारी चल रही है');
  String get turnsDone => _t('All four turns done', 'चारों बारियाँ पूरी');
  String get finishRepair => _t('Finish', 'पूरा करें');
  String get coolDown => _t('Cool down', 'शांत हों');
  String get breatheIn => _t('breathe in', 'साँस लें');
  String get breatheOut => _t('breathe out', 'साँस छोड़ें');
  String get coolDownBody => _t(
      'Twenty minutes is how long a flooded nervous system takes to settle. The room will still be here.',
      'बीस मिनट — इतना समय लगता है उबले हुए दिमाग़ को शांत होने में। रूम यहीं रहेगा।');
  String get coolDownDone => _t('Twenty minutes. You can go back now.',
      'बीस मिनट पूरे। अब लौट सकते हैं।');
  String get backToRoom => _t('Back to the room', 'रूम में वापस');
  String coolDownPreset(int minutes) => _t('$minutes min', '$minutes मिनट');
  String get repairSavedToJournal => _t('This room is saved in your journal.',
      'यह रूम आपकी डायरी में सहेजा गया है।');
  String get repaired => _t('Repaired', 'सुलझ गया');
  String get repairedTitle => _t('You both stayed. That is the whole thing.',
      'आप दोनों टिके रहे। बस यही सब कुछ है।');
  String get repairedBody => _t(
      'The fight was never the point. Feeling alone in it was. You said that out loud tonight — and you were heard.',
      'झगड़ा कभी असली बात नहीं थी। उसमें अकेला महसूस करना थी। आज आपने वह कह दिया — और सुना गया।');
  String get inYourWords => _t('in your words', 'आपके शब्दों में');
  String get originNotWritten =>
      _t('You have not written yours yet.', 'आपने अभी अपनी बात नहीं लिखी।');
  String get closeRoom => _t('Close the room', 'रूम बंद करें');
  String get planSmallThing =>
      _t('Plan a small thing this week', 'इस हफ़्ते कुछ छोटा-सा प्लान करें');

  // ── Couple Space ──────────────────────────────────────────────────────────
  String get usLabel => _t('Us', 'हम');
  String originRevealHintUnwritten(String p) => _t(
      'Write yours in Settings. When $p writes theirs, you reveal them together.',
      'अपनी बात सेटिंग्स में लिखिए। जब $p अपनी लिखेंगे, तो दोनों साथ मिलकर खोलिएगा।');
  String originRevealHintWritten(String p) => _t(
      'Yours is written. When $p writes theirs, reveal them together on the same evening, when you are both ready.',
      'आपकी लिखी जा चुकी है। जब $p अपनी लिखेंगे, तो किसी एक शाम दोनों साथ मिलकर खोलिएगा — जब दोनों तैयार हों।');
  String get planTheReveal => _t('Plan the reveal', 'खोलने की योजना बनाएँ');
  String get loveMap => _t('Love map', 'लव मैप');
  String get loveMapSub => _t(
        'The questions are the point. Most people cannot name what they do not know.',
        'सवाल ही असली बात हैं। ज़्यादातर लोग यह नहीं बता पाते कि वे क्या नहीं जानते।',
      );

  /// Ten love-map prompts, asked about the partner by name.
  List<String> loveMapPrompts(String p) => [
        _t('What is $p worried about right now?',
            'अभी $p किस बात से परेशान हैं?'),
        _t('What small thing makes $p’s day better?',
            'कौन-सी छोटी बात $p का दिन बेहतर कर देती है?'),
        _t('Who does $p turn to when it is bad?',
            'बुरे वक़्त में $p किसके पास जाते हैं?'),
        _t('What is $p secretly proud of?',
            '$p किस बात पर चुपचाप गर्व करते हैं?'),
        _t('What does $p find hardest about their family?',
            'अपने परिवार में $p को सबसे मुश्किल क्या लगता है?'),
        _t('What would $p do with a free Sunday?',
            'एक ख़ाली रविवार मिले तो $p क्या करेंगे?'),
        _t('What is $p most afraid of losing?',
            '$p को सबसे ज़्यादा किसे खोने का डर है?'),
        _t('Where would $p go, anywhere at all?',
            'कहीं भी जा सकें तो $p कहाँ जाएँगे?'),
        _t('What did $p want to be at fifteen?',
            'पंद्रह साल की उम्र में $p क्या बनना चाहते थे?'),
        _t('What does $p wish you asked about more?',
            '$p चाहते हैं कि आप किस बारे में और पूछें?'),
      ];

  String get loveMapAnswer => _t('Your answer', 'आपका जवाब');
  String get loveMapUnanswered => _t('Not yet', 'अभी नहीं');
  String loveMapProgress(int known, int total) =>
      _t('$known of $total', '$total में से $known');
  String get loveMapAsk => _t('Ask, don’t guess', 'पूछिए, अंदाज़ा मत लगाइए');

  String get goals => _t('Shared goals', 'साझा लक्ष्य');
  String get goalAdd => _t('Add a goal', 'लक्ष्य जोड़ें');
  String get goalHint => _t(
        'Something small and this week. "One phone-free dinner" beats "communicate better".',
        'कुछ छोटा और इसी हफ़्ते का। "एक फ़ोन-मुक्त डिनर" — "बेहतर बात करें" से बेहतर है।',
      );
  String get goalsEmpty => _t('Nothing set yet.', 'अभी कुछ तय नहीं।');
  String get goalDone => _t('Done', 'पूरा हुआ');
  String get goalRemove => _t('Remove', 'हटाएँ');
  String get goalEdit => _t('Edit', 'बदलें');
  String get goalsCompleted => _t('Completed', 'पूरे हुए');

  String get dates => _t('Dates that matter', 'ख़ास तारीख़ें');
  String get dateAdd => _t('Add a date', 'तारीख़ जोड़ें');
  String get dateLabel => _t('What is it?', 'यह क्या है?');
  String get dateLabelHint =>
      _t('Anniversary, their birthday…', 'सालगिरह, उनका जन्मदिन…');
  String get datesEmpty => _t(
        'None yet. Saath will remind you here — on this phone, no account needed.',
        'अभी कोई नहीं। साथ आपको यहीं याद दिलाएगा — इसी फ़ोन पर, बिना किसी अकाउंट के।',
      );
  String daysAway(int days) => switch (days) {
        0 => _t('today', 'आज'),
        1 => _t('tomorrow', 'कल'),
        _ => _t('in $days days', '$days दिन में'),
      };
  String nthYear(int n) => _t('$n years', '$n साल');
  String get remove => _t('Remove', 'हटाएँ');
  String currentStress(String p) =>
      _t('$p’s current stress', '$p का मौजूदा तनाव');
  String smallJoy(String p) => _t('$p’s small joy', '$p की छोटी ख़ुशी');
  String get tapToAdd => _t('Tap to add', 'जोड़ने के लिए टैप करें');
  String askAbout(String p) => _t('Ask $p about', '$p से पूछिए');
  String get dreamTripPrompt =>
      _t('The trip they would take anywhere', 'वो सफ़र जो वो कहीं भी कर लें');
  String get nextDate => _t('Next date', 'अगली डेट');
  String get noDatePlanned => _t(
      'Nothing planned · ask Saath for one that fits you both',
      'कुछ तय नहीं · साथ से पूछिए जो दोनों को जँचे');
  String get sharedGoal => _t('Shared goal', 'साझा लक्ष्य');
  String get noSharedGoal => _t(
      'None set yet. A first one people often pick: one phone-free dinner a week.',
      'अभी कोई तय नहीं। लोग अक्सर यह पहला चुनते हैं: हफ़्ते में एक फ़ोन-मुक्त डिनर।');
  String get openRepairRoom => _t('Open a Repair Room', 'रिपेयर रूम खोलें');
  String get needsPairing => _t(
      'This one needs pairing — the couple-layer build.',
      'इसके लिए पेयरिंग चाहिए — कपल-लेयर बिल्ड में।');

  // ── Learn ─────────────────────────────────────────────────────────────────
  String learnCount(int shown, int total) =>
      _t('Learn · $shown of $total done', 'सीखें · $total में से $shown पूरे');
  String get learnTitle =>
      _t('Small ideas, big fights', 'छोटे विचार, बड़े झगड़े');
  String get twoMinuteExercise => _t('2-minute exercise', '2 मिनट का अभ्यास');
  String get learnShowExercise => _t('Show the exercise', 'अभ्यास दिखाएँ');
  String get learnMarkDone => _t('Done this', 'यह कर लिया');
  String get learnDone => _t('Done', 'हो गया');
  String get learnSaveToJournal => _t('Save to journal', 'डायरी में सहेजें');
  String get learnAllDone => _t(
      'You have worked through every card. They stay here to come back to.',
      'आपने हर कार्ड पूरा कर लिया। ये यहाँ रहेंगे, जब चाहें लौटिए।');

  // ── Journal ───────────────────────────────────────────────────────────────
  String get journal => _t('Journal', 'डायरी');
  String get journalSub => _t(
      'Everything you saved. On this phone, nowhere else.',
      'आपने जो सहेजा। इसी फ़ोन पर, और कहीं नहीं।');
  String get journalEmpty => _t(
      'Nothing saved yet. Untangle something and tap Save.',
      'अभी कुछ सहेजा नहीं। कुछ सुलझाइए और सहेजें दबाइए।');
  String get deleteEntry => _t('Delete this entry', 'यह प्रविष्टि मिटाएँ');
  String get journalReflect =>
      _t('What does this look like now?', 'अब यह कैसा लगता है?');
  String get journalReflecting => _t('Reading it back…', 'दोबारा पढ़ रहा हूँ…');
  String get journalReflection => _t('Looking back', 'पीछे मुड़कर');
  String get journalTags => _t('What was it about?', 'यह किस बारे में था?');
  String get journalTrends => _t('Last 30 days', 'पिछले 30 दिन');
  String get entryDeleted => _t('Deleted', 'मिट गया');
  String get journalWriteNote => _t('Write a note', 'एक नोट लिखें');
  String get journalNoteHint =>
      _t('Something you want to remember…', 'कुछ जो आप याद रखना चाहते हैं…');
  String get journalShowAll => _t('All', 'सब');
  String journalFilterEmpty(String theme) =>
      _t('Nothing tagged $theme yet.', '$theme से जुड़ा अभी कुछ नहीं।');
  String get journalReflectTimeout => _t(
      'That took too long. The model may still be loading — try again in a moment.',
      'बहुत देर लग गई। मॉडल शायद अभी लोड हो रहा है — थोड़ी देर में फिर कोशिश करें।');

  // ── Safety ────────────────────────────────────────────────────────────────
  String get safetyTitle => _t('I want to pause and check on you.',
      'मैं रुककर आपका हाल पूछना चाहता हूँ।');
  String get safetyBody1 => _t(
      'Some of what you described sounds like more than a rough patch. You deserve to be safe, and that comes before fixing anything.',
      'आपने जो बताया, वह मुश्किल दौर से कुछ ज़्यादा लगता है। आपका सुरक्षित रहना ज़रूरी है — किसी भी चीज़ को ठीक करने से पहले।');
  String get safetyBody2 => _t(
      'I am not a counsellor you can call. These people are, and they are free.',
      'मैं ऐसा काउंसलर नहीं जिसे आप फ़ोन कर सकें। ये लोग हैं, और मुफ़्त हैं।');
  String get imOkayKeepTalking =>
      _t('I’m okay, keep talking', 'मैं ठीक हूँ, बात जारी रखें');
  String get hideApp => _t('Hide Saath behind a calculator icon',
      'साथ को कैलकुलेटर आइकॉन के पीछे छिपाएँ');
  String get callLabel => _t('Call', 'कॉल करें');
  String get dialFailed => _t(
      'No dialler on this device. The number is above — dial it by hand.',
      'इस डिवाइस में डायलर नहीं है। नंबर ऊपर है — हाथ से मिलाइए।');
  String get safetyAlwaysHere => _t('Reachable any time from Settings.',
      'सेटिंग्स से कभी भी पहुँचा जा सकता है।');
  String get helplines => _t('Helplines', 'हेल्पलाइन');

  // ── App lock ──────────────────────────────────────────────────────────────
  String get appLock => _t('Lock $appName', '$appNameDevanagari को लॉक करें');
  String get appLockBody => _t(
        'Ask for your face, fingerprint or passcode before opening $appName. Worth turning on if anyone else can pick up your phone.',
        '$appNameDevanagari खोलने से पहले चेहरा, उँगली या पासकोड माँगे। अगर आपका फ़ोन कोई और भी उठा सकता है, तो इसे चालू रखिए।',
      );
  String get appLockOn => _t('On', 'चालू');
  String get appLockOff => _t('Off', 'बंद');
  String get appLockPrompt =>
      _t('Unlock $appName', '$appNameDevanagari को अनलॉक करें');
  String get appLockUnlock => _t('Unlock', 'अनलॉक करें');
  String get appLockLocked =>
      _t('$appName is locked', '$appNameDevanagari लॉक है');
  String get appLockUnavailable => _t(
        'This phone has no screen lock set up, so $appName has nothing to check against.',
        'इस फ़ोन में कोई स्क्रीन लॉक सेट नहीं है, इसलिए $appNameDevanagari के पास जाँचने को कुछ नहीं।',
      );
  String get appLockFailed => _t('That did not match. Try again.',
      'यह मेल नहीं खाया। दोबारा कोशिश कीजिए।');

  // ── Supporting Saath ──────────────────────────────────────────────────────
  String get support => _t('Support Saath', 'साथ का साथ दीजिए');
  String get supportBody => _t(
        'Saath is free and has no ads, because an ad company has no business sitting next to your relationship. If it has been useful and you can spare something, that is what keeps it going. If you cannot, use it anyway — that is the point.',
        'साथ मुफ़्त है और इसमें कोई विज्ञापन नहीं, क्योंकि आपके रिश्ते के पास किसी विज्ञापन कंपनी का कोई काम नहीं। अगर यह काम आया हो और आप कुछ दे सकें, तो उसी से यह चलता रहेगा। न दे सकें, तो भी इस्तेमाल कीजिए — मक़सद यही है।',
      );
  String get supportAction => _t('Chip in', 'योगदान दें');
  String get supportFailed => _t(
        'Could not open that. No harm done.',
        'यह खुल नहीं पाया। कोई बात नहीं।',
      );

  // ── Settings ──────────────────────────────────────────────────────────────
  String get settings => _t('Settings', 'सेटिंग्स');
  String get language => _t('Language', 'भाषा');
  String get theme => _t('Appearance', 'रूप');
  String get themeSystem => _t('System', 'सिस्टम');
  String get themeLight => _t('Light', 'उजला');
  String get themeDark => _t('Dark', 'गहरा');
  String get you => _t('You two', 'आप दोनों');
  String get editOriginStory =>
      _t('Why we started — edit', 'हमने शुरुआत क्यों की — बदलें');
  String get privacy => _t('Privacy', 'निजता');
  String get privacyBody => _t(
      'Everything — the counsellor, your journal, your origin story — stays on this phone. Nothing is sent anywhere unless you pair with a partner, and even then only encrypted.',
      'सब कुछ — काउंसलर, आपकी डायरी, आपकी शुरुआत की कहानी — इसी फ़ोन पर रहता है। कुछ भी कहीं नहीं भेजा जाता, जब तक आप साथी से न जुड़ें — और तब भी सिर्फ़ एन्क्रिप्टेड।');
  String get exportData => _t('Export my data', 'मेरा डेटा निर्यात करें');
  String get exportTitle => _t('Everything Saath knows', 'साथ जो कुछ जानता है');
  String get exportBody => _t(
      'This is the whole file. Copy it somewhere safe — Saath keeps no other copy.',
      'यह पूरी फ़ाइल है। इसे कहीं सुरक्षित कॉपी कर लीजिए — साथ के पास कोई और प्रति नहीं है।');
  String get deleteEverything => _t('Delete everything', 'सब कुछ मिटाएँ');
  String get deleteConfirmTitle => _t('Delete everything?', 'सब कुछ मिटा दें?');
  String get deleteConfirmBody => _t(
      'Your origin story, journal and check-ins are erased from this phone. There is no copy anywhere else, so this cannot be undone.',
      'आपकी शुरुआत की कहानी, डायरी और चेक-इन इस फ़ोन से मिट जाएँगे। कहीं और कोई प्रति नहीं है, इसलिए इसे वापस नहीं लाया जा सकता।');
  String get deleteConfirmAction => _t('Delete everything', 'सब कुछ मिटाएँ');
  String get everythingDeleted => _t('Everything deleted', 'सब कुछ मिट गया');
  String get counsellorModel => _t('Counsellor model', 'काउंसलर मॉडल');
  String get modelPreviewBody => _t(
      'Preview engine — scripted replies, no AI model on the device yet. Gemma 3n runs here once the on-device spike lands, and nothing about that changes what leaves the phone: still nothing.',
      'प्रीव्यू इंजन — लिखे हुए जवाब, अभी डिवाइस पर कोई AI मॉडल नहीं। ऑन-डिवाइस काम पूरा होते ही Gemma 3n यहाँ चलेगा — और तब भी फ़ोन से कुछ बाहर नहीं जाएगा।');
  String get about => _t('About', 'बारे में');
  String get notTherapist => _t(
      'Saath is not a licensed therapist and does not diagnose. In an emergency, call 112.',
      'साथ लाइसेंस-प्राप्त थेरेपिस्ट नहीं है और न ही कोई निदान करता है। आपात स्थिति में 112 पर कॉल करें।');
  String versionLine(String version) =>
      _t('$appName $version', '$appNameDevanagari $version');
  String get licences => _t('Licences', 'लाइसेंस');
  String helplinesVerified(String date) =>
      _t('Helplines verified $date', 'हेल्पलाइन $date को जाँची गईं');

  // ── Errors ────────────────────────────────────────────────────────────────
  String get routeNotFound =>
      _t('That page does not exist.', 'यह पेज मौजूद नहीं है।');
  String get goHome => _t('Go to Today', 'आज पर जाएँ');
  String get somethingBroke => _t(
      'Something broke on this screen. Nothing was lost.',
      'इस स्क्रीन में कुछ गड़बड़ हुई। कुछ खोया नहीं।');
}

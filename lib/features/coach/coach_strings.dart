import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import 'coach_engine.dart';
import 'tracker.dart';

/// Vyuhbhed's copy, EN/HI. Common labels come from the shared `S` table.
class T {
  const T._(this._lang);
  final AppLanguage _lang;

  static T of(BuildContext context, WidgetRef ref) =>
      T._(ref.watch(appStateProvider.select((s) => s.language)));
  static T readWidget(WidgetRef ref) =>
      T._(ref.read(appStateProvider).language);
  @visibleForTesting
  static T forLanguage(AppLanguage l) => T._(l);

  bool get isHindi => _lang == AppLanguage.hi;
  String _t(String en, String hi) => _lang == AppLanguage.hi ? hi : en;

  // ── Identity ──────────────────────────────────────────────────────────────
  String get appName => 'Vyuhbhed';
  String get appNameDevanagari => 'व्यूहभेद';
  String get tagline => _t('Your notice period, run like a campaign.',
      'आपका नोटिस पीरियड — एक अभियान की तरह।');
  String get taglineSub => _t(
      'One plan for every day, mock interviews that score you, a resume that gets read, and a coach for the bad afternoons. On your phone.',
      'हर दिन की एक योजना, स्कोर देने वाले मॉक इंटरव्यू, पढ़ा जाने वाला रिज़्यूमे, और बुरे दिनों के लिए एक कोच। आपके फ़ोन पर।');
  String get introPlanTitle => _t('Every morning: one screen, four things.',
      'हर सुबह: एक स्क्रीन, चार काम।');
  String get introPlanBody => _t(
      'Check in, hit your application count, do one mock, learn one thing. The app tells you which one is next. That is the whole method.',
      'चेक-इन, आवेदन का लक्ष्य, एक मॉक, एक नई बात। ऐप बताता है अगला क्या है। बस यही तरीक़ा है।');
  String get introPrivateTitle => _t(
      'Offline by default. Online if you choose.',
      'डिफ़ॉल्ट ऑफ़लाइन। चाहें तो ऑनलाइन।');
  String get introPrivateBody => _t(
      'The coach runs on the phone from a model you download once. Paste your own Gemini key in Settings for sharper answers — then, and only then, your text leaves the device.',
      'कोच फ़ोन पर चलता है, एक बार डाउनलोड किए मॉडल से। तेज़ जवाबों के लिए सेटिंग्स में अपनी Gemini key डालें — तब, और सिर्फ़ तब, आपका टेक्स्ट फ़ोन से बाहर जाता है।');

  // ── Profile onboarding ────────────────────────────────────────────────────
  String get profileTitle => _t('What are we going after?', 'निशाना क्या है?');
  String get yourName => _t('Your name', 'आपका नाम');
  String get currentRole => _t('Current role', 'अभी की भूमिका');
  String get targetRole => _t('Target role', 'लक्ष्य भूमिका');
  String get targetRoleHint =>
      _t('e.g. Senior Flutter Developer', 'जैसे Senior Flutter Developer');
  String get years => _t('Years of experience', 'अनुभव (वर्ष)');
  String get location => _t('City / remote', 'शहर / रिमोट');
  String get skills => _t('Skills, comma-separated', 'कौशल, कॉमा से अलग');
  String get noticeEnd => _t('Last working day', 'आख़िरी कार्यदिवस');
  String get noticeEndPick => _t('Pick a date', 'तारीख़ चुनें');
  String get targetOffers => _t('Offers you want in hand', 'कितने ऑफ़र चाहिए');
  String get applicationsPerDay =>
      _t('Applications per day', 'रोज़ कितने आवेदन');
  String get startCampaign => _t('Start the campaign', 'अभियान शुरू करें');

  // ── Today ─────────────────────────────────────────────────────────────────
  String get tabToday => _t('Today', 'आज');
  String get tabTrack => _t('Track', 'ट्रैक');
  String get tabPractice => _t('Practice', 'अभ्यास');
  String get tabCoach => _t('Coach', 'कोच');
  String greeting(String name) => _t('Today, $name.', 'आज, $name।');
  String get friend => _t('friend', 'दोस्त');
  String daysLeft(int n) => n < 0
      ? _t('Notice period over', 'नोटिस पीरियड पूरा')
      : n == 0
          ? _t('Last working day', 'आख़िरी कार्यदिवस')
          : _t('$n days left', '$n दिन बाक़ी');
  String offers(int have, int want) =>
      _t('$have of $want offers', '$want में से $have ऑफ़र');
  String stepsDone(int done, int total) =>
      _t('$done of $total done', '$total में से $done पूरे');
  String get rightNow => _t('Right now', 'अभी');
  String nextCheckIn() => _t('Thirty seconds: how is your energy today?',
      'तीस सेकंड: आज ऊर्जा कैसी है?');
  String nextApply(int left) => _t(
      'Send $left more application${left == 1 ? '' : 's'}. Open Jobs, pick one, apply, log it.',
      '$left और आवेदन भेजिए। Jobs खोलिए, एक चुनिए, आवेदन कीजिए, लॉग कीजिए।');
  String get nextMock => _t('One mock interview. Fifteen minutes, scored.',
      'एक मॉक इंटरव्यू। पंद्रह मिनट, स्कोर के साथ।');
  String get nextLearn => _t(
      'Learn one thing for the target role, then tick it here.',
      'लक्ष्य भूमिका के लिए एक चीज़ सीखिए, फिर यहाँ टिक कीजिए।');
  String get nextRest => _t(
      'Done for today. Close the app. Tomorrow is another four.',
      'आज का काम पूरा। ऐप बंद कीजिए। कल फिर चार।');
  String get doIt => _t('Do it', 'करते हैं');
  String get checkInLabel => _t('Energy check-in', 'ऊर्जा चेक-इन');
  String get checkInQ =>
      _t('How much fight do you have in you today?', 'आज कितना दम है?');
  String get low => _t('Running on empty', 'बिलकुल ख़ाली');
  String get high => _t('Ready', 'तैयार');
  String get oneWord => _t('One word for today', 'आज के लिए एक शब्द');
  String get savedForToday => _t('Saved for today.', 'आज के लिए सहेजा गया।');
  String applicationsToday(int done, int target) =>
      _t('Applications · $done of $target', 'आवेदन · $target में से $done');
  String get mockToday => _t('Mock interview', 'मॉक इंटरव्यू');
  String get learnToday => _t('Learned one thing', 'एक नई बात सीखी');
  String get markLearned => _t('Mark learned', 'सीख लिया');
  String pipeline(int n) => _t('$n in the pipeline', '$n पाइपलाइन में');
  String get openJobs => _t('Find jobs', 'नौकरियाँ खोजें');
  String get openResume => _t('Fix my resume', 'रिज़्यूमे सुधारें');
  String get openJournal => _t('Journal', 'डायरी');
  String get firstDay => _t(
      'Day one. Do the check-in, then send today’s applications. The count on this screen is the only score that matters this month.',
      'पहला दिन। चेक-इन कीजिए, फिर आज के आवेदन भेजिए। इस स्क्रीन की गिनती ही इस महीने का असली स्कोर है।');

  // ── Track ─────────────────────────────────────────────────────────────────
  String get trackTitle => _t('Applications', 'आवेदन');
  String get addApplication => _t('Log an application', 'आवेदन लॉग करें');
  String get company => _t('Company', 'कंपनी');
  String get role => _t('Role', 'भूमिका');
  String get link => _t('Link (optional)', 'लिंक (वैकल्पिक)');
  String stage(AppStage s) => switch (s) {
        AppStage.saved => _t('Saved', 'सहेजा'),
        AppStage.applied => _t('Applied', 'आवेदन किया'),
        AppStage.screening => _t('Screening', 'स्क्रीनिंग'),
        AppStage.interview => _t('Interview', 'इंटरव्यू'),
        AppStage.offer => _t('Offer', 'ऑफ़र'),
        AppStage.rejected => _t('Rejected', 'अस्वीकृत'),
      };
  String get trackEmpty => _t(
      'Nothing logged yet. Every application you send goes here — it is how the plan knows you did it.',
      'अभी कुछ लॉग नहीं। हर भेजा आवेदन यहाँ आता है — योजना को इसी से पता चलता है।');
  String get moveTo => _t('Move to', 'यहाँ ले जाएँ');
  String get removeApplication => _t('Remove', 'हटाएँ');
  String get removed => _t('Removed', 'हटा दिया');
  String get undo => _t('Undo', 'वापस लाएँ');
  String get openLink => _t('Open posting', 'पोस्टिंग खोलें');
  String get notes => _t('Notes', 'नोट्स');
  String get funnel => _t('Funnel', 'फ़नल');

  // ── Jobs ──────────────────────────────────────────────────────────────────
  String get jobsTitle => _t('Find jobs', 'नौकरियाँ खोजें');
  String get jobsBody => _t(
      'One search, every board. Each button opens the site with your role and city already typed in. Apply there, then log it in Track.',
      'एक खोज, हर बोर्ड। हर बटन साइट को आपकी भूमिका और शहर के साथ खोलता है। वहाँ आवेदन कीजिए, फिर Track में लॉग कीजिए।');
  String get searchRole => _t('Role', 'भूमिका');
  String get searchCity => _t('City', 'शहर');
  String get remoteOnly => _t('Remote', 'रिमोट');
  String get couldNotOpen =>
      _t('Could not open that site.', 'वह साइट नहीं खुल सकी।');

  // ── Practice ──────────────────────────────────────────────────────────────
  String get practiceTitle => _t('Mock interview', 'मॉक इंटरव्यू');
  String get practiceBody => _t(
      'Six questions for your target role. Type your answer; get a score and a stronger version of what you said.',
      'आपकी लक्ष्य भूमिका के लिए छह सवाल। जवाब लिखिए; स्कोर पाइए और अपने जवाब का बेहतर रूप।');
  String round(InterviewRound r) => switch (r) {
        InterviewRound.hr => _t('HR round', 'HR राउंड'),
        InterviewRound.technical => _t('Technical', 'तकनीकी'),
        InterviewRound.managerial => _t('Managerial', 'मैनेजरियल'),
        InterviewRound.behavioural => _t('Behavioural', 'व्यवहार'),
      };
  String get startMock => _t('Start', 'शुरू करें');
  String get preparing =>
      _t('Writing your questions…', 'आपके सवाल बन रहे हैं…');
  String questionOf(int i, int n) => _t('Question $i of $n', 'सवाल $i / $n');
  String get answerHint => _t('Say it the way you would in the room…',
      'वैसे ही कहिए जैसे कमरे में कहते…');
  String get scoreIt => _t('Score my answer', 'मेरा जवाब जाँचो');
  String get scoring => _t('Scoring…', 'जाँच रहा हूँ…');
  String get structure => _t('Structure', 'ढाँचा');
  String get specificity => _t('Specificity', 'ठोसपन');
  String get feedback => _t('Feedback', 'प्रतिक्रिया');
  String get strongerAnswer => _t('A stronger version', 'एक बेहतर रूप');
  String get lookingFor =>
      _t('What they want to hear', 'वे क्या सुनना चाहते हैं');
  String get nextQuestion => _t('Next question', 'अगला सवाल');
  String get finishMock => _t('Finish', 'समाप्त');
  String mockDone(String avg) => _t('Average $avg / 10. Logged for today.',
      'औसत $avg / 10। आज के लिए लॉग हुआ।');
  String get logExternal =>
      _t('Log an interview I did elsewhere', 'बाहर दिया इंटरव्यू लॉग करें');
  String get externalCompany => _t('Company (optional)', 'कंपनी (वैकल्पिक)');
  String get externalNotes =>
      _t('How did it go? What came up?', 'कैसा रहा? क्या पूछा गया?');
  String get history => _t('History', 'इतिहास');
  String get inApp => _t('In-app', 'ऐप में');
  String get external => _t('Real / external', 'असली / बाहरी');
  String get skipQuestion => _t('Skip', 'छोड़ें');

  // ── Resume ────────────────────────────────────────────────────────────────
  String get resumeTitle => _t('Resume review', 'रिज़्यूमे समीक्षा');
  String get resumeHint => _t(
      'Paste your resume text here…', 'अपना रिज़्यूमे टेक्स्ट यहाँ चिपकाएँ…');
  String get jdHint => _t('Paste the job description (optional)…',
      'नौकरी का विवरण चिपकाएँ (वैकल्पिक)…');
  String get reviewResume => _t('Review it', 'समीक्षा करो');
  String get reviewing =>
      _t('Reading it like a recruiter…', 'रिक्रूटर की तरह पढ़ रहा हूँ…');
  String get verdict => _t('Verdict', 'फ़ैसला');
  String get fixes => _t('Fix these first', 'पहले ये सुधारें');
  String get rewritten =>
      _t('Your bullets, rewritten', 'आपके बुलेट, दोबारा लिखे');
  String get missingKeywords => _t('Keywords the posting has and you don’t',
      'पोस्टिंग के कीवर्ड जो आपके पास नहीं');
  String get resumeTooShort => _t(
      'Paste the full resume — a few lines is not enough to judge.',
      'पूरा रिज़्यूमे चिपकाइए — कुछ पंक्तियाँ काफ़ी नहीं।');

  // ── Coach ─────────────────────────────────────────────────────────────────
  String get coachTitle => _t('Coach', 'कोच');
  String get coachHint =>
      _t('What is in the way right now?', 'अभी क्या रोक रहा है?');
  String get ask => _t('Ask', 'पूछें');
  String get thinking => _t('Thinking…', 'सोच रहा हूँ…');
  String get promptRejected => _t('Got rejected today', 'आज रिजेक्ट हुआ');
  String get promptSalary =>
      _t('How do I negotiate salary?', 'सैलरी कैसे नेगोशिएट करूँ?');
  String get promptBuyout =>
      _t('Notice period buyout?', 'नोटिस पीरियड बायआउट?');
  String get promptCounter => _t('Got a counter-offer', 'काउंटर-ऑफ़र मिला');
  String get promptStuck => _t('No calls for a week', 'हफ़्ते से कोई कॉल नहीं');
  String get promptPanic => _t('I am panicking', 'मुझे घबराहट हो रही है');
  String get coachFailed => _t(
      'The coach could not answer. If you are offline, download the model in Settings; if you pasted a key, check it.',
      'कोच जवाब नहीं दे सका। ऑफ़लाइन हैं तो सेटिंग्स में मॉडल डाउनलोड करें; key डाली है तो जाँचें।');

  // ── Journal ───────────────────────────────────────────────────────────────
  String get journalTitle => _t('Journal', 'डायरी');
  String get journalBody => _t(
      'Rejections, wins, things you noticed about yourself. Private.',
      'रिजेक्शन, जीत, अपने बारे में जो नोटिस किया। निजी।');
  String get writeEntry => _t('Write', 'लिखें');
  String get journalEmpty => _t('Nothing here yet.', 'अभी यहाँ कुछ नहीं।');
  String get deleteEntry => _t('Delete', 'मिटाएँ');

  // ── Settings ──────────────────────────────────────────────────────────────
  String get profile => _t('Profile & goal', 'प्रोफ़ाइल और लक्ष्य');
  String get editProfile => _t('Edit profile', 'प्रोफ़ाइल बदलें');
  String get engine => _t('Coach engine', 'कोच इंजन');
  String engineKind(EngineKind k) => switch (k) {
        EngineKind.preview =>
          _t('Sample replies — no model yet', 'नमूना जवाब — अभी मॉडल नहीं'),
        EngineKind.onDevice => _t('On-device model — offline, private',
            'ऑन-डिवाइस मॉडल — ऑफ़लाइन, निजी'),
        EngineKind.online => _t(
            'Online (Gemini, your key) — text leaves the phone',
            'ऑनलाइन (Gemini, आपकी key) — टेक्स्ट फ़ोन से बाहर जाता है'),
      };

  /// Two or three words, for the pill beside the screen title. [engineKind]
  /// is the full sentence for Settings; a whole sentence in a pill overflows
  /// the header row.
  String engineBadge(EngineKind k) => switch (k) {
        EngineKind.preview => _t('Sample', 'नमूना'),
        EngineKind.onDevice => _t('On this phone', 'इसी फ़ोन पर'),
        // A brand name, not copy — never routed through _t.
        EngineKind.online => 'Gemini',
      };
  String get apiKey =>
      _t('Gemini API key (optional)', 'Gemini API key (वैकल्पिक)');
  String get apiKeyBody => _t(
      'Free from aistudio.google.com. With a key, answers come from Gemini online and what you type is sent to Google. Leave it empty to stay fully offline.',
      'aistudio.google.com से मुफ़्त। key के साथ जवाब Gemini से ऑनलाइन आते हैं और आपका टेक्स्ट Google को जाता है। पूरी तरह ऑफ़लाइन रहने के लिए खाली छोड़ें।');
  String get apiKeySaved =>
      _t('Key saved on this phone.', 'key इस फ़ोन पर सहेजी गई।');
  String get apiKeyRemoved =>
      _t('Key removed. Offline only.', 'key हटाई। सिर्फ़ ऑफ़लाइन।');
  String get reminders => _t('Reminders', 'रिमाइंडर');
  String get remindersBody => _t(
      'Set a morning plan time and an evening review time. Phone notifications arrive in the next update; until then the app shows the plan whenever you open it.',
      'सुबह की योजना और शाम की समीक्षा का समय तय करें। फ़ोन नोटिफ़िकेशन अगले अपडेट में आएँगे; तब तक ऐप खोलते ही योजना दिखती है।');
  String get morningTime => _t('Morning plan', 'सुबह की योजना');
  String get eveningTime => _t('Evening review', 'शाम की समीक्षा');
  String get privacyBody => _t(
      'Applications, mocks, journal and profile stay on this phone. Nothing is sent anywhere unless you add a Gemini key.',
      'आवेदन, मॉक, डायरी और प्रोफ़ाइल इसी फ़ोन पर रहते हैं। Gemini key न डालें तो कुछ भी कहीं नहीं जाता।');
  String get deleteBody => _t(
      'Everything logged in this app will be removed from this phone. There is no copy anywhere else.',
      'इस ऐप में लॉग किया सब इस फ़ोन से मिट जाएगा। कहीं और कोई प्रति नहीं।');
  String get disclaimer => _t(
      'Vyuhbhed is a planning and practice tool. It does not guarantee interviews or offers, and its advice can be wrong — check anything that matters against a real person.',
      'व्यूहभेद योजना और अभ्यास का औज़ार है। यह इंटरव्यू या ऑफ़र की गारंटी नहीं देता, और इसकी सलाह ग़लत हो सकती है — ज़रूरी बातें किसी असली व्यक्ति से जाँचें।');
}

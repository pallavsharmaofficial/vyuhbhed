# Vyuhbhed (व्यूहभेद)

**Your notice period, run like a campaign.**

A job-hunt coach that runs on your phone. One plan every morning, mock
interviews that score you, a resume review, and a coach for the bad
afternoons. Offline by default — a model you download once, and nothing you
type leaves the device unless you choose to add your own API key.

Flutter · Android 10+ · iOS 16+ · English and Hindi throughout.

> **Where this is:** the daily plan, tracker, mock interviews, resume review,
> job search, journal and Learn deck all work. The coach answers from a
> scripted sample engine until a model is downloaded; Settings says so plainly
> rather than pretending otherwise.

## Try it

- **Web preview** — the real app, with sample coach replies. A browser is the
  wrong place for a model download that size.
- **Android APK** — on the Releases page.

## Run it

```bash
flutter pub get
flutter run          # a simulator, or an arm64 Android emulator
```

Both platform folders are checked in. There is no `flutter create` step.

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos --fatal-warnings   # must be clean
flutter test                                     # 212 tests
```

## The method the app is built around

Four things a day, in order, and the app tells you which one is next:

1. **Check in** — thirty seconds on your energy. A low day gets a different
   plan, not a guilt trip.
2. **Applications** — hit the count you set. The counter on the Today screen is
   the only score that matters.
3. **One mock interview** — HR, technical or managerial. Typed answers, scored
   on structure and specificity, with a stronger version of what you said.
4. **Learn one thing** — for the role you are actually targeting.

## Layout

```
lib/
  app/        router, tab shell, lock gate, web frame
  theme/      tokens, typography, ThemeData
  ui/         Atmosphere, Frost/glass components
  core/       app state, journal, app lock, key-value store, strings
  features/
    coach/    Today, Track, Practice, Jobs, Resume, the coach, profile
    learn/    the card deck
    safety/   crisis interrupt and helplines
docs/         RELEASE.md, ACCESSIBILITY.md
test/         212 tests; test/support/harness.dart boots the real app
```

## The engine

`features/coach/coach_engine.dart` defines the interface. Three
implementations sit behind it and the UI knows about none of them:

- **On-device** — a quantised model via LiteRT-LM. Downloaded once, on your
  say-so, over Wi-Fi. No server, no API bill, nothing leaving the phone.
- **Online** — your own Gemini key, pasted in Settings. Sharper answers, and
  the only mode where your text goes anywhere. The app says so at the moment
  you enable it, not in a policy nobody reads.
- **Sample** — scripted replies, used when neither of the above is available,
  and labelled as such everywhere it appears.

## Strings

Every user-visible string lives in `lib/features/coach/coach_strings.dart` (the
coach) or `lib/core/strings.dart` (the shared shell). A literal in a widget is
a string that ships in English to a Hindi user. A test reads the tables as
source and fails on any pair that is empty, identical, or missing Devanagari.

## Not a recruiter

Vyuhbhed is a planning and practice tool. It does not guarantee interviews or
offers, and its advice can be wrong — check anything that matters against a
real person. The crisis interrupt and helplines exist because a job hunt is a
hard time and the app should know that.

## Releasing

See [docs/RELEASE.md](docs/RELEASE.md).

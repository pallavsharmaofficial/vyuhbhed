# Saath (साथ)

An AI relationship counsellor that runs entirely on the phone. Free, private,
offline. Flutter, iOS 16+ and Android 10+.

> **What this build is:** everything that works on one phone, including the
> on-device Gemma counsellor. What is missing is the couple layer — pairing,
> encryption and sync — and a host to serve the model files from.

## Run it

```bash
flutter pub get
flutter run          # pick a simulator or an arm64 Android emulator
```

Both platform folders are checked in. There is no `flutter create` step.

```bash
flutter analyze --fatal-infos --fatal-warnings   # must be clean
flutter test                                     # 242 tests
```

## Layout

```
lib/
  app/        router (one stable GoRouter), tab shell, lock gate, web frame
  theme/      tokens (palette, SurfaceTokens, StageTokens), typography, ThemeData
  ui/         Atmosphere (photo + veil + fades), Frost/glass, text prompt
  core/       app state, journal, couple space, app lock, key-value store,
              strings (EN/HI), helplines
  features/   onboarding, home, counsellor (+ model, voice), untangle, repair,
              couple, journal, pulse, learn, safety, settings
assets/
  backgrounds/  placeholder colour fields — swap for real photos, same filenames
  fonts/        Sora, Source Serif 4, Noto Serif Devanagari (subset, variable)
docs/         RELEASE.md, ACCESSIBILITY.md
test/         unit + widget tests; test/support/harness.dart boots the real app
```

## The resolution arc

Every screen is wrapped in `StageTheme(stage: …)`. Three stages move accent,
radius and blur together:

| stage   | accent | radius | blur | used on |
|---------|--------|--------|------|---------|
| aware   | rose   | 12     | 14   | welcome, counsellor chat |
| working | plum   | 18     | 18   | today, names, untangle, repair room |
| calm    | sage   | 26     | 24   | origin story, cool-down, repair close, us, journal, learn, settings |

## Typography

The three faces are **bundled**, not fetched. `google_fonts` downloads from
`fonts.gstatic.com` on first run, which breaks the offline promise the welcome
screen makes and is the one network call an otherwise on-device app would have.

All three are variable fonts. Flutter does not map `fontWeight` onto a `wght`
axis by itself, so build styles with `AppFonts.sora` / `AppFonts.sourceSerif`
and change weight with `AppFonts.at` — a bare `copyWith(fontWeight: …)` silently
does nothing. Noto Serif Devanagari is attached as a fallback on every style, so
Hindi resolves even inside an English paragraph.

## AI engine

`features/counsellor/engine.dart` defines `CounsellorEngine`. Two
implementations sit behind it and the UI knows about neither:

- `GemmaCounsellorEngine` — flutter_gemma on LiteRT-LM, used whenever a model
  is installed. The chat session is kept alive and fed only new messages;
  rebuilding it per turn re-prefills the whole conversation, which on a 4 GB
  phone is the difference between a two-second wait and fifteen.
- `MockCounsellorEngine` — scripted, in both languages, used when no model is
  loadable. Onboarding, Learn and the helplines all have to work before a
  3.7 GB download finishes, and on a phone where it never will.

Prompts live in one file, `model/prompts.dart`, meant to be readable end to end
as writing rather than as code. Untangle, the Repair merge, Say it kinder and
the weekly reflection are all JSON-constrained: structure is both more
trustworthy and far easier for a 1B model than open advice.

**The model files need a host.** Both upstream Hugging Face repos are gated.
Point the build at your own mirror:

```bash
flutter build appbundle --release --target-platform android-arm64 \
  --dart-define=SAATH_MODEL_BASE_URL=https://models.example.in
```

Without it the download button is disabled and the screen says why.

The safety guardrail (`features/counsellor/safety.dart`) is deliberately *not*
part of the model. It runs on every text the user writes — chat, Untangle
vents, both Repair Room sides, a message being rewritten — before any
generation, and the model gets no vote.

## Strings

Every user-visible string lives in `lib/core/strings.dart`. A literal in a
widget is a string that will ship in English to a Hindi user, which is what half
this app used to do. `test/strings_test.dart` reads the table as source and
fails if any `_t()` pair is empty, identical, or missing Devanagari.

## Dev shortcuts

- `flutter run --route=/safety` (or `/learn`, `/settings`, `/journal`,
  `/week`, `/settings/model`) opens straight onto a screen. go_router honours
  the platform's initial route.
- Settings → *Delete everything* resets to onboarding (with a confirmation).
- Repair Room's merged view has a "Skip to closing" link **in debug builds
  only**.
- Type "afraid of him" in the counsellor to see the safety interrupt.

## Web

`flutter build web --release` works, and the app frames itself to phone width
in a desktop browser. The web build deliberately has **no model** — a browser
is the wrong place for a 3.7 GB download — so the counsellor there runs the
scripted preview, and a banner says so on every screen. A relationship app that
took a real problem and answered with a canned line without saying so would be
a lie told to someone at a bad moment.

`.github/workflows/web.yml` deploys it to GitHub Pages for free on every push.

## Releasing

See [docs/RELEASE.md](docs/RELEASE.md).

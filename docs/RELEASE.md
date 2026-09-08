# Releasing Saath

Everything here is reproducible from a clean checkout. Nothing in this file
assumes a machine that has built the app before.

## Identity

| | |
|---|---|
| iOS bundle ID | `in.saathhamesha.app` |
| Android application ID | `in.saathhamesha.app` |
| Store name | Saath |
| Minimum iOS | 16.0 |
| Minimum Android | API 29 (Android 10) |
| Orientation | Portrait only, both platforms |

The version lives in exactly two places and a test enforces that they agree:
`pubspec.yaml` (`version: x.y.z+n`) and `lib/core/app_info.dart`. Bump both, or
`test/app_info_test.dart` fails.

## Before every release

```bash
flutter pub get
flutter analyze          # must be clean, not "only infos"
flutter test             # 171 tests
```

Then re-verify the helpline numbers against the operators' own published pages
and bump `Helplines.verifiedOn` in `lib/core/helplines.dart`. Settings → About
shows that date to the user, so a stale value is visible in the product.

## Android

Release signing reads `android/key.properties`, which is **not** in version
control. Create it on the release machine:

```properties
storePassword=…
keyPassword=…
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

Without that file the release build falls back to the debug keystore so
`flutter run --release` still works locally — it just cannot be uploaded.

```bash
flutter build appbundle --release --target-platform android-arm64
# → build/app/outputs/bundle/release/app-release.aab
```

**The `--target-platform` flag is not optional.** `flutter_gemma` ships
LiteRT-LM native libraries for `arm64-v8a` only. Without the flag the bundle
also carries `armeabi-v7a` and `x86_64` splits that install cleanly and then
cannot load a model — an app whose headline feature can never work on the
device that downloaded it. Setting `ndk.abiFilters` in `build.gradle.kts` does
**not** work: the Flutter Gradle plugin overwrites it from this flag.

R8 (`isMinifyEnabled`) and resource shrinking are on. Rules live in
`android/app/proguard-rules.pro`.

### Size, measured

| | |
|---|---|
| AAB, arm64 only | 86.9 MB |
| Native libraries, arm64 | 124.2 MB uncompressed |
| — of which `libLiteRtLm.so` | 25.9 MB |
| — of which Qualcomm QNN HTP skels | ~40 MB across four chip generations |
| Gemma 3 1B model | 584 MB |
| Gemma 3n E2B model | 3.7 GB |

So the smallest realistic path to a working counsellor is roughly **670 MB**:
an ~85 MB install, then a 584 MB download. That is a real barrier in the
market this is aimed at, and it is worth a decision rather than a shrug.

That lever now exists and is measured. `-PsaathExcludeQnn=true` drops the
Qualcomm NPU delegate libraries:

| Build | APK |
|---|---|
| Default | 134 MB |
| `-PsaathExcludeQnn=true` | 77 MB |

57 MB, at the cost of NPU acceleration on Snapdragon — which is most of this
market. It is off by default because a counsellor that answers slowly is a
worse product than a larger download. Measure tokens/sec on the week-1 spike
devices before making it permanent either way.


## iOS

```bash
flutter build ipa --release
```

Signing is configured in Xcode against the team that owns
`in.saathhamesha.app`. `ios/Runner/PrivacyInfo.xcprivacy` is registered in the
Runner target's Resources phase — confirm it is present in the built
`Runner.app` before uploading, because App Store Connect rejects the archive
silently late if it is missing.

## Store answers already decided in code

- **Encryption** — `ITSAppUsesNonExemptEncryption = false` in `Info.plist`.
  True today: the app makes no network calls at all. This changes the day
  pairing ships.
- **Data Safety / Privacy Nutrition Label** — no data collected, no data
  shared, no tracking. `PrivacyInfo.xcprivacy` declares one required-reason
  API: `UserDefaults` (CA92.1), used by `shared_preferences`.
- **Backups** — Android cloud backup and device transfer are both disabled
  (`android/app/src/main/res/xml/data_extraction_rules.xml`). The journal and
  origin story are meant to exist on one phone.
- **Age rating** — 17+ on iOS / Mature on Play, for the relationship and
  self-harm subject matter.
- **Not medical advice** — Settings → About carries the "not a licensed
  therapist" line, and the store listing must repeat it.

## Still open before a public launch

The counsellor needs a host to download model files from — see
`ModelHosting` in `lib/features/counsellor/model/model_catalogue.dart`. Without
one the app runs its scripted preview engine and says so in Settings. Pairing
and encrypted couple sync are not built.

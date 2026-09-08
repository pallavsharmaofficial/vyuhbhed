#!/usr/bin/env bash
# Checks that a built APK can actually launch.
#
#   ./tool/verify-apk.sh build/app/outputs/flutter-apk/app-release.apk
#
# WHY THIS EXISTS
# ---------------
# v0.2.0 shipped an APK that crashed on every Android device, and nothing in
# the build caught it. MainActivity.kt had been moved into the new package
# directory during the fork from Saath, but its `package` declaration still
# read `in.saathhamesha.app`. Kotlin permits that mismatch. The manifest asked
# for `<applicationId>.MainActivity`, R8 saw the real class as unreferenced and
# stripped it, and the result was an app with no launch activity at all —
# ClassNotFoundException before a single frame.
#
# Everything was green: analyze clean, 212 tests passing, CI passing, the APK
# signed and installable. None of it looks inside the dex. This does.

set -euo pipefail

APK="${1:-build/app/outputs/flutter-apk/app-release.apk}"
[[ -f "$APK" ]] || { echo "no such apk: $APK"; exit 1; }

SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
AAPT=$(ls "$SDK"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -1)
[[ -x "${AAPT:-}" ]] || { echo "aapt2 not found under $SDK/build-tools"; exit 1; }

ACTIVITY=$("$AAPT" dump badging "$APK" | sed -n "s/^launchable-activity: name='\([^']*\)'.*/\1/p" | head -1)
[[ -n "$ACTIVITY" ]] || { echo "FAIL: the manifest declares no launchable activity"; exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
unzip -o -q "$APK" 'classes*.dex' -d "$TMP"

# Dalvik type descriptor: in.foo.Bar -> Lin/foo/Bar;
DESC="L$(echo "$ACTIVITY" | tr '.' '/');"

# NOTE: not `grep -q`. It exits on the first match, which SIGPIPEs `strings`,
# and `set -o pipefail` then reports the whole pipeline as a failure — a false
# negative that made this guard fail on a perfectly good APK.
FOUND=$(strings "$TMP"/*.dex | grep -cF "$DESC" || true)

if [[ "$FOUND" -gt 0 ]]; then
  echo "OK  launch activity present: $ACTIVITY"
else
  echo "FAIL  the manifest points at $ACTIVITY"
  echo "      but no such class is in the dex — this APK crashes on launch."
  echo "      Check the 'package' line in MainActivity.kt matches the"
  echo "      namespace in android/app/build.gradle.kts."
  exit 1
fi

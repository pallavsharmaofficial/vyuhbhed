#!/usr/bin/env bash
# Creates the upload keystore that signs every Android release of Vyuhbhed.
#
# Costs nothing. Takes a minute. Run it once, ever.
#
#   ./tool/make-keystore.sh
#
# WHAT YOU MUST NOT LOSE
# ----------------------
# Google Play ties an app to this key. Lose it and you cannot ship an update
# to your own users — they would have to uninstall and reinstall a different
# listing. Back up BOTH files produced here, somewhere that is not this laptop:
#
#   ~/.vyuhbhed/upload-keystore.jks   the key itself
#   android/key.properties         the passwords, git-ignored
#
# (Play App Signing gives you a recovery path, but only if you enrol before
# you need it. Enrol.)

set -euo pipefail

KEYSTORE_DIR="${HOME}/.vyuhbhed"
KEYSTORE="${KEYSTORE_DIR}/upload-keystore.jks"
PROPS="$(cd "$(dirname "$0")/.." && pwd)/android/key.properties"

if [[ -f "$KEYSTORE" ]]; then
  echo "A keystore already exists at:"
  echo "  $KEYSTORE"
  echo
  echo "Refusing to overwrite it. If you replace this key you can no longer"
  echo "update the app for anyone who already installed it."
  exit 1
fi

command -v keytool >/dev/null 2>&1 || {
  echo "keytool not found. It ships with the JDK — install one, or use the JDK"
  echo "bundled with Android Studio, then run this again."
  exit 1
}

mkdir -p "$KEYSTORE_DIR"
chmod 700 "$KEYSTORE_DIR"

echo "Creating an upload key for Vyuhbhed."
echo "Pick a password you can find again in two years. Write it down."
echo
read -r -s -p "Keystore password: " PASS; echo
read -r -s -p "Confirm: " PASS2; echo
[[ "$PASS" == "$PASS2" ]] || { echo "Those did not match."; exit 1; }
[[ ${#PASS} -ge 6 ]] || { echo "keytool needs at least 6 characters."; exit 1; }

keytool -genkeypair \
  -alias upload \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000 \
  -keystore "$KEYSTORE" \
  -storetype JKS \
  -storepass "$PASS" \
  -keypass "$PASS" \
  -dname "CN=Vyuhbhed, OU=Vyuhbhed, O=Vyuhbhed, L=, ST=, C=IN"

chmod 600 "$KEYSTORE"

umask 077
cat > "$PROPS" <<PROPSEOF
storePassword=${PASS}
keyPassword=${PASS}
keyAlias=upload
storeFile=${KEYSTORE}
PROPSEOF

echo
echo "Done."
echo "  key      $KEYSTORE"
echo "  passwords $PROPS   (git-ignored — check that it stays that way)"
echo
echo "Build a signed release:"
echo "  flutter build apk --release --target-platform android-arm64"
echo
echo "Back both files up now, not later."

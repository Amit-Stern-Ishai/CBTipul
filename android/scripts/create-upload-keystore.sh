#!/usr/bin/env bash
# Interactive upload-keystore setup for CBTipul.
# Passwords are read from the TTY only — never echoed or printed.
set -euo pipefail

KEYSTORE="${HOME}/.android/cbtipul-upload.jks"
PROPS="${HOME}/.gradle/gradle.properties"
ALIAS="cbtipul"
DNAME="CN=CBTipul, OU=Mobile, O=CBTipul, L=Tel Aviv, ST=Israel, C=IL"

if [[ ! -t 0 && ! -e /dev/tty ]]; then
  echo "No TTY available. Run this script in your local terminal:" >&2
  echo "  bash \"$(cd "$(dirname "$0")" && pwd)/create-upload-keystore.sh\"" >&2
  exit 1
fi

TTY=/dev/tty

if [[ -f "$KEYSTORE" ]]; then
  echo "Refusing to replace existing keystore: $KEYSTORE" >&2
  echo "Move or rename it first if you intentionally want a new one." >&2
  exit 1
fi

mkdir -p "${HOME}/.android" "${HOME}/.gradle"

echo "Creating Play upload keystore at: $KEYSTORE"
echo "Alias: $ALIAS"
echo

# Prompt on the real TTY so passwords never appear in logs/agent output.
printf "Keystore password: " >"$TTY"
IFS= read -r -s STORE_PASS <"$TTY" || true
printf "\n" >"$TTY"
if [[ -z "${STORE_PASS}" ]]; then
  echo "Keystore password cannot be empty." >&2
  exit 1
fi

printf "Key password (Enter to reuse keystore password): " >"$TTY"
IFS= read -r -s KEY_PASS <"$TTY" || true
printf "\n" >"$TTY"
if [[ -z "${KEY_PASS}" ]]; then
  KEY_PASS="$STORE_PASS"
fi

keytool -genkeypair \
  -keystore "$KEYSTORE" \
  -alias "$ALIAS" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "$DNAME" \
  -storepass "$STORE_PASS" \
  -keypass "$KEY_PASS" \
  >/dev/null

chmod 600 "$KEYSTORE"

# Merge CBTipul signing props into ~/.gradle/gradle.properties without printing secrets.
touch "$PROPS"
chmod 600 "$PROPS"
TMP="$(mktemp)"
# Drop prior cbtipul.* lines, keep everything else.
if [[ -s "$PROPS" ]]; then
  grep -v '^cbtipul\.' "$PROPS" >"$TMP" || true
else
  : >"$TMP"
fi
{
  cat "$TMP"
  printf '%s\n' \
    "cbtipul.storeFile=${KEYSTORE}" \
    "cbtipul.storePassword=${STORE_PASS}" \
    "cbtipul.keyAlias=${ALIAS}" \
    "cbtipul.keyPassword=${KEY_PASS}"
} >"$PROPS"
rm -f "$TMP"
chmod 600 "$PROPS"

unset STORE_PASS KEY_PASS
echo
echo "Done."
echo "  Keystore: $KEYSTORE"
echo "  Properties updated: $PROPS (mode 600)"
echo "  Passwords were not printed."

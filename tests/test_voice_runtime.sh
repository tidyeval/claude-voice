#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT_DIR/hooks/voice-runtime.sh"

TMP_DIR="$(mktemp -d)"
STUB_DIR="$TMP_DIR/bin"
LOG_FILE="$TMP_DIR/calls.log"
export VOICE_STATE_FILE="$TMP_DIR/state"
export VOICE_SPEAK_URL="http://127.0.0.1:58732/speak"
export PATH="$STUB_DIR:$PATH"

mkdir -p "$STUB_DIR"
: > "$LOG_FILE"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  if [ "$expected" != "$actual" ]; then
    printf 'Expected: %s\nActual:   %s\n' "$expected" "$actual" >&2
    fail "$message"
  fi
}

assert_log_contains() {
  local pattern="$1"
  local message="$2"

  if ! grep -qE "$pattern" "$LOG_FILE"; then
    printf 'Log:\n%s\n' "$(cat "$LOG_FILE")" >&2
    fail "$message"
  fi
}

assert_log_not_contains() {
  local pattern="$1"
  local message="$2"

  if grep -qE "$pattern" "$LOG_FILE"; then
    printf 'Log:\n%s\n' "$(cat "$LOG_FILE")" >&2
    fail "$message"
  fi
}

write_stub_commands() {
  cat > "$STUB_DIR/killall" <<'STUB'
#!/bin/bash
printf 'killall %s\n' "$*" >> "$VOICE_TEST_LOG"
exit 0
STUB

  cat > "$STUB_DIR/say" <<'STUB'
#!/bin/bash
printf 'say %s\n' "$*" >> "$VOICE_TEST_LOG"
exit 0
STUB

  cat > "$STUB_DIR/afplay" <<'STUB'
#!/bin/bash
printf 'afplay %s\n' "$*" >> "$VOICE_TEST_LOG"
exit 0
STUB

  cat > "$STUB_DIR/curl" <<'STUB'
#!/bin/bash
printf 'curl %s\n' "$*" >> "$VOICE_TEST_LOG"
if [ "${VOICE_TEST_CURL_WAV:-}" = "1" ]; then
  printf '{"wav":"%s"}\n' "$VOICE_TEST_WAV"
else
  printf '{}\n'
fi
exit 0
STUB

  chmod +x "$STUB_DIR/killall" "$STUB_DIR/say" "$STUB_DIR/afplay" "$STUB_DIR/curl"
}

reset_log() {
  : > "$LOG_FILE"
}

write_stub_commands
export VOICE_TEST_LOG="$LOG_FILE"

prepared=$(voice_prepare_text $'\n# **Hello** [world] `now`\nSecond line')
assert_eq "Hello world now" "$prepared" "cleans markdown from first non-empty line"

long_text="$(seq -s ' ' 1 60)"
truncated="$(voice_prepare_text "$long_text")"
expected_truncated="$(seq -s ' ' 1 50 | sed 's/ $//')"
assert_eq "$expected_truncated" "$truncated" "truncates assistant line to 50 words"

assert_eq "de" "$(voice_detect_language "Das ist gut")" "detects German common words"
assert_eq "de" "$(voice_detect_language "Grüße aus Berlin")" "detects German umlauts"
assert_eq "en" "$(voice_detect_language "Hello from the voice runtime")" "defaults non-German text to English"

printf 'on\n' > "$VOICE_STATE_FILE"
VOICE_TEST_WAV="$TMP_DIR/speech.wav"
export VOICE_TEST_WAV
touch "$VOICE_TEST_WAV"
export VOICE_TEST_CURL_WAV=1
reset_log
voice_speak_assistant_message $'\n**Hello** [friend]\nIgnored second line'
wait || true
assert_log_contains 'curl .*"text": "Hello friend\\n".*"lang": "en"' "posts cleaned English text to Kokoro server"
assert_log_contains "afplay $VOICE_TEST_WAV" "plays returned WAV with afplay"
assert_log_not_contains 'say .*Hello friend' "does not fall back to say when WAV exists"

reset_log
voice_speak_assistant_message "Das ist gut"
wait || true
assert_log_contains 'say -v Reed \(German \(Germany\)\) -r 200 Das ist gut' "uses German macOS voice for German text"
assert_log_not_contains '^curl ' "does not call Kokoro for German text"

export VOICE_TEST_CURL_WAV=0
reset_log
voice_speak_assistant_message "Hello fallback"
wait || true
assert_log_contains '^curl ' "tries Kokoro for English text"
assert_log_contains 'say -v Reed \(English \(US\)\) -r 210 Hello fallback' "falls back to English macOS voice without WAV"

printf 'off\n' > "$VOICE_STATE_FILE"
reset_log
voice_speak_assistant_message "Hello disabled"
wait || true
assert_eq "" "$(cat "$LOG_FILE")" "does nothing when voice state is off"

printf 'on\n' > "$VOICE_STATE_FILE"
export VOICE_TEST_CURL_WAV=0
reset_log
printf '{"last_assistant_message":"**Adapter** [line]\\nSecond line"}\n' | bash "$ROOT_DIR/hooks/tts-summary.sh"
wait || true
assert_log_contains 'curl .*"text": "Adapter line\\n".*"lang": "en"' "Claude adapter reads last_assistant_message"

printf 'ok\n'

#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT_DIR/install-config.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

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

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if ! grep -qE "$pattern" "$file"; then
    printf '%s:\n%s\n' "$file" "$(cat "$file")" >&2
    fail "$message"
  fi
}

CODEX_DIR="$TMP_DIR/.codex"
HOOK_CMD="$CODEX_DIR/hooks/codex-tts-summary.sh"
mkdir -p "$CODEX_DIR"
cat > "$CODEX_DIR/config.toml" <<'TOML'
model = "gpt-5.5"

[features]
web_search_request = true

[projects."/tmp/example"]
trust_level = "trusted"
TOML

cat > "$CODEX_DIR/hooks.json" <<'JSON'
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/tmp/existing-hook.sh"
          }
        ]
      }
    ]
  }
}
JSON

agent_voice_configure_codex "$CODEX_DIR" "$HOOK_CMD"

assert_file_contains "$CODEX_DIR/config.toml" '^codex_hooks = true$' "enables Codex hooks feature"
assert_file_contains "$CODEX_DIR/config.toml" '^web_search_request = true$' "preserves existing features"
assert_file_contains "$CODEX_DIR/config.toml" '^\[projects\."/tmp/example"\]$' "preserves later TOML tables"

assert_eq "$HOOK_CMD" "$(jq -r '.hooks.Stop[0].hooks[0].command' "$CODEX_DIR/hooks.json")" "writes Codex Stop hook command"
assert_eq "/tmp/existing-hook.sh" "$(jq -r '.hooks.UserPromptSubmit[0].hooks[0].command' "$CODEX_DIR/hooks.json")" "preserves existing hook entries"

agent_voice_configure_codex "$CODEX_DIR" "$HOOK_CMD"
assert_eq "1" "$(jq '[.hooks.Stop[]?.hooks[]? | select(.command == "'"$HOOK_CMD"'")] | length' "$CODEX_DIR/hooks.json")" "does not duplicate Codex hook"

CLAUDE_SETTINGS="$TMP_DIR/.claude/settings.json"
agent_voice_enable_claude_hook "$CLAUDE_SETTINGS" "$TMP_DIR/tts-summary.sh" || true
assert_eq "$TMP_DIR/tts-summary.sh" "$(jq -r '.hooks.Stop[0].hooks[0].command' "$CLAUDE_SETTINGS")" "creates Claude Stop hook settings"

printf 'ok\n'

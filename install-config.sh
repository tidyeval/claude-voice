#!/bin/bash

agent_voice_enable_claude_hook() {
    local settings="$1"
    local hook_cmd="$2"

    if [ -f "$settings" ]; then
        if jq -e '.hooks.Stop[]?.hooks[]? | select(.command == "'"$hook_cmd"'")' "$settings" &>/dev/null; then
            return 1
        fi

        local tmpfile
        tmpfile=$(mktemp)
        jq --arg cmd "$hook_cmd" '
            .hooks //= {} |
            .hooks.Stop //= [] |
            .hooks.Stop += [{"matcher": "", "hooks": [{"type": "command", "command": $cmd}]}]
        ' "$settings" > "$tmpfile" && mv "$tmpfile" "$settings"
        return 0
    fi

    mkdir -p "$(dirname "$settings")"
    jq -n --arg cmd "$hook_cmd" '{
      hooks: {
        Stop: [
          {
            matcher: "",
            hooks: [
              {
                type: "command",
                command: $cmd
              }
            ]
          }
        ]
      }
    }' > "$settings"
    return 0
}

agent_voice_enable_codex_feature() {
    local config="$1"

    mkdir -p "$(dirname "$config")"
    CONFIG_PATH="$config" python3 <<'PY'
import os
import re
from pathlib import Path

path = Path(os.environ["CONFIG_PATH"])
text = path.read_text() if path.exists() else ""

if not text.strip():
    path.write_text("[features]\ncodex_hooks = true\n")
    raise SystemExit

features_match = re.search(r"(?m)^\[features\]\s*$", text)
if not features_match:
    suffix = "\n" if text.endswith("\n") else "\n\n"
    path.write_text(text + suffix + "[features]\ncodex_hooks = true\n")
    raise SystemExit

start = features_match.end()
next_table = re.search(r"(?m)^\[", text[start:])
end = start + next_table.start() if next_table else len(text)
block = text[start:end]

if re.search(r"(?m)^\s*codex_hooks\s*=", block):
    block = re.sub(r"(?m)^(\s*codex_hooks\s*=\s*).*$", r"\1true", block)
else:
    block = "\ncodex_hooks = true" + block

path.write_text(text[:start] + block + text[end:])
PY
}

agent_voice_enable_codex_hook() {
    local hooks_json="$1"
    local hook_cmd="$2"

    mkdir -p "$(dirname "$hooks_json")"

    if [ -f "$hooks_json" ]; then
        if jq -e '.hooks.Stop[]?.hooks[]? | select(.command == "'"$hook_cmd"'")' "$hooks_json" &>/dev/null; then
            return 1
        fi
    else
        printf '{}\n' > "$hooks_json"
    fi

    local tmpfile
    tmpfile=$(mktemp)
    jq --arg cmd "$hook_cmd" '
        .hooks //= {} |
        .hooks.Stop //= [] |
        .hooks.Stop += [{
            "hooks": [{
                "type": "command",
                "command": $cmd,
                "statusMessage": "Speaking response",
                "timeout": 30
            }]
        }]
    ' "$hooks_json" > "$tmpfile" && mv "$tmpfile" "$hooks_json"
    return 0
}

agent_voice_configure_codex() {
    local codex_dir="$1"
    local hook_cmd="$2"

    agent_voice_enable_codex_feature "$codex_dir/config.toml"
    agent_voice_enable_codex_hook "$codex_dir/hooks.json" "$hook_cmd" || true
}

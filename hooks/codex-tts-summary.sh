#!/bin/bash
# Stop hook: speaks the first line of a Codex response through the shared runtime.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/voice-runtime.sh"

INPUT=$(cat)
RESULT=$(echo "$INPUT" | jq -r '.last_assistant_message // empty')

voice_speak_assistant_message "$RESULT"

exit 0

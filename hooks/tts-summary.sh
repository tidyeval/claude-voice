#!/bin/bash
# Stop hook: speaks the first line of Claude's response.
# English: Kokoro-82M via local server. German: macOS `say` (Kokoro has no German support).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/voice-runtime.sh"

INPUT=$(cat)
RESULT=$(echo "$INPUT" | jq -r '.last_assistant_message // empty')

voice_speak_assistant_message "$RESULT"

exit 0

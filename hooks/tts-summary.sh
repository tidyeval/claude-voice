#!/bin/bash
# Stop hook: speaks the first line of Claude's response.
# English: Kokoro-82M via local server. German: macOS `say` (Kokoro has no German support).

STATE_FILE="/tmp/claude-tts/state"
[ ! -f "$STATE_FILE" ] && exit 0
[ "$(cat "$STATE_FILE" 2>/dev/null)" != "on" ] && exit 0

INPUT=$(cat)
RESULT=$(echo "$INPUT" | jq -r '.last_assistant_message // empty')

[ -z "$RESULT" ] && exit 0

# Extract first non-empty line, strip markdown formatting
FIRST_LINE=$(echo "$RESULT" | sed '/^[[:space:]]*$/d' | head -1 | sed 's/^#\+ //' | sed 's/\*\*//g' | sed 's/`//g' | sed 's/\[//g' | sed 's/\]//g')

[ -z "$FIRST_LINE" ] && exit 0

# Truncate to ~50 words
FIRST_LINE=$(echo "$FIRST_LINE" | awk '{for(i=1;i<=50&&i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ $//')

# Language detection: German if umlauts or common German words present
if echo "$FIRST_LINE" | grep -qiE '[äöüß]|(\b(und|oder|ist|nicht|das|die|der|ein|eine|wird|wurde|haben|kann|auch|mit|für|auf|noch|werden)\b)'; then
  LANG="de"
else
  LANG="en"
fi

# Kill any previous playback
killall afplay 2>/dev/null
killall say 2>/dev/null

if [ "$LANG" = "de" ]; then
  # German: macOS say (Kokoro-82M doesn't support German)
  say -v "Reed (German (Germany))" -r 200 "$FIRST_LINE" &
else
  # English: try Kokoro TTS server, fall back to macOS say
  RESPONSE=$(curl -s --max-time 5 -X POST http://127.0.0.1:58732/speak \
    -H 'Content-Type: application/json' \
    -d "{\"text\": $(echo "$FIRST_LINE" | jq -Rs .), \"lang\": \"en\"}" 2>/dev/null)

  WAV=$(echo "$RESPONSE" | jq -r '.wav // empty' 2>/dev/null)

  if [ -n "$WAV" ] && [ -f "$WAV" ]; then
    afplay "$WAV" &
  else
    say -v "Reed (English (US))" -r 210 "$FIRST_LINE" &
  fi
fi

exit 0

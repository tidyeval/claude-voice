#!/bin/bash
# Shared voice runtime for agent Stop hooks.

VOICE_STATE_FILE="${VOICE_STATE_FILE:-/tmp/claude-tts/state}"
VOICE_SPEAK_URL="${VOICE_SPEAK_URL:-http://127.0.0.1:58732/speak}"

voice_is_enabled() {
  [ -f "$VOICE_STATE_FILE" ] && [ "$(cat "$VOICE_STATE_FILE" 2>/dev/null)" = "on" ]
}

voice_prepare_text() {
  local text="$1"
  local first_line

  first_line=$(
    printf '%s\n' "$text" |
      sed '/^[[:space:]]*$/d' |
      head -1 |
      sed 's/^#\{1,\}[[:space:]]*//' |
      sed 's/\*\*//g' |
      sed 's/`//g' |
      sed 's/\[//g' |
      sed 's/\]//g'
  )

  [ -z "$first_line" ] && return 0

  printf '%s\n' "$first_line" |
    awk '{for(i=1;i<=50&&i<=NF;i++) printf "%s ", $i; print ""}' |
    sed 's/ $//'
}

voice_detect_language() {
  local text="$1"

  if printf '%s\n' "$text" | grep -qiE '[äöüß]|(\b(und|oder|ist|nicht|das|die|der|ein|eine|wird|wurde|haben|kann|auch|mit|für|auf|noch|werden)\b)'; then
    printf 'de\n'
  else
    printf 'en\n'
  fi
}

voice_stop_existing_playback() {
  killall afplay 2>/dev/null
  killall say 2>/dev/null
}

voice_play_german() {
  local text="$1"
  say -v "Reed (German (Germany))" -r 200 "$text" &
}

voice_play_english() {
  local text="$1"
  local response
  local wav

  response=$(
    curl -s --max-time 5 -X POST "$VOICE_SPEAK_URL" \
      -H 'Content-Type: application/json' \
      -d "{\"text\": $(printf '%s\n' "$text" | jq -Rs .), \"lang\": \"en\"}" 2>/dev/null
  )

  wav=$(printf '%s\n' "$response" | jq -r '.wav // empty' 2>/dev/null)

  if [ -n "$wav" ] && [ -f "$wav" ]; then
    afplay "$wav" &
  else
    say -v "Reed (English (US))" -r 210 "$text" &
  fi
}

voice_play_text() {
  local text="$1"
  local lang

  [ -z "$text" ] && return 0

  lang=$(voice_detect_language "$text")
  voice_stop_existing_playback

  if [ "$lang" = "de" ]; then
    voice_play_german "$text"
  else
    voice_play_english "$text"
  fi
}

voice_speak_assistant_message() {
  local message="$1"
  local text

  voice_is_enabled || return 0
  [ -z "$message" ] && return 0

  text=$(voice_prepare_text "$message")
  [ -z "$text" ] && return 0

  voice_play_text "$text"
}

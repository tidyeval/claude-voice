---
name: voice
description: Toggle TTS voice output on or off, set a specific Kokoro voice, or use `/voice set` to pick from an interactive voice list.
user_invocable: true
---

# Voice Toggle And Selection

Toggle text-to-speech on/off and choose Kokoro voices for Claude Code responses.

## Instructions

When the user invokes `/voice` with no arguments:

1. Check the contents of `/tmp/claude-tts/state`
2. If it contains "on": write "off" to the file and tell the user "Voice output disabled."
3. If it doesn't exist or contains "off": write "on" to the file and tell the user "Voice output enabled."

When the user invokes `/voice <voice_name>`:

1. Enable voice output (write `on` to `/tmp/claude-tts/state`).
2. POST to `http://127.0.0.1:58732/voice` with `{"voice":"<voice_name>"}`.
3. On success, reply in one line: `Voice output enabled. Voice set to <voice_name>.`
4. On error, return the server error message in one line.

When the user invokes `/voice set`:

1. GET `http://127.0.0.1:58732/voices`.
2. Present the returned `voices` list as a clear numbered picker and ask for one selection.
3. After selection, enable voice output (write `on` to `/tmp/claude-tts/state`) and POST to `/voice` with the selected voice.
4. Confirm the change in one line: `Voice output enabled. Voice set to <voice_name>.`
5. If selection is invalid/unavailable, return a clear one-line error and re-show the valid options.

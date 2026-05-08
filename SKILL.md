---
name: voice
description: Toggle TTS voice output on or off. When enabled, the agent's summary line is spoken aloud after each response using Kokoro-82M.
user_invocable: true
---

# Voice Toggle

Toggle text-to-speech on or off for agent responses.

## Instructions

When the user invokes `/voice`, do the following:

1. Check the contents of `/tmp/claude-tts/state`
2. If it contains "on": write "off" to the file and tell the user "Voice output disabled."
3. If it doesn't exist or contains "off": write "on" to the file and tell the user "Voice output enabled."

Optional argument: `/voice [voice_name]` - enable voice AND switch to a specific Kokoro voice (e.g., `/voice am_adam`). To switch voice, POST to `http://127.0.0.1:58732/voice` with `{"voice": "<voice_name>"}`.

Available voices: am_puck (default), am_adam, am_michael, am_onyx, am_eric, am_echo, am_liam, am_fenrir, af_heart, af_bella, af_nova, af_sky, bm_george, bm_daniel, bf_emma, bf_lily.

Keep the response to one line. No explanation needed.

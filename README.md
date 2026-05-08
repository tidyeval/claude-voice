# Claude Voice

Give Claude Code and Codex a voice. Literally.

Type `/voice` and every Claude Code or Codex response starts with the first line spoken aloud using [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M), a fast, high-quality text-to-speech model that runs entirely on your machine. No API keys, no cloud, no latency.

German responses automatically use macOS's built-in voice (Kokoro doesn't support German yet).

## What happens

1. You type `/voice` to toggle voice on
2. Claude Code or Codex responds to your question
3. The first line of the response is spoken aloud
4. That's it. Type `/voice` again to turn it off

Switch voices anytime: `/voice am_adam`, `/voice af_bella`, etc.

## Install

**You'll need:** macOS, Python 3.10-3.12, [uv](https://docs.astral.sh/uv/), and jq (comes with macOS, or `brew install jq`).

```bash
# 1. Clone the repo
git clone https://github.com/YOUR_USERNAME/claude-voice.git
cd claude-voice

# 2. Run the installer
./install.sh
```

The installer does everything:
- Installs the TTS server to `~/.claude/tts-server/`
- Downloads Kokoro-82M weights (~300 MB, first time only)
- Sets up a background service via launchd (starts on login)
- Installs the `/voice` skill and Stop hooks for Claude Code and Codex
- Wires Claude Code through `~/.claude/settings.json`
- Enables Codex hooks in `~/.codex/config.toml` and wires Codex Stop through `~/.codex/hooks.json`

The model download takes a minute. The rest is fast.

## Voices

Pick a voice with `/voice <name>`. Default is `am_puck`.

| Voice | Sounds like |
|-------|-------------|
| `am_puck` | Warm, clear, versatile (default) |
| `am_adam` | Deep, steady narrator |
| `am_michael` | Friendly, conversational |
| `am_onyx` | Rich baritone |
| `am_eric` | Casual, upbeat |
| `am_echo` | Soft, thoughtful |
| `am_liam` | Young, energetic |
| `am_fenrir` | Commanding, dramatic |
| `af_heart` | Warm, expressive |
| `af_bella` | Smooth, confident |
| `af_nova` | Bright, clear |
| `af_sky` | Light, airy |
| `bm_george` | British, distinguished |
| `bm_daniel` | British, warm |
| `bf_emma` | British, polished |
| `bf_lily` | British, gentle |

`a` = American, `b` = British, `m` = male, `f` = female.

## How it works

```
You ask Claude Code or Codex something
        │
        ▼
The agent responds
        │
        ▼
Stop hook fires ──► Extracts first line of response
                           │
                           ▼
                    Is it German? ──► Yes ──► macOS `say` (Reed voice)
                           │
                           No
                           │
                           ▼
                    POST /speak to Kokoro server
                           │
                           ▼
                    Server generates WAV
                           │
                           ▼
                    afplay speaks it 🔊
```

The Kokoro server stays warm in memory (launchd keeps it alive), so there's no cold start. First response after boot takes ~2 seconds, after that it's near-instant.

## Codex support

The installer copies the Codex Stop hook to `~/.codex/hooks/codex-tts-summary.sh`, shares the runtime at `~/.codex/hooks/voice-runtime.sh`, installs `/voice` instructions to `~/.codex/skills/voice/`, enables `codex_hooks = true` in `~/.codex/config.toml`, and adds a Stop entry to `~/.codex/hooks.json`.

Smoke-test Codex after install:

```bash
cat /tmp/claude-tts/state
codex
```

Inside Codex, invoke `/voice` or ask Codex to turn voice output on, then send a short prompt. To disable voice, invoke `/voice` again or write `off` to `/tmp/claude-tts/state`.

## Something not working?

**Server not responding:**
```bash
# Check if it's running
curl http://127.0.0.1:58732/health

# Check logs
tail -20 /tmp/claude-tts/server.log

# Restart it
launchctl unload ~/Library/LaunchAgents/com.claude.tts.plist
launchctl load ~/Library/LaunchAgents/com.claude.tts.plist
```

**No sound:**
- Is voice enabled? Check: `cat /tmp/claude-tts/state` (should say "on")
- Is your volume up? (seriously, it happens)
- Is another `afplay` or `say` process stuck? `killall afplay say`

**Model download failed:**
```bash
cd ~/.claude/tts-server
.venv/bin/python -c "from kokoro import KPipeline; KPipeline(lang_code='a')"
```

## Uninstall

```bash
cd claude-voice
./uninstall.sh
```

Then remove the Stop hook entry from `~/.claude/settings.json` (the uninstaller will remind you).

If you installed Codex support, also remove the Stop entry that references `codex-tts-summary.sh` from `~/.codex/hooks.json`. You may leave `codex_hooks = true` enabled if other Codex hooks use it.

## License

MIT

# Agent Voice Repo Instructions

This repo extends the global Codex workflow. See `/Users/tino.kanngiesser/.codex/SOUL.md` and the global `AGENTS.md` for defaults.

## Project Shape

- Product: Claude Voice, a local macOS text-to-speech add-on for Claude Code and Codex.
- Runtime: Bash installer/hook plus a small Python Flask server using Kokoro-82M.
- Target platform: macOS only. The install flow depends on `launchd`, `afplay`, `say`, `jq`, `uv`, `~/.claude`, and `~/.codex`.
- User-facing behavior is documented in `README.md`; keep agent operating notes here and durable project context in `CONTEXT.md`.

## Important Paths

- `install.sh`: installs server files, launchd plist, Stop hooks, `/voice` skill, Claude Code settings hook, and Codex hook config.
- `install-config.sh`: shared installer config helpers for Claude settings and Codex hooks/config.
- `uninstall.sh`: removes installed service/hook/skill files and temp files; settings cleanup remains manual.
- `hooks/tts-summary.sh`: Stop hook that extracts the first assistant line, detects German vs English, and plays audio.
- `hooks/codex-tts-summary.sh`: Codex Stop hook adapter that extracts the latest assistant message and delegates to the shared runtime.
- `hooks/voice-runtime.sh`: shared hook runtime for voice state, text cleanup, language detection, TTS calls, and playback fallback.
- `server/server.py`: Flask app, Kokoro pipeline loading, `/health`, `/voices`, `/voice`, and `/speak`.
- `server/test_server.py`: focused Flask endpoint tests.
- `tests/test_voice_runtime.sh`: focused shell tests for hook/runtime behavior with audio/network commands stubbed.
- `SKILL.md`: installed `/voice` command instructions.

## Verification

Use the narrowest useful command first.

- Proven focused server tests in this checkout: `cd server && .venv/bin/python -m pytest`
- Proven focused hook/runtime tests: `bash tests/test_voice_runtime.sh`
- Proven focused installer config tests: `bash tests/test_install_config.sh`
- Syntax check for shell entrypoints: `bash -n hooks/tts-summary.sh hooks/codex-tts-summary.sh hooks/voice-runtime.sh tests/test_voice_runtime.sh tests/test_install_config.sh install-config.sh install.sh uninstall.sh`
- Inferred fresh-environment setup: `cd server && uv sync --all-groups`, then `uv run pytest`
- Manual service smoke check after install: `curl http://127.0.0.1:58732/health`

Current caveat: `cd server && uv run pytest` failed in this checkout before a full sync because `soundfile` was missing from the active uv environment. The checked-in local `.venv` did pass the tests.

## Workflow

- Tiny docs or copy edits can be patched directly with focused verification when meaningful.
- Use `$tdd` for Small-or-larger behavior changes, especially server endpoints or hook parsing.
- Use `$diagnose` for broken install, launchd, audio playback, or model-loading reports.
- Use `$lets-document` when project structure, invariants, commands, or workflow docs drift.
- Use `$lets-plan` before creating new product work or broad changes.
- Use `$lets-ship` only when there is a ready issue or explicit issue waiver and the user asks for a landing workflow.

Do not auto-commit, push, merge, or close issues unless the user explicitly requests a landing workflow or invokes a skill whose contract includes it.

## Sharp Edges

- Do not change `~/.claude`, `~/Library/LaunchAgents`, or `/tmp/claude-tts` during repo edits unless the user explicitly asks to install, uninstall, or smoke-test locally.
- Keep the voice list in `server/server.py` and the README voice documentation aligned when voices change.
- German output is intentionally handled by macOS `say`; Kokoro-82M currently handles English here.
- The server binds to `127.0.0.1:58732`; changing the port requires updating hook, README, and skill instructions together.
- Hook JSON parsing depends on `jq` and the Claude Code/Codex Stop hook payload field `last_assistant_message`.

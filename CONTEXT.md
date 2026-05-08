# Agent Voice Context

## Purpose

Agent Voice gives local spoken feedback to coding agents. The current implementation works for Claude Code: when voice output is enabled, the Stop hook speaks the first non-empty line of the latest assistant response. English uses a local Kokoro-82M server; German falls back to macOS `say`.

## Audience

The primary user is a macOS user of Claude Code and Codex who wants lightweight, low-latency voice output without API keys or cloud TTS.

## Repo Map

- `README.md`: user-facing install, usage, troubleshooting, and voice list.
- `CHANGELOG.md`: release notes for user-visible changes.
- `SKILL.md`: `/voice` skill currently installed into `~/.claude/skills/voice/`.
- `install.sh`: macOS installer for server, launchd service, hook, skill, and Claude Code settings.
- `uninstall.sh`: cleanup script for installed files and temp data.
- `hooks/tts-summary.sh`: Claude Code Stop hook and playback orchestration.
- `hooks/voice-runtime.sh`: shared hook runtime for voice state checks, assistant text preparation, language detection, TTS server calls, and macOS playback fallback.
- `server/pyproject.toml`: Python package metadata and dependencies.
- `server/server.py`: local Flask TTS server.
- `server/test_server.py`: focused endpoint tests.
- `tests/test_voice_runtime.sh`: focused shell tests for runtime and Claude Stop-hook adapter behavior.

## Runtime Flow

1. User toggles voice with `/voice`; state is stored in `/tmp/claude-tts/state`.
2. Claude Code emits a Stop hook payload after an assistant response.
3. `hooks/tts-summary.sh` extracts `last_assistant_message` as the Claude-specific adapter.
4. `hooks/voice-runtime.sh` cleans the first non-empty line and truncates it to 50 words.
5. The shared runtime detects German via simple text heuristics.
6. German text plays through macOS `say`.
7. English text posts to `http://127.0.0.1:58732/speak`; the server writes `/tmp/claude-tts/speech.wav`.
8. The runtime plays the WAV with `afplay`, falling back to macOS `say` if the server path is unavailable.

## Domain Terms

- Voice state: the on/off flag in `/tmp/claude-tts/state`.
- Stop hook: client hook that receives the assistant message payload after a turn.
- TTS server: local Flask server that keeps Kokoro warm and exposes health, voice selection, and speech endpoints.
- Active voice: the server-side default Kokoro voice used when `/speak` receives no explicit voice.
- Agent adapter: a thin client-specific layer for install paths, settings wiring, and extracting assistant text from the client's hook payload.
- Shared voice runtime: the common state, text preparation, language detection, TTS server calls, and playback behavior reused by agent adapters.

## Target Architecture

- Keep one shared local voice runtime for state, text cleanup, language detection, Kokoro/macOS playback, voice listing, and voice selection.
- Keep Claude and Codex behavior in thin adapters. Adapters should own install locations, settings files, hook enablement, and any payload differences.
- Claude adapter specifics: install under `~/.claude`, wire Claude Code Stop hook settings, and install the Claude `/voice` skill.
- Codex adapter specifics: install under `~/.codex`, enable `features.codex_hooks`, wire a Stop hook through `~/.codex/hooks.json` or inline `[hooks]`, and install Codex-facing command/skill instructions if supported.
- Current Codex docs say lifecycle hooks can be loaded from `hooks.json` or inline `[hooks]`, and Stop is a supported event. Local evidence shows an old Codex config used `features.codex_hooks` and a Stop hook command.

## Invariants

- The app must remain local-first: no API keys or cloud TTS are required.
- Installer behavior is macOS-specific.
- The server should bind only to loopback.
- `/voice set` depends on `/voices` and `/voice` staying compatible with `SKILL.md`.
- README, skill instructions, hook endpoints, and server endpoints must move together when command or API behavior changes.
- Shared runtime behavior must stay client-neutral; Claude and Codex differences belong in adapters.

## Open Questions

- Whether the repo should track a lockfile for reproducible fresh installs.
- Whether the current feature branch `codex/voice-set-picker` should be landed, turned into a PR, or kept as review work.
- Whether shell hook behavior should get automated tests before more parsing or language-detection changes.
- Whether the first Codex release should install only the CLI/TUI hook path or also support Codex desktop app behavior when the app exposes different lifecycle data.

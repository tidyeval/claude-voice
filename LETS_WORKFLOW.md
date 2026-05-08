# Lets Workflow

Status: shipping
Current step: lets-ship
Next step: lets-ship

## Goal

Evolve Claude Voice into Agent Voice: one shared local voice runtime with thin Claude and Codex adapters.

## Current State

- Repo has a GitHub remote: `https://github.com/tidyeval/claude-voice.git`.
- Current branch after issue #3 landing: `main`.
- `main` exists locally and on origin.
- `IMPLEMENTATION_ORDER.md` now tracks three implementation issues.
- Issue #3 shipped the shared voice runtime and closed on GitHub.
- Issue #4 adds a Codex Stop-hook adapter, Codex installer wiring, and Codex install/uninstall docs.
- Codex support is wired through `~/.codex/hooks.json` with `features.codex_hooks` enabled in `~/.codex/config.toml`.

## Decisions Captured

- Keep adoption narrow: no behavior changes, no new tooling, no branch or issue automation.
- Use `AGENTS.md` for repo-specific operating rules and commands.
- Use `CONTEXT.md` for product purpose, runtime flow, repo map, invariants, and open questions.
- Do not add broader architecture docs yet; the repo is small enough for `CONTEXT.md`.
- Target architecture is a shared voice runtime plus agent adapters.
- Shared runtime owns voice state, text cleanup, language detection, TTS server calls, voice selection, and playback fallback.
- Claude and Codex adapters own install locations, config wiring, hook enablement, and payload extraction differences.
- Planned as three direct implementation issues rather than a PRD because the product direction and vertical slices are clear.

## Verification Evidence

- Passed: `cd server && .venv/bin/python -m pytest` with 3 tests passing.
- Failed before sync: `cd server && uv run pytest` because `soundfile` was missing from the active uv environment.
- Planning created GitHub issues #3, #4, and #5.
- Issue #3 branch verification passed with `bash -n hooks/tts-summary.sh hooks/voice-runtime.sh tests/test_voice_runtime.sh install.sh uninstall.sh`, `bash tests/test_voice_runtime.sh`, and `cd server && .venv/bin/python -m pytest`.
- Issue #3 shipped to `main`, pushed, and closed on GitHub. Main verification passed with the same three commands.
- Issue #4 branch verification passed with `bash -n hooks/tts-summary.sh hooks/codex-tts-summary.sh hooks/voice-runtime.sh tests/test_voice_runtime.sh tests/test_install_config.sh install-config.sh install.sh uninstall.sh`, `bash tests/test_voice_runtime.sh`, `bash tests/test_install_config.sh`, and `cd server && .venv/bin/python -m pytest`.

## Recommended Next Actions

- Finish landing #4 to `main`, then close the issue with main verification evidence.
- Then run `$lets-ship` for #5: package and document Agent Voice for Claude and Codex.

# Lets Workflow

Status: shipping
Current step: lets-ship
Next step: lets-ship

## Goal

Evolve Claude Voice into Agent Voice: one shared local voice runtime with thin Claude and Codex adapters.

## Current State

- Repo has a GitHub remote: `https://github.com/tidyeval/claude-voice.git`.
- Current branch during adoption: `codex/voice-set-picker`.
- `main` exists locally and on origin.
- Current branch contains one feature commit over `main`: `feat: add /voice set picker and voice validation`.
- `IMPLEMENTATION_ORDER.md` now tracks three implementation issues.
- Current implementation is Claude-shaped: docs, install paths, hook payload wording, settings wiring, and skill installation assume `~/.claude`.
- Codex support is viable through Codex lifecycle hooks. Current docs describe `features.codex_hooks`, `hooks.json` or inline `[hooks]`, and Stop as a supported event.

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

## Recommended Next Actions

- Finish landing #3, then ship #4 for Codex Stop-hook adapter and installer wiring.
- Then ship #5 to package and document Agent Voice for Claude and Codex.

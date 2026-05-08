#!/bin/bash
set -e

# ─── Claude Voice Uninstaller ─────────────────────────────────────────
# Removes the TTS server, hook, skill, and launchd service.
# ──────────────────────────────────────────────────────────────────────

LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST_NAME="com.claude.tts.plist"

echo ""
echo "🔇 Claude Voice Uninstaller"
echo "==========================="
echo ""

# Stop and remove launchd service
if launchctl list 2>/dev/null | grep -q com.claude.tts; then
    echo "Stopping TTS server..."
    launchctl unload "$LAUNCH_AGENTS/$PLIST_NAME" 2>/dev/null || true
fi
rm -f "$LAUNCH_AGENTS/$PLIST_NAME"
echo "✓ Launchd service removed."

# Remove server
if [ -d "$HOME/.claude/tts-server" ]; then
    rm -rf "$HOME/.claude/tts-server"
    echo "✓ Server removed from ~/.claude/tts-server/"
fi

# Remove hook
if [ -f "$HOME/.claude/hooks/tts-summary.sh" ]; then
    rm -f "$HOME/.claude/hooks/tts-summary.sh"
    rm -f "$HOME/.claude/hooks/voice-runtime.sh"
    echo "✓ Hook removed from ~/.claude/hooks/"
fi

if [ -f "$HOME/.codex/hooks/codex-tts-summary.sh" ]; then
    rm -f "$HOME/.codex/hooks/codex-tts-summary.sh"
    rm -f "$HOME/.codex/hooks/voice-runtime.sh"
    echo "✓ Codex hook removed from ~/.codex/hooks/"
fi

# Remove skill
if [ -d "$HOME/.claude/skills/voice" ]; then
    rm -rf "$HOME/.claude/skills/voice"
    echo "✓ Skill removed from ~/.claude/skills/voice/"
fi

if [ -d "$HOME/.codex/skills/voice" ]; then
    rm -rf "$HOME/.codex/skills/voice"
    echo "✓ Codex skill removed from ~/.codex/skills/voice/"
fi

# Clean up temp files
rm -rf /tmp/claude-tts
echo "✓ Temp files cleaned up."

echo ""
echo "═══════════════════════════════════"
echo "✓ Claude Voice has been removed."
echo "═══════════════════════════════════"
echo ""
echo "One manual step remains:"
echo "  Edit ~/.claude/settings.json and remove the Stop hook"
echo "  entry that references tts-summary.sh"
echo "  Also edit ~/.codex/hooks.json and remove the Stop hook"
echo "  entry that references codex-tts-summary.sh if present."
echo ""

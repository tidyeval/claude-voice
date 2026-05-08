#!/bin/bash
set -e

# ─── Agent Voice Installer ────────────────────────────────────────────
# Installs the Kokoro-82M TTS server, Stop hooks, and /voice skill for
# Claude Code and Codex.
# ──────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/install-config.sh"

TTS_DIR="$HOME/.claude/tts-server"
HOOKS_DIR="$HOME/.claude/hooks"
SKILLS_DIR="$HOME/.claude/skills/voice"
CODEX_HOOKS_DIR="$HOME/.codex/hooks"
CODEX_SKILLS_DIR="$HOME/.codex/skills/voice"
CODEX_DIR="$HOME/.codex"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST_NAME="com.claude.tts.plist"
SETTINGS="$HOME/.claude/settings.json"

echo ""
echo "🔊 Agent Voice Installer"
echo "========================="
echo ""

# ─── Check prerequisites ──────────────────────────────────────────────

check_prereq() {
    if ! command -v "$1" &>/dev/null; then
        echo "❌ $1 is required but not installed."
        echo "   $2"
        exit 1
    fi
}

if [[ "$(uname)" != "Darwin" ]]; then
    echo "❌ This only works on macOS (needs launchd and afplay)."
    exit 1
fi

check_prereq "uv" "Install it: curl -LsSf https://astral.sh/uv/install.sh | sh"
check_prereq "jq" "Install it: brew install jq"
check_prereq "python3" "Install Python 3.10-3.12."

echo "✓ Prerequisites look good."
echo ""

# ─── Install server ───────────────────────────────────────────────────

echo "📦 Installing TTS server to $TTS_DIR ..."
mkdir -p "$TTS_DIR"
cp "$SCRIPT_DIR/server/server.py" "$TTS_DIR/"
cp "$SCRIPT_DIR/server/pyproject.toml" "$TTS_DIR/"
cp "$SCRIPT_DIR/server/.python-version" "$TTS_DIR/"

echo "📦 Installing Python dependencies (this takes a moment)..."
cd "$TTS_DIR"
uv sync
uv pip install pip

echo ""
echo "🧠 Downloading Kokoro-82M model weights (first time only, ~300 MB)..."
echo "   This will take a minute. Grab a coffee."
"$TTS_DIR/.venv/bin/python" -c "from kokoro import KPipeline; KPipeline(lang_code='a'); print('Model ready.')"

# ─── Create temp directory ─────────────────────────────────────────────

mkdir -p /tmp/claude-tts

# ─── Install launchd service ──────────────────────────────────────────

echo ""
echo "⚙️  Setting up background service..."

# Unload existing service if running
if launchctl list 2>/dev/null | grep -q com.claude.tts; then
    launchctl unload "$LAUNCH_AGENTS/$PLIST_NAME" 2>/dev/null || true
fi

# Generate plist with correct paths
mkdir -p "$LAUNCH_AGENTS"
cat > "$LAUNCH_AGENTS/$PLIST_NAME" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.claude.tts</string>
    <key>ProgramArguments</key>
    <array>
        <string>$TTS_DIR/.venv/bin/python</string>
        <string>$TTS_DIR/server.py</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$TTS_DIR</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/claude-tts/server.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/claude-tts/server.log</string>
</dict>
</plist>
PLIST

launchctl load "$LAUNCH_AGENTS/$PLIST_NAME"
echo "✓ TTS server is running in the background."

# ─── Install hook ─────────────────────────────────────────────────────

echo ""
echo "🪝 Installing Stop hook..."
mkdir -p "$HOOKS_DIR"
cp "$SCRIPT_DIR/hooks/tts-summary.sh" "$HOOKS_DIR/"
cp "$SCRIPT_DIR/hooks/voice-runtime.sh" "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/tts-summary.sh" "$HOOKS_DIR/voice-runtime.sh"
echo "✓ Hook installed at $HOOKS_DIR/tts-summary.sh"

mkdir -p "$CODEX_HOOKS_DIR"
cp "$SCRIPT_DIR/hooks/codex-tts-summary.sh" "$CODEX_HOOKS_DIR/"
cp "$SCRIPT_DIR/hooks/voice-runtime.sh" "$CODEX_HOOKS_DIR/"
chmod +x "$CODEX_HOOKS_DIR/codex-tts-summary.sh" "$CODEX_HOOKS_DIR/voice-runtime.sh"
echo "✓ Codex hook installed at $CODEX_HOOKS_DIR/codex-tts-summary.sh"

# ─── Install skill ────────────────────────────────────────────────────

echo ""
echo "🎯 Installing /voice skill..."
mkdir -p "$SKILLS_DIR"
cp "$SCRIPT_DIR/SKILL.md" "$SKILLS_DIR/"
echo "✓ Skill installed at $SKILLS_DIR/SKILL.md"

mkdir -p "$CODEX_SKILLS_DIR"
cp "$SCRIPT_DIR/SKILL.md" "$CODEX_SKILLS_DIR/"
echo "✓ Codex skill installed at $CODEX_SKILLS_DIR/SKILL.md"

# ─── Wire hook into settings.json ─────────────────────────────────────

echo ""
echo "🔧 Configuring Claude Code settings..."

HOOK_CMD="$HOOKS_DIR/tts-summary.sh"

if agent_voice_enable_claude_hook "$SETTINGS" "$HOOK_CMD"; then
    echo "✓ Stop hook added to settings.json"
else
    echo "✓ Stop hook already configured in settings.json"
fi

echo "🔧 Configuring Codex settings..."
CODEX_HOOK_CMD="$CODEX_HOOKS_DIR/codex-tts-summary.sh"
agent_voice_configure_codex "$CODEX_DIR" "$CODEX_HOOK_CMD"
echo "✓ Codex hooks enabled in $CODEX_DIR/config.toml"
echo "✓ Codex Stop hook configured in $CODEX_DIR/hooks.json"

# ─── Done ──────────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════"
echo "🎉 Agent Voice is installed!"
echo "═══════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. Start a Claude Code or Codex session"
echo "  2. Type /voice to enable voice output"
echo "  3. The agent will speak the first line of every response"
echo ""
echo "Health check:  curl http://127.0.0.1:58732/health"
echo "Server logs:   tail -f /tmp/claude-tts/server.log"
echo ""

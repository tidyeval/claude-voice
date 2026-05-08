#!/bin/bash
set -e

# ─── Claude Voice Installer ───────────────────────────────────────────
# Installs the Kokoro-82M TTS server, hook, and /voice skill for Claude Code.
# Everything goes under ~/.claude/ so it's easy to find and remove.
# ──────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TTS_DIR="$HOME/.claude/tts-server"
HOOKS_DIR="$HOME/.claude/hooks"
SKILLS_DIR="$HOME/.claude/skills/voice"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST_NAME="com.claude.tts.plist"
SETTINGS="$HOME/.claude/settings.json"

echo ""
echo "🔊 Claude Voice Installer"
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

# ─── Install skill ────────────────────────────────────────────────────

echo ""
echo "🎯 Installing /voice skill..."
mkdir -p "$SKILLS_DIR"
cp "$SCRIPT_DIR/SKILL.md" "$SKILLS_DIR/"
echo "✓ Skill installed at $SKILLS_DIR/SKILL.md"

# ─── Wire hook into settings.json ─────────────────────────────────────

echo ""
echo "🔧 Configuring Claude Code settings..."

HOOK_CMD="$HOOKS_DIR/tts-summary.sh"

if [ -f "$SETTINGS" ]; then
    # Check if hook is already wired
    if jq -e '.hooks.Stop[]?.hooks[]? | select(.command == "'"$HOOK_CMD"'")' "$SETTINGS" &>/dev/null; then
        echo "✓ Stop hook already configured in settings.json"
    else
        # Add Stop hook entry
        TMPFILE=$(mktemp)
        jq --arg cmd "$HOOK_CMD" '
            .hooks //= {} |
            .hooks.Stop //= [] |
            .hooks.Stop += [{"matcher": "", "hooks": [{"type": "command", "command": $cmd}]}]
        ' "$SETTINGS" > "$TMPFILE" && mv "$TMPFILE" "$SETTINGS"
        echo "✓ Stop hook added to settings.json"
    fi
else
    # Create minimal settings.json with the hook
    mkdir -p "$(dirname "$SETTINGS")"
    cat > "$SETTINGS" <<SETTINGS_EOF
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOK_CMD"
          }
        ]
      }
    ]
  }
}
SETTINGS_EOF
    echo "✓ Created settings.json with Stop hook"
fi

# ─── Done ──────────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════"
echo "🎉 Claude Voice is installed!"
echo "═══════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. Start a Claude Code session"
echo "  2. Type /voice to enable voice output"
echo "  3. Claude will speak the first line of every response"
echo ""
echo "Health check:  curl http://127.0.0.1:58732/health"
echo "Server logs:   tail -f /tmp/claude-tts/server.log"
echo ""

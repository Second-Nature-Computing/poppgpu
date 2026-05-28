#!/bin/bash
# Install PoppAI (or one of the simpler variants) as your Claude Code statusline.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"

# Dependencies
for cmd in jq nvidia-smi; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "error: $cmd is required but not found"
        exit 1
    fi
done

HAS_NVITOP=false
command -v nvitop &>/dev/null && HAS_NVITOP=true

# Pick a variant. Default is PoppAI; --compact and --full select the simpler variants.
echo "PoppAI installer"
echo ""
case "${1:-}" in
    --compact)
        VARIANT=compact; SRC="$SCRIPT_DIR/statusline-compact.sh"
        echo "Installing compact variant (single-line, nvidia-smi only)"
        ;;
    --full)
        if [ "$HAS_NVITOP" = false ]; then
            echo "warning: nvitop not found — full variant won't render correctly."
            echo "         install with: pip install nvitop"
        fi
        VARIANT=full; SRC="$SCRIPT_DIR/statusline.sh"
        echo "Installing full variant (multi-line nvitop graphics)"
        ;;
    --poppai|"")
        VARIANT=poppai; SRC="$SCRIPT_DIR/poppai.sh"
        echo "Installing PoppAI (your terminal flower)"
        ;;
    *)
        echo "unknown option: $1"
        echo "usage: ./install.sh [--poppai|--compact|--full]"
        exit 1
        ;;
esac

DEST="$CLAUDE_DIR/poppai.sh"
mkdir -p "$CLAUDE_DIR"
cp "$SRC" "$DEST"
chmod +x "$DEST"
echo "Copied to $DEST"

# Wire into settings.json
if [ -f "$SETTINGS" ]; then
    if jq -e '.statusLine' "$SETTINGS" &>/dev/null; then
        CURRENT=$(jq -r '.statusLine.command // "none"' "$SETTINGS")
        if [ "$CURRENT" != "~/.claude/poppai.sh" ]; then
            echo ""
            echo "Warning: statusLine already configured in $SETTINGS"
            echo "Current: $CURRENT"
            read -rp "Overwrite? [y/N] " -n 1
            echo
            if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
                echo "Skipped settings update. To configure manually, add to $SETTINGS:"
                echo '  "statusLine": {"type": "command", "command": "~/.claude/poppai.sh"}'
                exit 0
            fi
        fi
    fi
    jq '.statusLine = {"type": "command", "command": "~/.claude/poppai.sh"}' "$SETTINGS" \
        > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"
else
    echo '{"statusLine": {"type": "command", "command": "~/.claude/poppai.sh"}}' | jq . > "$SETTINGS"
fi

echo "Updated $SETTINGS"
echo ""
echo "Done. Restart Claude Code to see PoppAI."
echo "To switch variants later: ./install.sh [--poppai|--compact|--full]"

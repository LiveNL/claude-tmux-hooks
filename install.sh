#!/bin/bash
set -euo pipefail

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
HOOKS_DEST="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
R='\033[0m'

ok()   { echo -e "  ${GREEN}✓${R}  $*"; }
info() { echo -e "  ${YELLOW}→${R}  $*"; }
bold() { echo -e "${BOLD}$*${R}"; }

# ── Preflight ──────────────────────────────────────────────────────────────

bold "\nclaude-tmux-hooks installer"
echo ""

for dep in tmux jq; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "Error: '$dep' is required but not installed." >&2
        exit 1
    fi
done

# ── Step 1: Install hooks ──────────────────────────────────────────────────

bold "1. Installing hooks"
mkdir -p "$HOOKS_DEST"

for hook in busy-window.sh notify.sh reset-window.sh; do
    cp "$SCRIPT_DIR/hooks/$hook" "$HOOKS_DEST/$hook"
    chmod +x "$HOOKS_DEST/$hook"
    ok "Installed $HOOKS_DEST/$hook"
done

# ── Step 2: Merge settings.json ────────────────────────────────────────────

bold "\n2. Configuring Claude Code settings"

HOOKS_FRAGMENT=$(jq -n \
    --arg reset  "bash $HOOKS_DEST/reset-window.sh" \
    --arg notify "bash $HOOKS_DEST/notify.sh" \
    --arg busy   "bash $HOOKS_DEST/busy-window.sh" \
    '{
      hooks: {
        SessionStart:     [{"matcher": "", hooks: [{"type": "command", command: $reset}]}],
        Notification:     [{"matcher": "", hooks: [{"type": "command", command: $notify}]}],
        Stop:             [{"matcher": "", hooks: [{"type": "command", command: $notify}]}],
        PreToolUse:       [{"matcher": "", hooks: [{"type": "command", command: $busy}]}],
        UserPromptSubmit: [{"matcher": "", hooks: [{"type": "command", command: $busy}]}]
      }
    }')

if [ ! -f "$SETTINGS" ]; then
    mkdir -p "$(dirname "$SETTINGS")"
    echo "$HOOKS_FRAGMENT" | jq '.' > "$SETTINGS"
    ok "Created $SETTINGS"
else
    BACKUP="${SETTINGS}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$SETTINGS" "$BACKUP"
    info "Backed up existing settings to $(basename "$BACKUP")"

    # Additive merge: for each hook event, append our entries and deduplicate
    # by command string. Existing hooks are preserved.
    MERGED=$(jq \
        --argjson new "$HOOKS_FRAGMENT" '
        reduce ($new.hooks | keys[]) as $event (
            .;
            .hooks[$event] = (
                ((.hooks[$event] // []) + $new.hooks[$event])
                | unique_by(.hooks[0].command)
            )
        )
        ' "$SETTINGS")

    echo "$MERGED" | jq '.' > "$SETTINGS"
    ok "Merged hooks into $SETTINGS"
fi

# ── Step 3: tmux instructions ──────────────────────────────────────────────

echo ""
bold "3. Configure tmux (manual step)"
cat << TMUX

  Add one of the following to your ~/.tmux.conf, then reload:
  tmux source-file ~/.tmux.conf

  ── Option A: Use the included standalone format ──────────────────────────
  Replaces your window-status-format with a clean minimal default.

    source-file $SCRIPT_DIR/tmux/claude-state.conf

  ── Option B: Embed in your existing format ───────────────────────────────
  Paste the prefix from tmux/claude-state-prefix.txt at the start of your
  existing window-status-format and window-status-current-format strings.

    cat $SCRIPT_DIR/tmux/claude-state-prefix.txt

TMUX

bold "Done."
echo ""

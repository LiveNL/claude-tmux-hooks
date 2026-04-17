#!/bin/bash
# Creates a tmux demo session.
# All visual options (status-left, window-status-format, etc.) are intentionally
# inherited from the global config so the demo looks identical to the real setup.

SESSION="vhsdemo"

tmux kill-session -t "$SESSION" 2>/dev/null || true

COLS="${1:-140}"
ROWS="${2:-3}"

# Five windows to fill the status bar
tmux new-session  -d -s "$SESSION" -n "claude-hooks" -x "$COLS" -y "$ROWS"
tmux new-window      -t "$SESSION" -n "api-server"
tmux new-window      -t "$SESSION" -n "payments"
tmux new-window      -t "$SESSION" -n "auth"
tmux new-window      -t "$SESSION" -n "frontend"

# Blank the right side only — user's real config shows a live clock + Spotify
# that would clutter the recording. Everything else comes from global config.
tmux set-option -t "$SESSION" status-right        "#[fg=#0f1c1e,bg=#0f1c1e] "
tmux set-option -t "$SESSION" status-right-length 2
tmux set-option -t "$SESSION" status-right-style  "bg=#0f1c1e,fg=#0f1c1e"

# Pre-set state on other windows so the bar shows variety from the start
tmux set-option -w -t "${SESSION}:api-server" @claude-state "done"
tmux set-option -w -t "${SESSION}:payments"   @claude-state "running"
tmux set-option -w -t "${SESSION}:payments"   @claude-spinner "⬡"
tmux set-option -w -t "${SESSION}:auth"        @claude-state ""
tmux set-option -w -t "${SESSION}:frontend"    @claude-state "input"
tmux refresh-client -t "$SESSION" -S 2>/dev/null || true

# Focus window 1 for the demo
tmux select-window -t "${SESSION}:claude-hooks"

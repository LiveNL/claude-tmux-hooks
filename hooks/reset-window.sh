#!/bin/bash
# Fired on SessionStart.
# Clears the Claude state indicator and stops the spinner loop.

[ -n "$TMUX" ] || exit 0

PIDFILE="/tmp/claude-spinner-${TMUX_PANE#%}.pid"
if [ -f "$PIDFILE" ]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null
    rm -f "$PIDFILE"
fi

tmux set-option -w -t "$TMUX_PANE" @claude-state ""
tmux refresh-client -S

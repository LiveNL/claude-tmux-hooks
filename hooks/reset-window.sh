#!/bin/bash
# Fired on SessionStart.
# Clears any stale state from a previous session.
if [ -n "$TMUX" ]; then
    tmux set-option -w -t "$TMUX_PANE" @claude-state ""
    tmux refresh-client -S
fi

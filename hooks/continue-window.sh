#!/bin/bash
# Fired on PostToolUse.
# Restores the running state without resetting the spinner or elapsed timer.
# Handles the permission → running transition after a grant.

[ -n "$TMUX" ] || exit 0
tmux set-option -w -t "$TMUX_PANE" @claude-state "running"
tmux refresh-client -S

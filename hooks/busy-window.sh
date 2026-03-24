#!/bin/bash
# Fired on PreToolUse and UserPromptSubmit.
# Sets the window state to "running" so the tab indicator shows Claude is active.
if [ -n "$TMUX" ]; then
    tmux set-option -w -t "$TMUX_PANE" @claude-state "running"
    tmux refresh-client -S
fi

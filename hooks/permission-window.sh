#!/bin/bash
# Fired on PermissionRequest.
# Sets the window state to "permission" immediately so the tab turns red
# before the Notification event arrives.
if [ -n "$TMUX" ]; then
    tmux set-option -w -t "$TMUX_PANE" @claude-state "permission"
    tmux refresh-client -S
fi

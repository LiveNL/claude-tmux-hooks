#!/bin/bash
# Fired on PermissionRequest.
# Sets the window state to "permission" immediately so the tab turns red
# before the Notification event arrives.
# The spinner loop keeps running so the elapsed timer stays current.

[ -n "$TMUX" ] || exit 0
tmux set-option -w -t "$TMUX_PANE" @claude-state "permission"
tmux refresh-client -S

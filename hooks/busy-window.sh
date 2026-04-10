#!/bin/bash
# Fired on PreToolUse and UserPromptSubmit.
# Sets the window state to "running" and starts an animated spinner
# with an elapsed timer that updates every second.

[ -n "$TMUX" ] || exit 0

PIDFILE="/tmp/claude-spinner-${TMUX_PANE#%}.pid"

# Kill any existing spinner loop for this pane
if [ -f "$PIDFILE" ]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null
    rm -f "$PIDFILE"
fi

tmux set-option -w -t "$TMUX_PANE" @claude-state   "running"
tmux set-option -w -t "$TMUX_PANE" @claude-spinner  "⬢"
tmux refresh-client -S

frames=(⬢ ⬡)
pane="$TMUX_PANE"

(
    i=0
    n=${#frames[@]}
    while true; do
        sleep 1
        tmux set-option -w -t "$pane" @claude-spinner "${frames[$i]}" 2>/dev/null || exit 0
        tmux refresh-client -S 2>/dev/null
        i=$(( (i + 1) % n ))
    done
) </dev/null >/dev/null 2>&1 &
echo $! > "$PIDFILE"
disown $!

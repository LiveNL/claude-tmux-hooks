#!/bin/bash
# Creates a tmux demo session for VHS recording.
# Run directly or sourced from demo.tape.
# Uses the exact Nightfox-themed format strings from ~/.tmux.conf.

SESSION="vhsdemo"

tmux kill-session -t "$SESSION" 2>/dev/null || true

# Exact format strings from the user's Nightfox-themed ~/.tmux.conf
# (These are inlined here so the demo looks identical to the real setup.)
FMT='#[fg=#0f1c1e]#[bg=#0f1c1e]#[nobold]#[nounderscore]#[noitalics]#{?#{==:#{@claude-state},running},#[fg=#3e6676]#[bg=#0f1c1e]#[bold]#[nounderscore]#[noitalics]#{@claude-spinner} #I  #W ,#{?#{==:#{@claude-state},input},#[fg=#a18056]#[bg=#0f1c1e]#[nobold]#[nounderscore]#[noitalics]? #I  #W ,#{?#{==:#{@claude-state},permission},#[fg=#a24038]#[bg=#0f1c1e]#[bold]#[nounderscore]#[noitalics]! #I  #W ,#{?#{==:#{@claude-state},done},#[fg=#557270]#[bg=#0f1c1e]#[nobold]#[nounderscore]#[noitalics]✓ #I  #W ,#[fg=#587b7b]#[bg=#0f1c1e]#[nobold]#[nounderscore]#[noitalics]  #I  #W }}}}#[fg=#0f1c1e]#[bg=#0f1c1e]#[nobold]#[nounderscore]#[noitalics]'
FMT_CURRENT='#[fg=#0f1c1e]#[bg=#0f1c1e]#[nobold]#[noitalics]#{?#{==:#{@claude-state},running},#[fg=#5a93aa]#[bg=#0f1c1e]#[bold]#[noitalics]#{@claude-spinner} #I  #W ,#{?#{==:#{@claude-state},input},#[fg=#e6b87b]#[bg=#0f1c1e]#[nobold]#[noitalics]? #I  #W ,#{?#{==:#{@claude-state},permission},#[fg=#e85c51]#[bg=#0f1c1e]#[bold]#[noitalics]! #I  #W ,#{?#{==:#{@claude-state},done},#[fg=#7aa4a1]#[bg=#0f1c1e]#[nobold]#[noitalics]✓ #I  #W ,#[fg=#5a93aa]#[bg=#0f1c1e]#[bold]#[noitalics]  #I  #W }}}}#[fg=#0f1c1e]#[bg=#0f1c1e]#[nobold]#[noitalics]'

COLS="${1:-140}"
ROWS="${2:-3}"

# Five windows to fill the status bar
tmux new-session  -d -s "$SESSION" -n "claude-hooks" -x "$COLS" -y "$ROWS"
tmux new-window      -t "$SESSION" -n "api-server"
tmux new-window      -t "$SESSION" -n "payments"
tmux new-window      -t "$SESSION" -n "auth"
tmux new-window      -t "$SESSION" -n "frontend"

# Session-scoped options — no -g so they die with the session, don't bleed into other sessions
tmux set-option -t "$SESSION" status-bg    "#0f1c1e"
tmux set-option -t "$SESSION" status-fg    "#5a93aa"
tmux set-option -t "$SESSION" status-left  "#[fg=#2f3239,bg=#5a93aa,bold] demo #[fg=#5a93aa,bg=#0f1c1e,nobold] "
tmux set-option -t "$SESSION" status-right        "#[fg=#0f1c1e,bg=#0f1c1e] "
tmux set-option -t "$SESSION" status-right-length 2
tmux set-option -t "$SESSION" status-right-style  "bg=#0f1c1e,fg=#0f1c1e"

# Window-scoped options set per window — no -g so global format strings are never touched
for win in claude-hooks api-server payments auth frontend; do
    tmux set-window-option -t "${SESSION}:${win}" window-status-separator    ""
    tmux set-window-option -t "${SESSION}:${win}" window-status-format         "$FMT"
    tmux set-window-option -t "${SESSION}:${win}" window-status-current-format "$FMT_CURRENT"
done

# Pre-set state on other windows so the bar shows variety from the start
tmux set-option -w -t "${SESSION}:api-server" @claude-state "done"
tmux set-option -w -t "${SESSION}:payments"   @claude-state "running"
tmux set-option -w -t "${SESSION}:payments"   @claude-spinner "⬡"
tmux set-option -w -t "${SESSION}:auth"        @claude-state ""
tmux set-option -w -t "${SESSION}:frontend"    @claude-state "input"
tmux refresh-client -t "$SESSION" -S 2>/dev/null || true

# Focus window 1 for the demo
tmux select-window -t "${SESSION}:claude-hooks"

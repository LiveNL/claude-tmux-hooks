#!/bin/bash
# Returns one braille spinner frame based on the current second.
# Called via #() in the tmux window-status-format string.
frames=(⬢ ⬡)
printf '%s' "${frames[$(( $(date +%s) % ${#frames[@]} ))]}"

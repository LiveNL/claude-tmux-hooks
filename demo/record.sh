#!/bin/bash
# Records the demo by screenshotting the real tmux status bar.
# Run from the repo root: bash demo/record.sh
#
# Requires: ffmpeg  (brew install ffmpeg)
# Uses:     screencapture + swift (built-in macOS, no extra installs)

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
FRAMES="$(mktemp -d)"
ALACRITTY_CFG="$FRAMES/alacritty.toml"
OUT="$REPO/screenshots/demo.gif"
SESSION=vhsdemo
COLS=140
ROWS=5

cleanup() {
    tmux kill-session -t "$SESSION" 2>/dev/null || true
    # Restore global tmux config in case any option leaked
    tmux source "$HOME/.tmux.conf" 2>/dev/null || true
    rm -rf "$FRAMES"
}
trap cleanup EXIT

# ── 0. Preflight ──────────────────────────────────────────────────────────────
if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "error: ffmpeg not found — install with: brew install ffmpeg" >&2; exit 1
fi
if ! command -v alacritty >/dev/null 2>&1; then
    echo "error: alacritty not found in PATH" >&2; exit 1
fi

# ── 1. Set up demo tmux session ───────────────────────────────────────────────
tmux kill-session -t "$SESSION" 2>/dev/null || true
sleep 0.3
bash "$REPO/demo/setup.sh" "$COLS" "$ROWS"

# ── 2. Open a minimal Alacritty window and attach ────────────────────────────
cat > "$ALACRITTY_CFG" << 'TOML'
[window]
decorations = "None"
dimensions  = { columns = 140, lines = 5 }
padding     = { x = 0, y = 0 }

[font]
size = 13.0

[font.normal]
family = "LiterationMono Nerd Font"
style  = "Book"
TOML

alacritty --config-file "$ALACRITTY_CFG" \
    -e bash -c "tmux attach -t ${SESSION}" &
ALACRITTY_PID=$!
sleep 2.0  # let window open and tmux attach

# Clear shell startup noise from the pane
tmux send-keys -t "${SESSION}:claude-hooks" "clear" Enter
sleep 0.3

# ── 3. Locate the demo Alacritty window by PID ───────────────────────────────
cat > "$FRAMES/find_window.swift" << 'SWIFT'
import CoreGraphics
import Foundation
let targetPID = Int32(CommandLine.arguments[1]) ?? 0
for _ in 0..<25 {
    if let list = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
    ) as? [[String: Any]] {
        for window in list {
            guard let pid    = window["kCGWindowOwnerPID"] as? Int32, pid == targetPID,
                  let bounds = window["kCGWindowBounds"]  as? [String: Any],
                  let x      = bounds["X"]      as? Double,
                  let y      = bounds["Y"]      as? Double,
                  let width  = bounds["Width"]  as? Double,
                  let height = bounds["Height"] as? Double,
                  width > 0
            else { continue }
            print("\(Int(x)) \(Int(y)) \(Int(width)) \(Int(height))")
            exit(0)
        }
    }
    Thread.sleep(forTimeInterval: 0.2)
}
exit(1)
SWIFT

WIN_BOUNDS=$(swift "$FRAMES/find_window.swift" "$ALACRITTY_PID" 2>/dev/null) || {
    echo "error: could not locate demo Alacritty window (PID $ALACRITTY_PID)" >&2
    echo "hint:  ensure Xcode CLI tools are installed: xcode-select --install" >&2
    exit 1
}
read -r WIN_X WIN_Y WIN_W WIN_H <<< "$WIN_BOUNDS"
echo "window bounds: ${WIN_X},${WIN_Y},${WIN_W},${WIN_H}"

# ── 4. Capture frames ─────────────────────────────────────────────────────────
CONCAT="$FRAMES/concat.txt"
: > "$CONCAT"
N=0

# Crop to the status bar: bottom row of a 5-line window (bottom 1/5 of height)
CROP="crop=iw:ih/5:0:4*ih/5"
SCALE="${WIN_W}:-2"

capture() {
    local dur="$1"
    N=$((N + 1))
    local f="$FRAMES/$(printf '%04d' $N).png"
    tmux refresh-client -t "$SESSION" -S 2>/dev/null || true
    sleep 0.25  # wait for terminal to re-render
    screencapture -x -R "${WIN_X},${WIN_Y},${WIN_W},${WIN_H}" "$f"
    printf 'file %s\nduration %s\n' "$f" "$dur" >> "$CONCAT"
}

# Set state on any named window
set_win() {
    local win="$1" state="$2" spinner="${3:-}"
    tmux set-option -w -t "${SESSION}:${win}" @claude-state  "$state"  2>/dev/null || true
    tmux set-option -w -t "${SESSION}:${win}" @claude-spinner "$spinner" 2>/dev/null || true
}

# ── Animation ─────────────────────────────────────────────────────────────────
# Initial: claude-hooks=idle, api-server=done, payments=running, auth=idle, frontend=input
capture 1.5

# Payments finishes while frontend keeps waiting for user input
set_win "payments" "done"       "";  capture 1.0

# claude-hooks starts a new Claude session — spinner animates
set_win "claude-hooks" "running" "⬢"; capture 0.8
set_win "claude-hooks" "running" "⬡"; capture 0.8
set_win "claude-hooks" "running" "⬢"; capture 0.8
set_win "claude-hooks" "running" "⬡"; capture 0.8

# claude-hooks needs permission to run a command; api-server also kicks off a task
set_win "api-server"   "running" "⬢"
set_win "claude-hooks" "permission" "";  capture 2.0

# User clicks the notification → focuses terminal, responds to frontend question too
set_win "frontend" "running" "⬡"
set_win "claude-hooks" "input" "";  capture 1.8

# All three resume running — spinners tick in sync
set_win "claude-hooks" "running" "⬢"; set_win "frontend" "running" "⬢"; set_win "api-server" "running" "⬢"; capture 0.8
set_win "claude-hooks" "running" "⬡"; set_win "frontend" "running" "⬡"; set_win "api-server" "running" "⬡"; capture 0.8
set_win "claude-hooks" "running" "⬢"; set_win "frontend" "running" "⬢"; set_win "api-server" "running" "⬢"; capture 0.8

# claude-hooks finishes first
set_win "claude-hooks" "done" "";  capture 1.8

# frontend and api-server finish
set_win "frontend" "done" ""; set_win "api-server" "done" "";  capture 1.2

# Everything settles back to idle
set_win "claude-hooks" "" ""; set_win "frontend" "" ""; set_win "api-server" "" "";  capture 1.5

# ffmpeg concat requires the last frame to be duplicated for its duration to apply
printf 'file %s\nduration 0.1\n' "$FRAMES/$(printf '%04d' $N).png" >> "$CONCAT"

# ── 4a. Per-state screenshots for README ─────────────────────────────────────
# Kill all windows except claude-hooks so each screenshot shows only that one tab
for win in api-server payments auth frontend; do
    tmux kill-window -t "${SESSION}:${win}" 2>/dev/null || true
done

snap() {
    local name="$1"
    tmux refresh-client -t "$SESSION" -S 2>/dev/null || true
    sleep 0.25
    local raw="$FRAMES/snap.png"
    screencapture -x -R "${WIN_X},${WIN_Y},${WIN_W},${WIN_H}" "$raw"
    ffmpeg -y -i "$raw" -vf "${CROP}" "$REPO/screenshots/state-${name}.png" 2>/dev/null
}

set_win "claude-hooks" ""           ""; snap "idle"
set_win "claude-hooks" "running"    "⬢"; snap "running"
set_win "claude-hooks" "permission" ""; snap "permission"
set_win "claude-hooks" "input"      ""; snap "input"
set_win "claude-hooks" "done"       ""; snap "done"

# ── 5. Close Alacritty ────────────────────────────────────────────────────────
tmux kill-session -t "$SESSION" 2>/dev/null || true
wait "$ALACRITTY_PID" 2>/dev/null || true

# ── 6. Two-pass GIF encode ────────────────────────────────────────────────────
echo "Rendering GIF…"
PALETTE="$FRAMES/palette.png"

ffmpeg -y -f concat -safe 0 -i "$CONCAT" \
    -vf "fps=10,scale=${SCALE}:flags=lanczos,${CROP},palettegen=stats_mode=full" \
    "$PALETTE" 2>/dev/null

ffmpeg -y -f concat -safe 0 -i "$CONCAT" -i "$PALETTE" \
    -filter_complex "[0:v]fps=10,scale=${SCALE}:flags=lanczos,${CROP}[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
    "$OUT" 2>/dev/null

echo "Done → $OUT"
echo "State screenshots → screenshots/state-*.png"

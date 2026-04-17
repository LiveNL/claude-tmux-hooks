#!/bin/bash
# Captures macOS notification screenshots for the README.
# Run from the repo root: bash demo/capture-notifications.sh
#
# Requires: alerter (brew install vjeantet/tap/alerter)
# Uses:     screencapture + swift (built-in macOS)

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v alerter >/dev/null 2>&1; then
    echo "error: alerter not found — install with: brew install vjeantet/tap/alerter" >&2; exit 1
fi

# ── Get logical screen width to locate the notification drop zone ──────────────
SWIFT_TMP=$(mktemp /tmp/screen_dim.XXXX.swift)
cat > "$SWIFT_TMP" << 'SWIFT'
import CoreGraphics
let b = CGDisplayBounds(CGMainDisplayID())
print("\(Int(b.width)) \(Int(b.height))")
SWIFT
read -r SCREEN_W SCREEN_H < <(swift "$SWIFT_TMP" 2>/dev/null)
rm -f "$SWIFT_TMP"

# macOS banner notifications: ~360px wide, ~8px from top-right
NOTIF_W=375
NOTIF_H=115
NOTIF_X=$((SCREEN_W - NOTIF_W - 8))
NOTIF_Y=8

echo "screen: ${SCREEN_W}x${SCREEN_H}, capture at: ${NOTIF_X},${NOTIF_Y},${NOTIF_W},${NOTIF_H}"

# ── Fire notification, wait for it to appear, capture, wait for dismiss ────────
fire() {
    local name="$1" subtitle="$2" msg="$3"

    alerter \
        --title "claude-tmux-hooks" \
        --subtitle "$subtitle" \
        --message "$msg" \
        --sound "Sosumi" \
        --timeout 6 >/dev/null 2>&1 &
    local pid=$!

    sleep 1.8  # wait for banner to fully animate in
    screencapture -x -R "${NOTIF_X},${NOTIF_Y},${NOTIF_W},${NOTIF_H}" \
        "$REPO/screenshots/${name}.png"

    wait "$pid" 2>/dev/null || true
    sleep 0.5   # brief pause before next notification
    echo "→ screenshots/${name}.png"
}

fire "notification-permission" "🔑 Permission"   "Run: bash scripts/migrate.sh"
fire "notification-input"      "💬 Input needed"  "Should I also update the tests?"

echo "Done"

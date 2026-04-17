#!/bin/bash
# Captures macOS notification screenshots for the README.
# Run from the repo root: bash demo/capture-notifications.sh
#
# Requires: alerter (brew install vjeantet/tap/alerter)
# Uses:     screencapture + swift + python3 (built-in macOS)

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

if ! command -v alerter >/dev/null 2>&1; then
    echo "error: alerter not found — install with: brew install vjeantet/tap/alerter" >&2; exit 1
fi

# ── Screen geometry and menu-bar height ───────────────────────────────────────
cat > "$TMP/geom.swift" << 'SWIFT'
import CoreGraphics
import Foundation

let screen = CGDisplayBounds(CGMainDisplayID())
var menuBarH = 25

if let list = CGWindowListCopyWindowInfo(
    [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
) as? [[String: Any]] {
    for w in list {
        guard let owner  = w["kCGWindowOwnerName"] as? String, owner == "Window Server",
              let bounds = w["kCGWindowBounds"]    as? [String: Any],
              let h      = bounds["Height"] as? Double,
              let ww     = bounds["Width"]  as? Double,
              h < 80, ww > 800
        else { continue }
        menuBarH = Int(h)
        break
    }
}
// Notifications drop just below the menu bar on the right
let capX = Int(screen.width) - 420
let capY = menuBarH
let capW = 420
let capH = 160
print("\(capX) \(capY) \(capW) \(capH)")
SWIFT
read -r CAP_X CAP_Y CAP_W CAP_H < <(swift "$TMP/geom.swift" 2>/dev/null)
echo "capture region: ${CAP_X},${CAP_Y} ${CAP_W}x${CAP_H}"

# ── Pixel-diff helper: find bounding box of changed pixels ────────────────────
cat > "$TMP/bbox.py" << 'PY'
import sys, struct, zlib

def decode_png(path):
    data = open(path, "rb").read()
    pos = 8
    idat = b""
    w = h = depth = colortype = 0
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos+4])[0]
        ctype  = data[pos+4:pos+8]
        chunk  = data[pos+8:pos+8+length]
        if ctype == b"IHDR":
            w, h = struct.unpack(">II", chunk[:8])
            depth, colortype = chunk[8], chunk[9]
        elif ctype == b"IDAT":
            idat += chunk
        pos += 12 + length
    raw = zlib.decompress(idat)
    ch = {0:1, 2:3, 3:1, 4:2, 6:4}[colortype]
    stride = 1 + w * ch
    pixels = []
    for row in range(h):
        filt = raw[row*stride]
        rb = bytearray(raw[row*stride+1:(row+1)*stride])
        prev = pixels[-1] if row > 0 else bytes(len(rb))
        if filt == 1:
            for i in range(ch, len(rb)):
                rb[i] = (rb[i] + rb[i-ch]) & 0xFF
        elif filt == 2:
            for i in range(len(rb)):
                rb[i] = (rb[i] + prev[i]) & 0xFF
        elif filt == 3:
            for i in range(len(rb)):
                a = rb[i-ch] if i >= ch else 0
                rb[i] = (rb[i] + (a + prev[i]) // 2) & 0xFF
        elif filt == 4:
            for i in range(len(rb)):
                a = rb[i-ch] if i >= ch else 0
                b, c = prev[i], (prev[i-ch] if i >= ch else 0)
                p = a + b - c
                pr = a if abs(p-a) <= abs(p-b) and abs(p-a) <= abs(p-c) else (b if abs(p-b) <= abs(p-c) else c)
                rb[i] = (rb[i] + pr) & 0xFF
        pixels.append(bytes(rb))
    return w, h, ch, pixels

w, h, ch, bef = decode_png(sys.argv[1])
_,  _,  _, aft = decode_png(sys.argv[2])

x1, y1, x2, y2 = w, h, 0, 0
for y in range(h):
    for x in range(w):
        if any(bef[y][x*ch+c] != aft[y][x*ch+c] for c in range(min(ch,3))):
            x1 = min(x1, x); x2 = max(x2, x)
            y1 = min(y1, y); y2 = max(y2, y)

if x2 == 0:
    sys.exit(1)

PAD = 12
print(max(0,x1-PAD), max(0,y1-PAD), min(w,x2+PAD+1), min(h,y2+PAD+1))
PY

# ── Fire notification, diff, crop to exact bounds ─────────────────────────────
fire() {
    local name="$1" subtitle="$2" msg="$3"

    screencapture -x -R "${CAP_X},${CAP_Y},${CAP_W},${CAP_H}" "$TMP/before.png"

    alerter \
        --title "claude-tmux-hooks" \
        --subtitle "$subtitle" \
        --message "$msg" \
        --sound "Sosumi" \
        --timeout 6 >/dev/null 2>&1 &
    local pid=$!

    sleep 1.8
    screencapture -x -R "${CAP_X},${CAP_Y},${CAP_W},${CAP_H}" "$TMP/after.png"

    read -r bx1 by1 bx2 by2 < <(python3 "$TMP/bbox.py" "$TMP/before.png" "$TMP/after.png")
    local cw=$((bx2 - bx1)) ch=$((by2 - by1))
    echo "  notification at: ${bx1},${by1} ${cw}x${ch} (within capture region)"

    ffmpeg -y -i "$TMP/after.png" \
        -vf "crop=${cw}:${ch}:${bx1}:${by1}" \
        "$REPO/screenshots/${name}.png" 2>/dev/null

    wait "$pid" 2>/dev/null || true
    sleep 0.5
    echo "→ screenshots/${name}.png"
}

fire "notification-permission" "🔑 Permission"   "Run: bash scripts/migrate.sh"
fire "notification-input"      "💬 Input needed"  "Should I also update the tests?"

echo "Done"

# claude-tmux-hooks

Claude Code lifecycle hooks that show per-window status indicators in your tmux tab bar.

Each tmux window running Claude gets a small prefix glyph that updates in real time:

| State | Prefix | Color | When |
|-------|--------|-------|------|
| running | `·` | cyan/teal | Claude is executing a tool |
| input | `?` | amber | Claude needs your response |
| permission | `!` | red | Claude needs approval to run a command |
| done | `✓` | green | Claude finished (no question asked) |
| *(idle)* | — | dim | No active Claude session |

Works via [Claude Code hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) — no polling, no background processes.

## Requirements

- [tmux](https://github.com/tmux/tmux) ≥ 3.0
- [jq](https://stedolan.github.io/jq/)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI

macOS desktop notifications are supported automatically via `osascript`. On other platforms they are silently skipped.

## Install

```bash
git clone https://github.com/yourusername/claude-tmux-hooks
cd claude-tmux-hooks
bash install.sh
```

The installer:
1. Copies the three hook scripts to `~/.claude/hooks/`
2. Merges the hook configuration into `~/.claude/settings.json` (backs up first, preserves existing hooks)
3. Prints instructions for the tmux step below

## tmux setup

The installer prints this, but for reference — add one of these to your `~/.tmux.conf`:

**Option A — standalone format** (replaces `window-status-format`):
```tmux
source-file /path/to/claude-tmux-hooks/tmux/claude-state.conf
```

**Option B — embed in your existing format** (if you have a custom theme):
Prepend the `#{?...}` fragment from `tmux/claude-state-prefix.txt` to the start of your existing `window-status-format` and `window-status-current-format` strings.

Then reload: `tmux source-file ~/.tmux.conf`

## How it works

Claude Code fires hook scripts on lifecycle events. Each hook updates a per-window tmux option (`@claude-state`), which the `window-status-format` string reads to render the prefix glyph.

```
UserPromptSubmit / PreToolUse  →  busy-window.sh   →  @claude-state = "running"
Stop / Notification            →  notify.sh         →  @claude-state = "input" | "done" | "permission"
SessionStart                   →  reset-window.sh   →  @claude-state = ""
```

The `@claude-state` option is window-scoped, so each tmux window tracks its own Claude session independently.

## Customization

**Colors:** Edit `tmux/claude-state.conf` and replace the named colors (`cyan`, `yellow`, `red`, `green`) with hex values or tmux color names that match your theme. See `tmux/claude-state-prefix.txt` for the raw format string.

**Disable macOS notifications:** Remove or comment out the `notify_macos` calls in `hooks/notify.sh`, or set `CAN_NOTIFY="0"` at the top of the file.

**Add a notification sound on Linux:** Replace `notify_macos` with a call to `notify-send` or `paplay`.

## Uninstall

```bash
rm ~/.claude/hooks/busy-window.sh ~/.claude/hooks/notify.sh ~/.claude/hooks/reset-window.sh
```

Then remove the hooks block from `~/.claude/settings.json` (the five event entries added by the installer) and remove the `source-file` line from `~/.tmux.conf`.

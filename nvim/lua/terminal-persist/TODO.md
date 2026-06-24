# terminal-persist — known bugs

## Bug 1: scrollback stops at the nvim viewport

**Symptom:** Open a persistent terminal (e.g. `commands` via `<leader>tn`), run a
command that generates lots of output, and you can't scroll back in nvim past
what the viewport shows.

**Root cause:** Plain terminals run a shell *inside* tmux, and tmux paints its
pane onto nvim's terminal **alternate screen**. nvim only records scrollback for
the *main* screen, so alt-screen content never enters nvim's scrollback. The two
scrollbacks are separate buffers and can't stay continuously in sync:

- tmux history (the complete record, `history-limit 50000`, `strategies.lua`) —
  source of truth.
- nvim terminal scrollback — only holds the one-time `capture-pane -S -10000`
  dump from `tmux-attach-with-history.sh` (printed before `exec tmux attach`, on
  the main screen) **plus the current viewport**. New output drawn after attach
  scrolls off into tmux history, invisible to nvim's normal-mode scroll.

This is the same limitation `claude-wrapper.sh` documents (lines 6-10) and dodges
via its "tmux dance" (detach tmux, run on main screen, reattach). Compounding it:
`tmux/tmux.conf` has `mouse off`, so the wheel doesn't drive tmux copy-mode either.

**Mental model:** tmux owns the truth; nvim holds a snapshot of it. They agree
only at the instant of a dump, then drift.

**Fix options:**
- [ ] On-demand re-dump keybind: re-run `capture-pane -S -50000` into the nvim
      buffer when requested, giving nvim-native scroll/search. Keeps persistence.
      (Preferred — matches "I want to scroll/search in nvim".)
- [ ] `set -g mouse on` so the wheel scrolls tmux copy-mode history. Quick, but
      scrollback stays in tmux (no nvim search/yank).
- [ ] Continuous sync by disabling tmux's alt-screen (`smcup@:rmcup@` override) —
      rejected: per-second Dracula status bar + pane redraws smear garbage into
      nvim's scrollback.

## Done: yanked commands carried wrap-newlines (split on paste)

**Was:** Yanking a wrapped command from one terminal's scrollback and pasting it
into another split the command — nvim stores the terminal grid row-by-row, so a
command wider than the pane becomes multiple buffer lines with a hard `\n` at the
wrap column. Pasting into a shell ran the first line early.

**Fix:** `dewrap_yank` (a `TextYankPost` hook in `init.lua`). On a *multi-line*
yank in a managed terminal it rejoins the command via two strategies:

1. **tmux** (`dewrap_via_tmux`) — for plain terminals whose content lives in the
   tmux pane: `capture-pane -J` (tmux knows the real wrap points), anchored on the
   first and last selected rows, replacing the register with the rejoined line.
2. **grid width** (`dewrap_via_grid`) — claude (`a_*`) terminals run *outside*
   tmux via the wrapper's detach dance, so their output lives in nvim's own grid
   and the tmux pane is empty. Reconstruct from the grid: a row filling the full
   terminal width is a soft-wrap continuation (concatenate, no separator); a
   shorter row ends a real line. Uses the full buffer lines of the `'[`..`']`
   region so width detection sees whole rows.

Single-line yanks, and either strategy finding nothing, fall through to the native
wrapped yank — never worse than before, and the grid path fails *safe* (an
unrecognised break stays split, never a silent merge). Native `y`/motions are
untouched (no remap). Residual risk: a real line that is *exactly* terminal-width
could be glued to the next — uncommon in command output.

## Bug 2: claude session IDs restore under the wrong terminal (swap)

**Symptom:** Close nvim with several `a_*` claude terminals open, reopen, and the
wrong claude session ID restores under the wrong terminal name — IDs look swapped.

**Root cause:** `claude_session_id` lives in one shared JSON file
(`.nvim/terminal-sessions.json`) mutated by **non-atomic read-modify-write from
multiple independent processes**:

- nvim Lua `write_state` (`init.lua` — `M.new` and the `BufDelete` cleanup).
- every claude wrapper's `jq … > tmp && mv` (`claude-wrapper.sh` lines 50, 104, 122).

Each writer rewrites the *whole* file. The `mv`/rename makes each individual
write atomic against torn reads, but there's **no lock across read→modify→write**.
When several wrappers (and nvim) touch the file near-simultaneously — e.g. one
claude exits gracefully (`--cleanup`) while another starts, or nvim's BufDelete
cleanup fires during a wrapper write — a stale snapshot gets written back and
reverts another session's `claude_session_id` (classic lost update). On the next
restore the wrong ID sits under the wrong session name.

**Fix options:**
- [ ] Per-session ID files: move `claude_session_id` out of the shared JSON into
      `.nvim/claude-sessions/<session>`. No two processes ever write the same
      file → race eliminated, no locking needed. nvim keeps owning the JSON for
      name/strategy/log (it's single-threaded so never races itself). Touches the
      wrapper (write/read/cleanup) and restore. (Preferred.)
- [ ] `flock` every state mutation. Smaller surface, but nvim's Lua writes must
      also route through the lock, which is awkward.

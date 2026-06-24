# phone-term

A specialized phone interface for the terminals you run claude in.

Your `terminal-persist` setup backs every nvim terminal with a **tmux session**, so
each "terminal" is already a thing that can be read, resized, and written from outside.
phone-term is a tiny [Deno](https://deno.com) server that bridges those sessions to a
mobile [xterm.js](https://xtermjs.org) PWA over your tailnet:

- **Read the buffer** — a `tmux -C` (control mode) client streams the active pane's
  output to the browser in real time.
- **Reformat to the phone** — the browser reports its size; the server runs
  `refresh-client -C <cols>x<rows>`, so claude/vim re-render at the phone's width.
  tmux's `window-size latest` (default since 2.9) means the phone owning the size
  doesn't squish your desktop nvim — focus there and it reclaims full width.
- **Send input back** — keystrokes go back as `send-keys -H` (raw hex bytes, so
  arrows / ctrl / paste all work).
- **Switch terminals** — the top-right dropdown lists `tmux` sessions, grouped by
  project (parent) with the `terminal-persist` `_<hex>_<label>` sub-sessions under them.

## Files

| Path | What |
|------|------|
| `server.ts` | The bridge: static serving, `/api/sessions`, `/ws` control-mode proxy |
| `public/index.html` | xterm.js PWA — terminal, session switcher, mobile key-bar (esc/tab/ctrl/arrows) |
| `public/manifest.webmanifest`, `sw.js`, `icon.svg` | PWA install assets |
| `deno.json` | `deno task start` + lib config |

## Run

Installed as a user service (see `arch/systemd/user/phone-term.service`):

```sh
cd ~/.config/arch && just bin && just systemd-symlinks && just systemd-user
systemctl --user start phone-term
```

Or run it directly for development:

```sh
cd ~/.config/phone-term && deno task start
```

It listens on `127.0.0.1:8787`.

## Expose over the tailnet

`tailscale serve` puts it behind HTTPS on your tailnet only (not the public internet —
that would be `tailscale funnel`). HTTPS is what makes it installable as a PWA.

```sh
# one-time; persists across reboots
tailscale serve --bg 8787
tailscale serve status   # shows the https://<machine>.<tailnet>.ts.net URL
```

Open that URL on your phone → **Add to Home Screen** for an app-like, full-screen view.

If `tailscale serve` complains about permissions, set yourself as operator once:
`sudo tailscale set --operator=$USER`.

## Notes / limits

- One session is viewed per tab; switching reconnects the WebSocket. The switcher
  auto-refreshes every 5s.
- The seed is `capture-pane` of the current screen; live output corrects the rest.
- MVP parses only `%output` from control mode — enough for a single-window session,
  which is what `terminal-persist` creates. Multi-window sessions would need
  `%window-add` / `%layout-change` handling.

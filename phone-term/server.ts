// phone-term — mobile bridge to tmux sessions via control mode.
//
// Each browser tab opens a WebSocket for one tmux session. The server spawns a
// dedicated `tmux -C attach` (control mode) client for it, streams that pane's
// %output to the browser's xterm.js, and pipes keystrokes back via `send-keys`.
// Resizing the browser resizes the tmux client (`refresh-client -C`), so the
// program (claude, vim, …) re-renders at the phone's width. window-size is
// `latest` by default in tmux ≥2.9, so the phone owning the size doesn't squish
// the desktop nvim client — focus there and it reclaims full width.
//
// Run: deno run --allow-net --allow-run=tmux --allow-read server.ts
// Then expose over the tailnet: tailscale serve --bg http://localhost:8787

const PORT = Number(Deno.env.get("PHONE_TERM_PORT") ?? 8787);
const HOST = Deno.env.get("PHONE_TERM_HOST") ?? "127.0.0.1";
const PUBLIC = new URL("./public/", import.meta.url);

const dec = new TextDecoder();
const enc = new TextEncoder();

// Run a one-shot tmux command against the server (TMUX="" => not nested).
async function tmux(args: string[]): Promise<string> {
  const { stdout } = await new Deno.Command("tmux", {
    args,
    env: { TMUX: "" },
    stdout: "piped",
    stderr: "null",
  }).output();
  return dec.decode(stdout);
}

// List sessions, parsing terminal-persist's <parent>_<6hex>_<label> convention
// so the switcher can group + label them nicely.
async function listSessions() {
  const fmt = "#{session_name}\t#{session_attached}\t#{session_activity}\t#{pane_current_command}";
  const out = await tmux(["list-sessions", "-F", fmt]);
  return out
    .trimEnd()
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const [name, attached, activity, cmd] = line.split("\t");
      const m = name.match(/^(.*)_[0-9a-f]{6}_(.*)$/);
      return {
        name,
        parent: m ? m[1] : name,
        label: m ? m[2] : "main",
        attached: attached !== "0",
        activity: Number(activity) || 0,
        command: cmd ?? "",
      };
    })
    .sort((a, b) =>
      a.parent === b.parent
        ? a.label.localeCompare(b.label)
        : a.parent.localeCompare(b.parent)
    );
}

// tmux %output escapes non-printables as octal (\ooo) and backslash as \\.
// Decode back to raw bytes for xterm.js.
function unescapeOutput(s: string): Uint8Array {
  const out: number[] = [];
  for (let i = 0; i < s.length; i++) {
    if (s[i] === "\\") {
      const n = s[i + 1];
      if (n === "\\") {
        out.push(0x5c);
        i += 1;
      } else if (n >= "0" && n <= "7") {
        out.push(parseInt(s.substr(i + 1, 3), 8) & 0xff);
        i += 3;
      } else {
        out.push(0x5c);
      }
    } else {
      out.push(s.charCodeAt(i) & 0xff);
    }
  }
  return new Uint8Array(out);
}

function bridge(socket: WebSocket, session: string, cols: number, rows: number) {
  const child = new Deno.Command("tmux", {
    args: ["-C", "attach", "-t", session],
    env: { TMUX: "" },
    stdin: "piped",
    stdout: "piped",
    stderr: "null",
  }).spawn();

  const writer = child.stdin.getWriter();
  const send = (line: string) => writer.write(enc.encode(line + "\n")).catch(() => {});

  // Match this control client to the phone, then seed with the current screen.
  send(`refresh-client -C ${cols}x${rows}`);
  tmux(["capture-pane", "-p", "-e", "-t", session]).then((txt) => {
    if (socket.readyState === WebSocket.OPEN) {
      // home + clear, then paint the captured visible screen; live %output corrects the rest.
      socket.send(enc.encode("\x1b[H\x1b[2J" + txt.replaceAll("\n", "\r\n")));
    }
  });

  // Stream control-mode notifications -> browser (only %output for the MVP).
  (async () => {
    const reader = child.stdout.getReader();
    let buf = "";
    try {
      for (;;) {
        const { value, done } = await reader.read();
        if (done) break;
        buf += dec.decode(value, { stream: true });
        let nl: number;
        while ((nl = buf.indexOf("\n")) >= 0) {
          const line = buf.slice(0, nl);
          buf = buf.slice(nl + 1);
          if (line.startsWith("%output ")) {
            const rest = line.slice(8);
            const sp = rest.indexOf(" ");
            const data = sp >= 0 ? rest.slice(sp + 1) : "";
            if (socket.readyState === WebSocket.OPEN) socket.send(unescapeOutput(data));
          }
        }
      }
    } catch { /* child killed / stream torn down */ }
    if (socket.readyState === WebSocket.OPEN) socket.close();
  })();

  socket.onmessage = (ev) => {
    let msg: { type: string; data?: string; cols?: number; rows?: number };
    try {
      msg = JSON.parse(ev.data);
    } catch {
      return;
    }
    if (msg.type === "input" && msg.data != null) {
      const hex = Array.from(enc.encode(msg.data))
        .map((b) => b.toString(16).padStart(2, "0"))
        .join(" ");
      if (hex) send(`send-keys -t '${session}' -H ${hex}`);
    } else if (msg.type === "resize" && msg.cols && msg.rows) {
      send(`refresh-client -C ${msg.cols}x${msg.rows}`);
    }
  };

  let closed = false;
  const cleanup = () => {
    if (closed) return;
    closed = true;
    writer.close().catch(() => {}); // rejects if the stream is already closing — ignore
    try {
      child.kill();
    } catch { /* already gone */ }
  };
  socket.onclose = cleanup;
  socket.onerror = cleanup;
}

const TYPES: Record<string, string> = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".svg": "image/svg+xml",
  ".webmanifest": "application/manifest+json",
  ".json": "application/json",
};

Deno.serve({ port: PORT, hostname: HOST }, async (req) => {
  const url = new URL(req.url);

  if (url.pathname === "/ws") {
    const session = url.searchParams.get("session");
    if (!session) return new Response("missing session", { status: 400 });
    const cols = Number(url.searchParams.get("cols") ?? 80);
    const rows = Number(url.searchParams.get("rows") ?? 24);
    const { socket, response } = Deno.upgradeWebSocket(req);
    socket.binaryType = "arraybuffer";
    socket.onopen = () => bridge(socket, session, cols, rows);
    return response;
  }

  if (url.pathname === "/api/sessions") {
    return Response.json(await listSessions());
  }

  // Static files from ./public (no traversal: collapse and reject "..").
  let path = url.pathname === "/" ? "/index.html" : url.pathname;
  if (path.includes("..")) return new Response("bad path", { status: 400 });
  try {
    const file = await Deno.readFile(new URL("." + path, PUBLIC));
    const ext = path.slice(path.lastIndexOf("."));
    return new Response(file, { headers: { "content-type": TYPES[ext] ?? "application/octet-stream" } });
  } catch {
    return new Response("not found", { status: 404 });
  }
});

console.log(`phone-term on http://${HOST}:${PORT}`);

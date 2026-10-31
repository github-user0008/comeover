export interface DashboardStats {
  rooms: number;
  uptime: number;
  version: string;
  directPort: number;
}

/** The small status page Umbrel opens when you launch the app. */
export function dashboardHtml(stats: DashboardStats): string {
  const rooms = stats.rooms === 1 ? '1 active room' : `${stats.rooms} active rooms`;
  const uptime = formatUptime(stats.uptime);

  return `<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="dark">
<title>ComeOver relay</title>
<style>
  :root { color-scheme: dark; --ink:#f7f3ff; --muted:#b8b1c9; --line:rgba(255,255,255,.16); }
  * { box-sizing: border-box; }
  body { margin:0; min-height:100dvh; padding:clamp(18px,4vw,48px);
    font-family: ui-rounded, "SF Pro Rounded", "Segoe UI Variable", system-ui, sans-serif;
    background: radial-gradient(110% 80% at 10% 0%, #3d2a72 0%, #191322 50%, #0b0910 100%); color:var(--ink); }
  .halo { position:fixed; width:58vmax; height:58vmax; border-radius:50%; filter:blur(95px); opacity:.5; pointer-events:none; }
  .halo.a { background:#7c5cff; top:-28vmax; right:-16vmax; }
  .halo.b { background:#27d3e0; bottom:-34vmax; left:-22vmax; }
  main { position:relative; width:min(900px,100%); margin:0 auto; }
  .top { display:flex; align-items:center; justify-content:space-between; gap:16px; margin-bottom:clamp(28px,6vw,64px); }
  .brand { display:flex; align-items:center; gap:12px; font-weight:750; letter-spacing:-.02em; }
  .mark { width:42px; height:42px; display:grid; place-items:center; border-radius:14px; font-size:22px;
    background:linear-gradient(145deg,#d9c8ff,#9bf6ff); box-shadow:0 10px 28px rgba(155,246,255,.22), inset 0 1px 0 #fff; }
  .pill { display:inline-flex; align-items:center; gap:8px; padding:9px 13px; border-radius:999px;
    border:1px solid rgba(155,246,255,.32); background:rgba(155,246,255,.09); color:#c9fbff; font-size:12px; font-weight:700; }
  .dot { width:8px; height:8px; border-radius:50%; background:#6cf0c2; box-shadow:0 0 0 5px rgba(108,240,194,.13); }
  .glass { border:1px solid var(--line); border-radius:32px; background:linear-gradient(150deg,rgba(255,255,255,.14),rgba(255,255,255,.045));
    box-shadow:0 30px 80px rgba(0,0,0,.42), inset 0 1px 0 rgba(255,255,255,.38); backdrop-filter:blur(24px) saturate(1.5); }
  .hero { padding:clamp(24px,5vw,44px); }
  .eyebrow { margin:0 0 10px; color:#c9fbff; text-transform:uppercase; letter-spacing:.18em; font-size:11px; font-weight:700; }
  h1 { margin:0; font-size:clamp(32px,6vw,58px); line-height:1.03; letter-spacing:-.045em; max-width:13ch; }
  .lede { margin:18px 0 0; color:var(--muted); line-height:1.55; max-width:62ch; font-size:clamp(14px,1.7vw,17px); }
  .stats { display:grid; grid-template-columns:repeat(3,1fr); gap:10px; margin-top:26px; }
  .stat { padding:16px; border-radius:20px; background:rgba(10,8,15,.32); border:1px solid rgba(255,255,255,.11); }
  .stat b { display:block; font-size:clamp(17px,2.4vw,24px); letter-spacing:-.03em; }
  .stat span { display:block; margin-top:5px; color:var(--muted); font-size:12px; }
  .grid { display:grid; grid-template-columns:1.15fr .85fr; gap:14px; margin-top:14px; }
  section { padding:clamp(20px,3vw,30px); }
  h2 { margin:0 0 8px; font-size:19px; letter-spacing:-.02em; }
  p { color:var(--muted); line-height:1.55; font-size:14px; }
  .field { display:flex; gap:8px; margin-top:18px; }
  code { flex:1; min-width:0; overflow:auto; padding:14px 16px; border-radius:14px; color:#e9e2ff;
    background:rgba(8,6,13,.5); border:1px solid rgba(255,255,255,.14); font-size:13px; white-space:nowrap; }
  button { border:0; cursor:pointer; border-radius:14px; padding:0 16px; font:inherit; font-weight:750; color:#211436;
    background:linear-gradient(120deg,#d9c8ff,#a5f3fc); box-shadow:inset 0 1px 0 #fff; }
  button:focus-visible, input:focus-visible, a:focus-visible { outline:3px solid #9bf6ff; outline-offset:3px; }
  form { display:flex; gap:8px; margin-top:18px; }
  input { flex:1; min-width:0; padding:14px 16px; border-radius:14px; border:1px solid rgba(255,255,255,.18);
    background:rgba(8,6,13,.5); color:var(--ink); font:inherit; font-size:15px; text-transform:uppercase; letter-spacing:.14em; }
  ol { margin:16px 0 0; padding-left:20px; color:var(--muted); line-height:1.6; font-size:14px; }
  ol b { color:var(--ink); }
  a { color:#c9fbff; }
  footer { display:flex; flex-wrap:wrap; gap:10px 18px; justify-content:space-between; padding:22px 6px 0; color:var(--muted); font-size:12px; }
  .toast { min-height:18px; margin-top:10px; color:#9bf6ff; font-size:12px; }
  @media (max-width:720px) {
    .grid { grid-template-columns:1fr; }
    .stats { grid-template-columns:1fr 1fr; }
    .stats .stat:last-child { grid-column:span 2; }
    .top { align-items:flex-start; }
  }
  @media (prefers-reduced-motion:no-preference) {
    .glass { animation:rise .6s cubic-bezier(.2,.9,.2,1) both; }
    .grid .glass { animation-delay:.08s; }
    @keyframes rise { from { opacity:0; transform:translateY(14px) scale(.99); } }
  }
</style></head>
<body>
<div class="halo a"></div><div class="halo b"></div>
<main>
  <header class="top">
    <div class="brand"><span class="mark">🫂</span><span>ComeOver</span></div>
    <span class="pill"><span class="dot"></span> Relay online</span>
  </header>

  <div class="glass hero">
    <p class="eyebrow">Umbrel relay</p>
    <h1>Your doorbell for the last few minutes.</h1>
    <p class="lede">The relay is running. It carries room invites, live location, distance, ETA and
      the arrival countdown between the phones and TVs in a room. There is no account to create.</p>
    <div class="stats">
      <div class="stat"><b>${rooms}</b><span>Right now</span></div>
      <div class="stat"><b>${uptime}</b><span>Uptime</span></div>
      <div class="stat"><b>v${escapeHtml(stats.version)}</b><span>Relay version</span></div>
    </div>
  </div>

  <div class="grid">
    <section class="glass">
      <h2>Connect the app</h2>
      <p>In ComeOver, open <b>Settings → Relay</b> and paste this address. Use the same
        Tailscale hostname or IP you used to open Umbrel.</p>
      <div class="field">
        <code id="relay-url">http://localhost:${stats.directPort}</code>
        <button type="button" id="copy">Copy</button>
      </div>
      <div class="toast" id="copy-status" role="status"></div>
      <p style="margin-top:14px">This is the direct relay port, deliberately outside the Umbrel
        login so native apps and TVs can use Socket.IO. Keep it on your LAN or tailnet. If you set
        up Tailscale Serve, use its HTTPS hostname instead.</p>
    </section>

    <section class="glass">
      <h2>Open an invite</h2>
      <p>Paste a six-character room code to preview the guest invite page.</p>
      <form id="invite-form">
        <input id="code" name="code" inputmode="text" autocomplete="off" spellcheck="false"
          maxlength="10" pattern="[A-Za-z0-9]{4,10}" placeholder="ABC123" aria-label="Room code">
        <button type="submit">Open</button>
      </form>
      <ol>
        <li><b>Start a room</b> on the host phone or TV.</li>
        <li><b>Share the code</b> or invite link.</li>
        <li><b>Watch the map</b> until they reach the door.</li>
      </ol>
    </section>
  </div>

  <footer>
    <span>Rooms are in memory and expire after six hours.</span>
    <span><a href="/healthz">Health check</a> · <a href="/j/ABC123">Example invite</a></span>
  </footer>
</main>
<script>
(() => {
  const directPort = ${JSON.stringify(String(stats.directPort))};
  const relay = document.getElementById('relay-url');
  const copy = document.getElementById('copy');
  const status = document.getElementById('copy-status');
  const code = document.getElementById('code');
  const host = location.hostname;
  const address = location.port === directPort
    ? location.origin
    : 'http://' + host + ':' + directPort;
  relay.textContent = address;

  const say = (message) => {
    status.textContent = message;
    setTimeout(() => { if (status.textContent === message) status.textContent = ''; }, 2200);
  };

  copy.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(address);
      say('Copied. Paste it into Settings → Relay.');
    } catch {
      const range = document.createRange();
      range.selectNodeContents(relay);
      const selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      say('Selected — copy it with your keyboard.');
    }
  });

  document.getElementById('invite-form').addEventListener('submit', (event) => {
    event.preventDefault();
    const value = code.value.trim().toUpperCase();
    if (!/^[A-Z0-9]{4,10}$/.test(value)) {
      say('Use the 4–10 character code from the app.');
      code.focus();
      return;
    }
    location.href = '/j/' + encodeURIComponent(value);
  });
})();
</script>
</body></html>`;
}

function formatUptime(seconds: number): string {
  const total = Math.max(0, Math.floor(seconds));
  if (total < 60) return `${total}s`;
  const minutes = Math.floor(total / 60);
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h`;
  return `${Math.floor(hours / 24)}d`;
}

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (char) => {
    switch (char) {
      case '&':
        return '&amp;';
      case '<':
        return '&lt;';
      case '>':
        return '&gt;';
      case '"':
        return '&quot;';
      default:
        return '&#39;';
    }
  });
}

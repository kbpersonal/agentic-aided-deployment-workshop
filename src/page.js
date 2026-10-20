export function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function identityCard(identity) {
  if (!identity.authenticated) {
    return `
      <div class="identity empty">
        <div class="avatar">?</div>
        <div>
          <p class="eyebrow">Identity passport</p>
          <h2>No trusted identity forwarded</h2>
          <p>Direct requests are intentionally anonymous. Tailscale Serve adds identity at the private edge.</p>
        </div>
      </div>`;
  }

  const name = escapeHtml(identity.name);
  const login = escapeHtml(identity.login);
  const avatar = identity.profilePic
    ? `<img class="avatar" src="${escapeHtml(identity.profilePic)}" alt="">`
    : `<div class="avatar">${escapeHtml(identity.name.slice(0, 1).toUpperCase())}</div>`;

  return `
    <div class="identity">
      ${avatar}
      <div>
        <p class="eyebrow">Identity passport</p>
        <h2>${name}</h2>
        <p class="login">${login}</p>
        <span class="badge">via Tailscale</span>
      </div>
    </div>`;
}

export function renderPage({
  identity,
  hostname,
  timestamp,
  uptimeSeconds,
  version,
}) {
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Beyond localhost</title>
  <style>
    :root { --paper:#f1eadb; --ink:#18211d; --rust:#bd4c2e; --green:#167a55; --line:rgba(24,33,29,.18); }
    * { box-sizing:border-box; }
    body { margin:0; min-height:100vh; color:var(--ink); background-color:var(--paper); background-image:linear-gradient(var(--line) 1px,transparent 1px),linear-gradient(90deg,var(--line) 1px,transparent 1px); background-size:34px 34px; font-family:"Iowan Old Style","Palatino Linotype",Georgia,serif; }
    main { width:min(1120px,calc(100% - 32px)); margin:0 auto; padding:clamp(34px,7vw,92px) 0; animation:arrive .7s ease-out both; }
    .sheet { border:1px solid var(--ink); background:rgba(241,234,219,.94); box-shadow:12px 12px 0 var(--ink); }
    header { display:grid; grid-template-columns:1.55fr .45fr; border-bottom:1px solid var(--ink); }
    .intro { padding:clamp(28px,5vw,64px); }
    .stamp { display:grid; place-content:center; min-height:180px; border-left:1px solid var(--ink); color:var(--rust); font:700 14px/1.4 "Cascadia Mono","Courier New",monospace; text-transform:uppercase; letter-spacing:.18em; transform:rotate(-2deg); }
    .eyebrow { margin:0 0 16px; font:700 12px/1.4 "Cascadia Mono","Courier New",monospace; text-transform:uppercase; letter-spacing:.16em; }
    h1 { max-width:760px; margin:0; font-size:clamp(48px,8vw,108px); font-weight:500; line-height:.86; letter-spacing:-.055em; }
    .lede { max-width:690px; margin:28px 0 0; font-size:clamp(19px,2.2vw,27px); line-height:1.3; }
    .grid { display:grid; grid-template-columns:1.2fr .8fr; }
    .identity { min-height:310px; display:flex; gap:24px; align-items:center; padding:clamp(28px,5vw,56px); border-right:1px solid var(--ink); }
    .identity h2 { margin:0 0 5px; font-size:clamp(30px,4vw,54px); font-weight:500; line-height:1; }
    .identity p:not(.eyebrow) { max-width:520px; margin:8px 0; font-size:18px; }
    .avatar { width:88px; height:88px; flex:0 0 88px; border:1px solid var(--ink); border-radius:50%; display:grid; place-items:center; object-fit:cover; background:var(--ink); color:var(--paper); font-size:38px; }
    .badge { display:inline-block; margin-top:14px; padding:7px 10px; color:white; background:var(--green); font:700 11px/1 "Cascadia Mono","Courier New",monospace; text-transform:uppercase; letter-spacing:.1em; }
    dl { margin:0; display:grid; grid-template-columns:1fr; }
    dl div { padding:22px 28px; border-bottom:1px solid var(--ink); }
    dl div:last-child { border-bottom:0; }
    dt { margin-bottom:7px; font:700 10px/1.2 "Cascadia Mono","Courier New",monospace; text-transform:uppercase; letter-spacing:.15em; }
    dd { margin:0; overflow-wrap:anywhere; font:600 14px/1.4 "Cascadia Mono","Courier New",monospace; }
    .status { color:var(--green); }
    .status::before { content:""; display:inline-block; width:10px; height:10px; margin-right:8px; border-radius:50%; background:currentColor; box-shadow:0 0 0 5px rgba(22,122,85,.14); }
    footer { display:flex; justify-content:space-between; gap:20px; padding:18px 24px; border-top:1px solid var(--ink); font:600 11px/1.4 "Cascadia Mono","Courier New",monospace; text-transform:uppercase; letter-spacing:.08em; }
    @keyframes arrive { from { opacity:0; transform:translateY(18px); } }
    @media (max-width:760px) { header,.grid { grid-template-columns:1fr; } .stamp,.identity { border-left:0; border-right:0; border-top:1px solid var(--ink); } .identity { align-items:flex-start; } footer { flex-direction:column; } }
    @media (prefers-reduced-motion:reduce) { main { animation:none; } }
  </style>
</head>
<body>
  <main>
    <article class="sheet">
      <header>
        <div class="intro">
          <p class="eyebrow">Agentic deployment / field note 01</p>
          <h1>Beyond localhost.</h1>
          <p class="lede">Reachable by the team. Invisible to everyone else. Identity decides who; the diff records why.</p>
        </div>
        <div class="stamp">Private<br>by default</div>
      </header>
      <section class="grid">
        ${identityCard(identity)}
        <dl>
          <div><dt>Service</dt><dd class="status">Reachable</dd></div>
          <div><dt>Host</dt><dd>${escapeHtml(hostname)}</dd></div>
          <div><dt>Runtime</dt><dd>Node ${escapeHtml(version)}</dd></div>
          <div><dt>Uptime</dt><dd>${escapeHtml(uptimeSeconds)} seconds</dd></div>
          <div><dt>Accepted</dt><dd>${escapeHtml(timestamp)}</dd></div>
        </dl>
      </section>
      <footer><span>GET /health</span><span>No public URL. No shared password. No stored deploy key.</span></footer>
    </article>
  </main>
</body>
</html>`;
}

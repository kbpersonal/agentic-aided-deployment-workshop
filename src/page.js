export function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

const DOCS =
  "https://tailscale.com/docs/features/tailscale-serve#identity-headers";

function row(name, value) {
  return `<tr><th><code>${name}</code></th><td>${value ?? '<span class="none">not sent</span>'}</td></tr>`;
}

function identitySection(identity) {
  const avatar = identity.profilePic
    ? `<img class="avatar" src="${escapeHtml(identity.profilePic)}" alt="">`
    : `<div class="avatar">${identity.authenticated ? escapeHtml(identity.name.slice(0, 1).toUpperCase()) : "?"}</div>`;

  const summary = identity.authenticated
    ? `<h2>${escapeHtml(identity.name)}</h2><p>${escapeHtml(identity.login)}</p>`
    : `<h2>No identity headers</h2><p>Open this app through its Tailscale URL. Requests sent straight to the port, and requests from tagged devices, carry no identity.</p>`;

  return `
    <section>
      <div class="who">${avatar}<div>${summary}</div></div>
      <table>
        ${row("Tailscale-User-Login", identity.login && escapeHtml(identity.login))}
        ${row("Tailscale-User-Name", identity.authenticated ? escapeHtml(identity.name) : null)}
        ${row("Tailscale-User-Profile-Pic", identity.profilePic && escapeHtml(identity.profilePic))}
      </table>
      <p class="note">Tailscale Serve and the Tailscale Ingress add these headers and strip any copies the client sent. <a href="${DOCS}">Identity headers docs</a></p>
    </section>`;
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
  <title>Tailscale identity headers</title>
  <style>
    body { margin:0; background:#faf9f8; color:#1f1e1e; font:16px/1.5 system-ui,-apple-system,"Segoe UI",sans-serif; }
    main { max-width:760px; margin:0 auto; padding:48px 20px; }
    h1 { margin:0 0 24px; font-size:28px; font-weight:600; }
    section { background:#fff; border:1px solid #dad6d5; border-radius:12px; padding:24px; margin-bottom:20px; }
    .who { display:flex; gap:16px; align-items:center; margin-bottom:20px; }
    .who h2 { margin:0; font-size:22px; font-weight:600; }
    .who p { margin:2px 0 0; color:#706e6d; }
    .avatar { width:64px; height:64px; flex:0 0 64px; border-radius:50%; object-fit:cover; display:grid; place-items:center; background:#1f1e1e; color:#fff; font-size:26px; }
    table { width:100%; border-collapse:collapse; }
    th, td { text-align:left; vertical-align:top; padding:10px 0; border-top:1px solid #eeebea; overflow-wrap:anywhere; }
    th { width:45%; padding-right:16px; font-weight:400; }
    code { font:14px/1.4 ui-monospace,"SF Mono",Menlo,monospace; }
    .none { color:#afacab; }
    .note { margin:16px 0 0; color:#706e6d; font-size:14px; }
    a { color:#4b70cc; }
  </style>
</head>
<body>
  <main>
    <h1>Tailscale identity headers</h1>
    ${identitySection(identity)}
    <section>
      <table>
        <tr><th>Host</th><td><code>${escapeHtml(hostname)}</code></td></tr>
        <tr><th>Node.js</th><td><code>${escapeHtml(version)}</code></td></tr>
        <tr><th>Uptime</th><td>${escapeHtml(uptimeSeconds)} seconds</td></tr>
        <tr><th>Rendered at</th><td><code>${escapeHtml(timestamp)}</code></td></tr>
      </table>
    </section>
  </main>
</body>
</html>`;
}

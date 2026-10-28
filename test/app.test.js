import assert from "node:assert/strict";
import http from "node:http";
import test from "node:test";
import { createHandler } from "../src/app.js";

async function withServer(run) {
  const server = http.createServer(
    createHandler({
      hostname: "demo-host",
      now: () => new Date("2026-07-28T12:00:00.000Z"),
      uptime: () => 42,
      version: "24.0.0",
    }),
  );
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const { port } = server.address();
  try {
    await run(`http://127.0.0.1:${port}`);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

test("renders the deployment passport and security headers", async () =>
  withServer(async (base) => {
    const response = await fetch(base);
    const body = await response.text();
    assert.equal(response.status, 200);
    assert.match(body, /Beyond localhost/);
    assert.match(body, /No trusted identity forwarded/);
    assert.equal(response.headers.get("x-frame-options"), "DENY");
    assert.match(
      response.headers.get("content-security-policy"),
      /default-src 'none'/,
    );
  }));

test("renders and escapes a forwarded identity", async () =>
  withServer(async (base) => {
    const response = await fetch(base, {
      headers: {
        "Tailscale-User-Login": "raj@example.com",
        "Tailscale-User-Name": "<script>Raj</script>",
      },
    });
    const body = await response.text();
    assert.match(body, /&lt;script&gt;Raj&lt;\/script&gt;/);
    assert.doesNotMatch(body, /<script>Raj<\/script>/);
    assert.match(body, /via Tailscale/);
  }));

test("serves health, HEAD, 404, and 405 correctly", async () =>
  withServer(async (base) => {
    const health = await fetch(`${base}/health`);
    assert.deepEqual(await health.json(), {
      status: "ok",
      service: "agentic-aided-deployment-workshop",
      uptimeSeconds: 42,
    });

    const head = await fetch(base, { method: "HEAD" });
    assert.equal(await head.text(), "");

    assert.equal((await fetch(`${base}/missing`)).status, 404);
    const unsupported = await fetch(base, { method: "POST" });
    assert.equal(unsupported.status, 405);
    assert.equal(unsupported.headers.get("allow"), "GET, HEAD");
  }));

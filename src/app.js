import os from "node:os";
import process from "node:process";
import { readIdentity } from "./identity.js";
import { renderPage } from "./page.js";

const securityHeaders = {
  "cache-control": "no-store",
  "content-security-policy":
    "default-src 'none'; style-src 'unsafe-inline'; img-src https: data:; base-uri 'none'; frame-ancestors 'none'; form-action 'none'",
  "permissions-policy": "camera=(), microphone=(), geolocation=()",
  "referrer-policy": "no-referrer",
  "x-content-type-options": "nosniff",
  "x-frame-options": "DENY",
};

function send(response, status, headers, body, method) {
  response.writeHead(status, { ...securityHeaders, ...headers });
  response.end(method === "HEAD" ? undefined : body);
}

export function createHandler(options = {}) {
  const hostname = options.hostname || os.hostname();
  const now = options.now || (() => new Date());
  const uptime = options.uptime || (() => Math.floor(process.uptime()));
  const version = options.version || process.version.replace(/^v/, "");
  const trustIdentityHeaders = options.trustIdentityHeaders !== false;

  return function handler(request, response) {
    const method = request.method || "GET";
    if (!new Set(["GET", "HEAD"]).has(method)) {
      return send(
        response,
        405,
        {
          allow: "GET, HEAD",
          "content-type": "application/json; charset=utf-8",
        },
        JSON.stringify({ error: "method_not_allowed" }),
        method,
      );
    }

    const url = new URL(request.url || "/", "http://localhost");
    if (url.pathname === "/health") {
      const body = JSON.stringify({
        status: "ok",
        service: "agentic-aided-deployment-workshop",
        uptimeSeconds: uptime(),
      });
      return send(
        response,
        200,
        { "content-type": "application/json; charset=utf-8" },
        body,
        method,
      );
    }

    if (url.pathname !== "/") {
      return send(
        response,
        404,
        { "content-type": "application/json; charset=utf-8" },
        JSON.stringify({ error: "not_found" }),
        method,
      );
    }

    const identity = readIdentity(
      new Headers(request.headers),
      trustIdentityHeaders,
    );
    const body = renderPage({
      identity,
      hostname,
      timestamp: now().toISOString(),
      uptimeSeconds: uptime(),
      version,
    });
    return send(
      response,
      200,
      { "content-type": "text/html; charset=utf-8" },
      body,
      method,
    );
  };
}

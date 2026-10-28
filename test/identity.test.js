import assert from "node:assert/strict";
import test from "node:test";
import { readIdentity } from "../src/identity.js";

test("returns anonymous without a login", () => {
  assert.equal(readIdentity(new Headers()).authenticated, false);
});

test("normalizes a Tailscale identity", () => {
  const identity = readIdentity(
    new Headers({
      "Tailscale-User-Login": " raj@example.com ",
      "Tailscale-User-Name": " Raj Singh ",
      "Tailscale-User-Profile-Pic": "https://example.com/raj.png",
    }),
  );
  assert.deepEqual(identity, {
    authenticated: true,
    login: "raj@example.com",
    name: "Raj Singh",
    profilePic: "https://example.com/raj.png",
  });
});

test("rejects unsafe profile URLs and untrusted headers", () => {
  const headers = new Headers({
    "Tailscale-User-Login": "raj@example.com",
    "Tailscale-User-Profile-Pic": "javascript:alert(1)",
  });
  assert.equal(readIdentity(headers).profilePic, null);
  assert.equal(readIdentity(headers, false).authenticated, false);
});

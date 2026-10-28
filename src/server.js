import http from "node:http";
import { createHandler } from "./app.js";

const host = process.env.HOST || "0.0.0.0";
const port = Number.parseInt(process.env.PORT || "3000", 10);

if (!Number.isInteger(port) || port < 1 || port > 65535) {
  throw new Error("PORT must be an integer between 1 and 65535");
}

const server = http.createServer(createHandler());
server.listen(port, host, () =>
  console.log(`workshop app listening on http://${host}:${port}`),
);

function shutdown(signal) {
  console.log(`${signal} received; shutting down`);
  const timer = setTimeout(() => process.exit(1), 5000);
  timer.unref();
  server.close(() => process.exit(0));
}

process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));

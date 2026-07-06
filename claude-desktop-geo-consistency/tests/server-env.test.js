import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { test } from "node:test";

test("MCP server applies configured proxy to its default environment", async () => {
  const child = spawn(process.execPath, ["server/index.js"], {
    cwd: new URL("..", import.meta.url),
    env: {
      ...process.env,
      GEO_PROXY_HOST: "127.0.0.1",
      GEO_HTTP_PORT: "18080",
      GEO_SOCKS_PORT: "18081",
      HTTP_PROXY: "http://wrong.example:1",
      HTTPS_PROXY: "http://wrong.example:1",
      ALL_PROXY: "socks5://wrong.example:1"
    },
    stdio: ["pipe", "pipe", "pipe"]
  });

  let stdout = "";
  const response = await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      reject(new Error(`Timed out waiting for geo_status response. stdout=${stdout}`));
    }, 8000);

    child.once("error", (error) => {
      clearTimeout(timeout);
      reject(error);
    });

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString("utf8");
      for (const line of stdout.split(/\r?\n/)) {
        if (!line.trim()) {
          continue;
        }

        const message = JSON.parse(line);
        if (message.id === 2) {
          clearTimeout(timeout);
          resolve(message);
          return;
        }
      }
    });

    child.stdin.write(
      `${JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: {
          protocolVersion: "2024-11-05",
          capabilities: {},
          clientInfo: { name: "test", version: "0" }
        }
      })}\n`
    );
    child.stdin.write(
      `${JSON.stringify({
        jsonrpc: "2.0",
        id: 2,
        method: "tools/call",
        params: {
          name: "geo_status",
          arguments: { includeNetwork: false }
        }
      })}\n`
    );
  });

  child.kill();

  const payload = JSON.parse(response.result.content[0].text);
  assert.equal(payload.environment.HTTP_PROXY, "http://127.0.0.1:18080");
  assert.equal(payload.environment.HTTPS_PROXY, "http://127.0.0.1:18080");
  assert.equal(payload.environment.ALL_PROXY, "socks5://127.0.0.1:18081");
  assert.equal(payload.environment.NO_PROXY, "localhost,127.0.0.1,::1");
});

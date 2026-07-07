import childProcess from "node:child_process";
import net from "node:net";
import os from "node:os";

const DEFAULT_PROXY_HOST = process.env.GEO_PROXY_HOST || "127.0.0.1";
const DEFAULT_HTTP_PORT = normalizePort(process.env.GEO_HTTP_PORT, 10808);
const DEFAULT_SOCKS_PORT = normalizePort(process.env.GEO_SOCKS_PORT, 10808);
const DEFAULT_NO_PROXY = process.env.NO_PROXY || process.env.no_proxy || "localhost,127.0.0.1,::1";
const TRACE_TARGETS = Object.freeze({
  anthropicApi: "https://api.anthropic.com/cdn-cgi/trace",
  claudeWeb: "https://claude.ai/cdn-cgi/trace",
  cloudflare: "https://cloudflare.com/cdn-cgi/trace"
});

applyDefaultProxyEnvironment();

const tools = [
  {
    name: "geo_status",
    description:
      "查看 Claude Desktop 所在系统的代理环境、本地端口、npm/git 配置和可选出口 trace。",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {
        proxyHost: { type: "string", description: "本地代理主机，默认来自扩展配置。" },
        httpPort: { type: "number", description: "HTTP/mixed 代理端口，默认来自扩展配置。" },
        socksPort: { type: "number", description: "SOCKS 代理端口，默认来自扩展配置。" },
        includeNetwork: {
          type: "boolean",
          description: "是否执行外部 trace 请求。默认 true。"
        }
      }
    }
  },
  {
    name: "geo_verify",
    description:
      "验证显式代理出口、Claude/Anthropic trace 和系统代理配置是否一致。",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {
        proxyHost: { type: "string", description: "本地代理主机，默认来自扩展配置。" },
        httpPort: { type: "number", description: "HTTP/mixed 代理端口，默认来自扩展配置。" },
        socksPort: { type: "number", description: "SOCKS 代理端口，默认来自扩展配置。" }
      }
    }
  },
  {
    name: "geo_fix_terminal_proxy",
    description:
      "写入用户级终端代理变量和 npm/git 代理配置。默认 dry-run，只有 apply=true 才修改。",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {
        proxyHost: { type: "string", description: "本地代理主机，默认来自扩展配置。" },
        httpPort: { type: "number", description: "HTTP/mixed 代理端口，默认来自扩展配置。" },
        socksPort: { type: "number", description: "SOCKS 代理端口，默认来自扩展配置。" },
        apply: {
          type: "boolean",
          description: "是否实际写入配置。默认 false，只展示会做什么。"
        },
        configureTools: {
          type: "boolean",
          description: "是否配置 npm/git 代理。默认 true。"
        },
        rcFile: {
          type: "string",
          description: "macOS 写入的 shell rc 文件，默认 ~/.zshrc。Windows 不使用。"
        }
      }
    }
  }
];

let inputBuffer = Buffer.alloc(0);
let outputMode = "ndjson";

process.stdin.on("data", (chunk) => {
  inputBuffer = Buffer.concat([inputBuffer, chunk]);
  drainInputBuffer();
});

process.stdin.resume();

function drainInputBuffer() {
  while (inputBuffer.length > 0) {
    const framed = tryReadContentLengthMessage();
    if (framed === null) {
      return;
    }

    if (framed === undefined) {
      const line = tryReadLineMessage();
      if (line === null) {
        return;
      }
      handleRawMessage(line, "ndjson");
      continue;
    }

    handleRawMessage(framed, "framed");
  }
}

function tryReadContentLengthMessage() {
  const headerEnd = inputBuffer.indexOf(Buffer.from("\r\n\r\n"));
  if (headerEnd === -1) {
    if (looksLikeContentLengthHeader(inputBuffer)) {
      return null;
    }
    return undefined;
  }

  const header = inputBuffer.slice(0, headerEnd).toString("ascii");
  if (!/^Content-Length:/im.test(header)) {
    return undefined;
  }

  const match = header.match(/Content-Length:\s*(\d+)/i);
  if (!match) {
    inputBuffer = inputBuffer.slice(headerEnd + 4);
    return "";
  }

  const contentLength = Number(match[1]);
  const bodyStart = headerEnd + 4;
  const bodyEnd = bodyStart + contentLength;
  if (inputBuffer.length < bodyEnd) {
    return null;
  }

  const body = inputBuffer.slice(bodyStart, bodyEnd).toString("utf8");
  inputBuffer = inputBuffer.slice(bodyEnd);
  outputMode = "framed";
  return body;
}

function tryReadLineMessage() {
  const newline = inputBuffer.indexOf(0x0a);
  if (newline === -1) {
    return null;
  }

  const line = inputBuffer.slice(0, newline).toString("utf8").trim();
  inputBuffer = inputBuffer.slice(newline + 1);
  return line;
}

function looksLikeContentLengthHeader(buffer) {
  const prefix = buffer.slice(0, Math.min(buffer.length, 32)).toString("ascii");
  return /^Content-Length:/i.test(prefix);
}

async function handleRawMessage(raw, mode) {
  if (!raw || !raw.trim()) {
    return;
  }

  let request;
  try {
    request = JSON.parse(raw);
  } catch {
    return;
  }

  try {
    const response = await handleRequest(request);
    if (response) {
      writeJson(response, mode);
    }
  } catch (error) {
    writeJson(
      {
        jsonrpc: "2.0",
        id: request.id ?? null,
        error: {
          code: -32603,
          message: error?.message || String(error)
        }
      },
      mode
    );
  }
}

async function handleRequest(request) {
  const { id, method, params } = request;

  if (method === "initialize") {
    return {
      jsonrpc: "2.0",
      id,
      result: {
        protocolVersion: params?.protocolVersion || "2024-11-05",
        capabilities: {
          tools: {}
        },
        serverInfo: {
          name: "claude-desktop-geo-consistency",
          version: "0.1.4"
        }
      }
    };
  }

  if (method === "notifications/initialized") {
    return null;
  }

  if (method === "tools/list") {
    return {
      jsonrpc: "2.0",
      id,
      result: {
        tools
      }
    };
  }

  if (method === "tools/call") {
    const result = await callTool(params?.name, params?.arguments || {});
    return {
      jsonrpc: "2.0",
      id,
      result: {
        content: [
          {
            type: "text",
            text: JSON.stringify(result, null, 2)
          }
        ]
      }
    };
  }

  return {
    jsonrpc: "2.0",
    id,
    error: {
      code: -32601,
      message: `Unknown method: ${method}`
    }
  };
}

async function callTool(name, args) {
  if (name === "geo_status") {
    return geoStatus(args);
  }
  if (name === "geo_verify") {
    return geoVerify(args);
  }
  if (name === "geo_fix_terminal_proxy") {
    return geoFixTerminalProxy(args);
  }
  throw new Error(`Unknown tool: ${name}`);
}

async function geoStatus(args) {
  const config = normalizeConfig(args);
  const httpProxy = `http://${config.proxyHost}:${config.httpPort}`;
  const socksProxy = `socks5://${config.proxyHost}:${config.socksPort}`;
  const includeNetwork = args.includeNetwork !== false;

  const result = {
    platform: process.platform,
    arch: process.arch,
    hostname: os.hostname(),
    expected: {
      httpProxy,
      socksProxy
    },
    localPorts: {
      http: await testPort(config.proxyHost, config.httpPort),
      socks: await testPort(config.proxyHost, config.socksPort)
    },
    environment: readProxyEnvironment(),
    systemProxy: await readSystemProxy(),
    tools: await readToolProxyState(),
    traces: {}
  };

  if (includeNetwork) {
    result.traces.envDefaultAnthropicApi = await runTrace(TRACE_TARGETS.anthropicApi);
    result.traces.explicitProxyAnthropicApi = await runTrace(TRACE_TARGETS.anthropicApi, {
      proxy: httpProxy
    });
    result.traces.explicitProxyClaudeWeb = await runTrace(TRACE_TARGETS.claudeWeb, {
      proxy: httpProxy
    });
  }

  return result;
}

async function geoVerify(args) {
  const config = normalizeConfig(args);
  const httpProxy = `http://${config.proxyHost}:${config.httpPort}`;
  const [portOpen, direct, envDefault, explicitProxy, claudeWebProxy, systemProxy] =
    await Promise.all([
      testPort(config.proxyHost, config.httpPort),
      runTrace(TRACE_TARGETS.anthropicApi, { direct: true }),
      runTrace(TRACE_TARGETS.anthropicApi),
      runTrace(TRACE_TARGETS.anthropicApi, { proxy: httpProxy }),
      runTrace(TRACE_TARGETS.claudeWeb, { proxy: httpProxy }),
      readSystemProxy()
    ]);

  const checks = {
    proxyPortOpen: portOpen,
    explicitProxyWorks: explicitProxy.ok,
    systemProxyLooksEnabled: Boolean(systemProxy.enabled),
    envDefaultMatchesExplicit:
      envDefault.ok && explicitProxy.ok && envDefault.ip === explicitProxy.ip,
    claudeWebMatchesAnthropic:
      claudeWebProxy.ok && explicitProxy.ok && claudeWebProxy.loc === explicitProxy.loc,
    directDiffersFromProxy:
      direct.ok && explicitProxy.ok ? direct.ip !== explicitProxy.ip : null
  };

  return {
    platform: process.platform,
    expectedProxy: httpProxy,
    checks,
    traces: {
      directAnthropicApi: direct,
      envDefaultAnthropicApi: envDefault,
      explicitProxyAnthropicApi: explicitProxy,
      explicitProxyClaudeWeb: claudeWebProxy
    },
    systemProxy,
    verdict: buildVerdict(checks)
  };
}

async function geoFixTerminalProxy(args) {
  const config = normalizeConfig(args);
  const apply = args.apply === true;
  const configureTools = args.configureTools !== false;
  const httpProxy = `http://${config.proxyHost}:${config.httpPort}`;
  const socksProxy = `socks5://${config.proxyHost}:${config.socksPort}`;
  const noProxy = "localhost,127.0.0.1,::1";
  const planned = {
    environment: {
      HTTP_PROXY: httpProxy,
      HTTPS_PROXY: httpProxy,
      ALL_PROXY: socksProxy,
      NO_PROXY: noProxy
    },
    configureTools,
    rcFile: args.rcFile || `${os.homedir()}/.zshrc`
  };

  if (!apply) {
    return {
      dryRun: true,
      planned,
      note: "没有修改系统。再次调用时传 apply=true 才会写入用户级终端代理和工具代理。"
    };
  }

  if (process.platform === "win32") {
    await applyWindowsUserEnvironment(planned.environment);
  } else if (process.platform === "darwin") {
    await applyMacShellEnvironment(planned);
  } else {
    throw new Error("geo_fix_terminal_proxy 目前只支持 Windows 和 macOS。");
  }

  const toolResults = configureTools ? await configureToolProxy(httpProxy) : {};
  return {
    dryRun: false,
    applied: planned,
    toolResults,
    note: "已经写入。请重启 Claude Desktop/Claude Code 或从新终端启动，使新环境生效。"
  };
}

function normalizeConfig(args = {}) {
  return {
    proxyHost:
      typeof args.proxyHost === "string" && args.proxyHost.trim()
        ? args.proxyHost.trim()
        : DEFAULT_PROXY_HOST,
    httpPort: normalizePort(args.httpPort, DEFAULT_HTTP_PORT),
    socksPort: normalizePort(args.socksPort, DEFAULT_SOCKS_PORT)
  };
}

function normalizePort(value, fallback) {
  const number = Number(value);
  return Number.isInteger(number) && number > 0 && number <= 65535 ? number : fallback;
}

function applyDefaultProxyEnvironment() {
  const httpProxy = `http://${DEFAULT_PROXY_HOST}:${DEFAULT_HTTP_PORT}`;
  const socksProxy = `socks5://${DEFAULT_PROXY_HOST}:${DEFAULT_SOCKS_PORT}`;
  const values = {
    HTTP_PROXY: httpProxy,
    HTTPS_PROXY: httpProxy,
    ALL_PROXY: socksProxy,
    NO_PROXY: DEFAULT_NO_PROXY,
    http_proxy: httpProxy,
    https_proxy: httpProxy,
    all_proxy: socksProxy,
    no_proxy: DEFAULT_NO_PROXY
  };

  for (const [name, value] of Object.entries(values)) {
    process.env[name] = value;
  }
}

function readProxyEnvironment() {
  const names = [
    "HTTP_PROXY",
    "HTTPS_PROXY",
    "ALL_PROXY",
    "NO_PROXY",
    "http_proxy",
    "https_proxy",
    "all_proxy",
    "no_proxy",
    "ANTHROPIC_BASE_URL",
    "TZ",
    "LANG",
    "LC_ALL"
  ];
  const output = {};
  for (const name of names) {
    if (process.env[name]) {
      output[name] = process.env[name];
    }
  }
  return output;
}

async function readSystemProxy() {
  if (process.platform === "win32") {
    return readWindowsSystemProxy();
  }
  if (process.platform === "darwin") {
    return readMacSystemProxy();
  }
  return {
    platform: process.platform,
    enabled: null,
    note: "Only Windows and macOS system proxy detection is implemented."
  };
}

async function readWindowsSystemProxy() {
  const key = "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings";
  const values = {};
  for (const valueName of ["ProxyEnable", "ProxyServer", "AutoConfigURL"]) {
    const result = await execFileSafe("reg", ["query", key, "/v", valueName]);
    values[valueName] = parseRegQueryValue(result.stdout);
  }
  return {
    platform: "win32",
    enabled: values.ProxyEnable === "0x1" || values.ProxyEnable === "1",
    proxyServer: values.ProxyServer || "",
    autoConfigUrl: values.AutoConfigURL || ""
  };
}

async function readMacSystemProxy() {
  const result = await execFileSafe("scutil", ["--proxy"]);
  const parsed = {};
  for (const line of result.stdout.split(/\r?\n/)) {
    const match = line.match(/^\s*([^:]+)\s*:\s*(.*)$/);
    if (match) {
      parsed[match[1].trim()] = match[2].trim();
    }
  }
  const enabled =
    parsed.HTTPEnable === "1" ||
    parsed.HTTPSEnable === "1" ||
    parsed.SOCKSEnable === "1" ||
    parsed.ProxyAutoConfigEnable === "1";
  return {
    platform: "darwin",
    enabled,
    raw: parsed
  };
}

async function readToolProxyState() {
  const [gitHttp, gitHttps, npmProxy, npmHttpsProxy] = await Promise.all([
    execFileText("git", ["config", "--global", "--get", "http.proxy"]),
    execFileText("git", ["config", "--global", "--get", "https.proxy"]),
    execFileText("npm", ["config", "get", "proxy"]),
    execFileText("npm", ["config", "get", "https-proxy"])
  ]);
  return {
    gitHttpProxy: cleanToolValue(gitHttp),
    gitHttpsProxy: cleanToolValue(gitHttps),
    npmProxy: cleanToolValue(npmProxy),
    npmHttpsProxy: cleanToolValue(npmHttpsProxy)
  };
}

async function configureToolProxy(httpProxy) {
  const results = {};
  results.gitHttp = await execFileSummary("git", ["config", "--global", "http.proxy", httpProxy]);
  results.gitHttps = await execFileSummary("git", ["config", "--global", "https.proxy", httpProxy]);
  results.npmProxy = await execFileSummary("npm", ["config", "set", "proxy", httpProxy]);
  results.npmHttpsProxy = await execFileSummary("npm", [
    "config",
    "set",
    "https-proxy",
    httpProxy
  ]);
  return results;
}

async function applyWindowsUserEnvironment(envValues) {
  for (const [name, value] of Object.entries(envValues)) {
    await execFileSafe("setx", [name, value]);
    await execFileSafe("setx", [name.toLowerCase(), value]);
  }
}

async function applyMacShellEnvironment(planned) {
  const markerStart = "# >>> claude-desktop-geo-consistency start <<<";
  const markerEnd = "# >>> claude-desktop-geo-consistency end <<<";
  const block = [
    markerStart,
    `export HTTP_PROXY="${planned.environment.HTTP_PROXY}"`,
    `export HTTPS_PROXY="${planned.environment.HTTPS_PROXY}"`,
    `export ALL_PROXY="${planned.environment.ALL_PROXY}"`,
    `export http_proxy="${planned.environment.HTTP_PROXY}"`,
    `export https_proxy="${planned.environment.HTTPS_PROXY}"`,
    `export all_proxy="${planned.environment.ALL_PROXY}"`,
    `export NO_PROXY="${planned.environment.NO_PROXY}"`,
    `export no_proxy="${planned.environment.NO_PROXY}"`,
    markerEnd
  ].join("\n");

  const script = `
set -e
touch "$1"
python3 - "$1" "$2" "$3" "$4" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
start = sys.argv[2]
end = sys.argv[3]
block = sys.argv[4] + "\\n"
text = path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""
pattern = re.compile(re.escape(start) + r".*?" + re.escape(end) + r"\\n?", re.S)
if pattern.search(text):
    text = pattern.sub(block, text)
else:
    if text and not text.endswith("\\n"):
        text += "\\n"
    text += "\\n" + block
path.write_text(text, encoding="utf-8")
PY
`;
  await execFileSafe("bash", ["-lc", script, "bash", planned.rcFile, markerStart, markerEnd, block]);
}

async function runTrace(url, { proxy = "", direct = false } = {}) {
  const args = ["-fsS", "--connect-timeout", "5", "--max-time", "12"];
  if (direct) {
    args.push("--noproxy", "*");
  }
  if (proxy) {
    args.push("--proxy", proxy);
  }
  args.push(url);

  const result = await execFileSafe("curl", args);
  if (!result.ok) {
    return {
      ok: false,
      url,
      proxy,
      direct,
      error: result.stderr || result.stdout || result.error
    };
  }

  const trace = parseTrace(result.stdout);
  return {
    ok: true,
    url,
    proxy,
    direct,
    ip: trace.ip || "",
    loc: trace.loc || "",
    colo: trace.colo || "",
    warp: trace.warp || "",
    raw: trace
  };
}

function parseTrace(text) {
  const result = {};
  for (const line of text.split(/\r?\n/)) {
    const index = line.indexOf("=");
    if (index > 0) {
      result[line.slice(0, index)] = line.slice(index + 1);
    }
  }
  return result;
}

function testPort(host, port) {
  return new Promise((resolve) => {
    const socket = net.createConnection({ host, port });
    const timer = setTimeout(() => {
      socket.destroy();
      resolve(false);
    }, 1000);
    socket.once("connect", () => {
      clearTimeout(timer);
      socket.destroy();
      resolve(true);
    });
    socket.once("error", () => {
      clearTimeout(timer);
      resolve(false);
    });
  });
}

function buildVerdict(checks) {
  if (!checks.proxyPortOpen) {
    return "FAIL: 本地代理端口不可连接。";
  }
  if (!checks.explicitProxyWorks) {
    return "FAIL: 显式代理无法访问 Anthropic trace。";
  }
  if (!checks.systemProxyLooksEnabled) {
    return "WARN: 显式代理可用，但系统代理看起来没有开启。Claude Desktop 可能不会走该代理。";
  }
  if (!checks.envDefaultMatchesExplicit) {
    return "WARN: 当前 MCP server 默认出口与显式代理出口不一致。";
  }
  if (!checks.claudeWebMatchesAnthropic) {
    return "WARN: Claude Web 与 Anthropic API 的代理出口地区不一致。";
  }
  return "OK: 显式代理、系统代理信号和 Claude/Anthropic 出口看起来一致。";
}

function parseRegQueryValue(stdout) {
  const lines = stdout.split(/\r?\n/);
  for (const line of lines) {
    const parts = line.trim().split(/\s{2,}/);
    if (parts.length >= 3) {
      return parts.slice(2).join(" ").trim();
    }
  }
  return "";
}

function cleanToolValue(value) {
  const text = String(value || "").trim();
  return text && text !== "null" && text !== "undefined" ? text : "";
}

async function execFileText(command, args) {
  const result = await execFileSafe(command, args);
  return result.ok ? result.stdout : "";
}

async function execFileSummary(command, args) {
  const result = await execFileSafe(command, args);
  return {
    ok: result.ok,
    error: result.ok ? "" : result.stderr || result.stdout || result.error || ""
  };
}

function execFileSafe(command, args) {
  return new Promise((resolve) => {
    childProcess.execFile(
      command,
      args,
      {
        windowsHide: true,
        timeout: 15000,
        maxBuffer: 1024 * 1024
      },
      (error, stdout, stderr) => {
        resolve({
          ok: !error,
          stdout: stdout || "",
          stderr: stderr || "",
          error: error?.message || ""
        });
      }
    );
  });
}

function writeJson(value, mode = outputMode) {
  const json = JSON.stringify(value);
  if (mode === "framed") {
    const byteLength = Buffer.byteLength(json, "utf8");
    process.stdout.write(`Content-Length: ${byteLength}\r\n\r\n${json}`);
    return;
  }

  process.stdout.write(`${json}\n`);
}

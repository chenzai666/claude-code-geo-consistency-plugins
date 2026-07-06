# Claude Desktop 出口一致性扩展

这是 Claude Desktop 可安装的 Desktop Extension/MCPB 版本，用来在 Claude Desktop 里直接检查当前机器的代理和出口一致性。

它不是浏览器扩展，也不会 patch Claude Desktop 内部 JS API。它提供的是本地 MCP 工具：

- `geo_status`：查看系统代理、本地代理端口、环境变量、npm/git 代理和可选出口 trace。
- `geo_verify`：对比显式代理出口、Anthropic API、Claude Web trace 是否一致。
- `geo_fix_terminal_proxy`：按需写入用户级终端代理变量和 npm/git 代理配置，默认是 dry-run，不会直接修改。

## 默认配置

- 代理主机：`127.0.0.1`
- HTTP 代理端口：`10808`
- SOCKS 代理端口：`10808`

这个默认值适合 v2rayN 开启系统代理到 `127.0.0.1:10808` 的情况。

## 隐私模型

- 不读取 Claude 聊天内容。
- 不读取网页内容。
- 不做 telemetry。
- 不做 analytics。
- 不使用账号系统。
- 外部请求只用于出口检测：`api.anthropic.com/cdn-cgi/trace`、`claude.ai/cdn-cgi/trace`、`cloudflare.com/cdn-cgi/trace`。

## 安装

打包后会生成：

```text
dist/claude-desktop-geo-consistency.mcpb
```

在 Claude Desktop 中打开该 `.mcpb` 文件安装。

## 本地开发校验

```powershell
npm run check
```

也可以直接启动 MCP server 做协议调试：

```powershell
node server/index.js
```

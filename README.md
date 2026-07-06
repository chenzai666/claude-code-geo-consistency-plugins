# Claude Code 出口一致性插件

这个目录里有两个 Claude Code 插件版本，用来让 Claude Code 的终端运行环境、代理配置和实际出口 IP 保持一致：

- `geo-consistency-windows`：Windows 版，默认面向 v2rayN / PowerShell / `127.0.0.1:10808`。
- `geo-consistency-macos`：macOS 版，面向 zsh/bash、系统代理和本地代理端口检测。
- `claude-desktop-geo-consistency`：Claude Desktop 版，打包为 `.mcpb` Desktop Extension。

这不是浏览器画像插件，也不会 patch `navigator`、`Intl`、`Date` 这类网页 API。它只处理 Claude Code 会实际用到的 CLI 环境：

- `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY`
- npm / git 代理配置
- 系统代理状态
- Anthropic / Claude 相关域名看到的出口 IP 和地区

桌面版同样不 patch Claude Desktop 内部网络栈；它提供 MCP 工具，让你在 Claude Desktop 里检查系统代理、本地端口和 Claude/Anthropic 出口是否一致。Desktop 扩展会按自己的配置只给 MCP server 进程补齐代理环境变量，让 server 默认 trace 和显式代理 trace 使用同一个出口。

## 安装建议

这个仓库已经带有 Claude Code marketplace 清单。先在 Claude Code 里添加 marketplace：

```text
/plugin marketplace add chenzai666/claude-code-geo-consistency-plugins
```

然后按系统安装对应插件：

```text
/plugin install geo-consistency-windows@geo-consistency
```

```text
/plugin install geo-consistency-macos@geo-consistency
```

安装后建议执行：

```text
/reload-plugins
```

安装后，命令会按插件 manifest 名称命名：

```text
/geo-consistency-windows:geo-status
/geo-consistency-windows:geo-verify
/geo-consistency-windows:geo-fix
```

```text
/geo-consistency-macos:geo-status
/geo-consistency-macos:geo-verify
/geo-consistency-macos:geo-fix
```

## 默认值

两个版本默认都使用：

- 主机：`127.0.0.1`
- HTTP 代理端口：`10808`
- SOCKS 代理端口：`10808`

这匹配常见 v2rayN mixed port / 系统代理设置。如果你的本地代理端口不同，可以在 slash command 后面传参数覆盖。

## Claude Desktop 安装

下载或打开仓库中的：

```text
claude-desktop-geo-consistency/dist/claude-desktop-geo-consistency.mcpb
```

在 Claude Desktop 中安装该 `.mcpb` 文件。安装后可在对话里让 Claude 调用：

- `geo_status`
- `geo_verify`
- `geo_fix_terminal_proxy`

`geo_fix_terminal_proxy` 默认 dry-run，不会直接修改环境；只有传 `apply=true` 才会写入用户级终端代理变量和 npm/git 代理配置。

如果 Windows AppX 版 Claude Desktop 双击 `.mcpb` 弹出“Windows 无法访问指定设备、路径或文件”，请在仓库根目录运行：

```powershell
cd .\claude-desktop-geo-consistency
powershell -ExecutionPolicy Bypass -File .\scripts\install-windows.ps1
```

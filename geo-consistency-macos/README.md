# Geo Consistency macOS

这是 macOS 版 Claude Code 出口一致性插件，用来检查和修复 Claude Code 当前 shell 环境是否真的走本地代理出口。

默认配置：

- 代理主机：`127.0.0.1`
- HTTP 代理端口：`10808`
- SOCKS 代理端口：`10808`

## 会检查什么

- Claude Code 进程环境变量：`HTTP_PROXY`、`HTTPS_PROXY`、`ALL_PROXY`、`NO_PROXY`
- macOS 系统代理摘要：`scutil --proxy`
- 本地代理端口是否可连接，默认检查 `127.0.0.1:10808`
- npm / git 全局代理配置
- `api.anthropic.com`、`claude.ai`、Cloudflare trace 看到的出口 IP 和地区

## 命令

```text
/geo-consistency-macos:geo-status
/geo-consistency-macos:geo-verify
/geo-consistency-macos:geo-fix
```

可以在命令后传参数覆盖默认端口或 rc 文件，例如：

```text
/geo-consistency-macos:geo-status --http-port 10808 --socks-port 10808
/geo-consistency-macos:geo-fix --http-port 7890 --socks-port 7891 --rc-file "$HOME/.zshrc"
```

## 命令说明

- `geo-status`：查看当前 Claude Code shell 环境、macOS 系统代理、npm/git 代理和出口状态。
- `geo-verify`：对比直连、终端默认路由、显式代理路由、Claude/Anthropic 相关域名出口是否一致。
- `geo-fix`：把代理环境变量写入 shell rc 文件，并配置 npm/git 代理。

`geo-fix` 会写入 rc 文件，默认是 `~/.zshrc`。已经运行中的 Claude Code 进程不会自动继承这些变化；运行后需要从新终端重新启动 Claude Code，或者先 `source` 对应 rc 文件再启动。

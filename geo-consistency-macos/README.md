# Geo Consistency macOS

这是 macOS 版 Claude Code 出口一致性插件，用来检查当前 Claude Code shell 环境是否真的走本地代理出口，并确认 Anthropic/Claude 相关请求看到的出口是否一致。

默认配置：

- 代理主机：`127.0.0.1`
- HTTP 代理端口：`10808`
- SOCKS 代理端口：`10808`

## 会检查什么

- Claude Code 当前进程环境变量：`HTTP_PROXY`、`http_proxy`、`HTTPS_PROXY`、`https_proxy`、`ALL_PROXY`、`all_proxy`、`NO_PROXY`、`no_proxy`
- macOS 系统代理摘要：`scutil --proxy`
- 本地代理端口是否可连接，默认检查 `127.0.0.1:10808`
- npm / git 全局代理配置
- `api.anthropic.com`、`claude.ai`、Cloudflare trace 看到的出口 IP 和地区

## 命令

```text
/geo-consistency-macos:geo-status
/geo-consistency-macos:geo-verify
```

可以在命令后传参数覆盖默认端口，例如：

```text
/geo-consistency-macos:geo-status --http-port 10808 --socks-port 10808
/geo-consistency-macos:geo-verify --http-port 10808 --socks-port 10808
```

## 使用边界

插件不会写入 `~/.zshrc`、`~/.bashrc` 或用户级环境变量。它只读取 Claude Code 当前进程已经继承到的 shell 环境，并做一致性验证。

如果要让 Claude Code 继承代理，请先配置 shell rc 或运行你的代理设置脚本，然后从这个终端启动 Claude Code。

`geo-fix` 已移除，因为子进程不能反向修改已经运行中的 Claude Code 父进程环境。

## 卸载

在 Claude Code 中执行：

```text
/plugin uninstall geo-consistency-macos@geo-consistency
/reload-plugins
```

如需移除 marketplace，可以在 `/plugin` 的 marketplace 管理界面删除 `geo-consistency`，或在终端执行：

```bash
claude plugin marketplace remove geo-consistency --scope user
```

手动清理缓存：

```bash
rm -rf "$HOME/.claude/plugins/cache/geo-consistency"
rm -rf "$HOME/.claude/plugins/marketplaces/geo-consistency"
```

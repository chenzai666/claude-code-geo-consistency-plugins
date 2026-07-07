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
/geo-consistency-macos:geo-launch
```

可以在命令后传参数覆盖默认端口，例如：

```text
/geo-consistency-macos:geo-status --http-port 10808 --socks-port 10808
/geo-consistency-macos:geo-verify --http-port 10808 --socks-port 10808
```

`geo-status` 默认是本地快照，不做外部出口请求；需要追加 trace 时传 `--include-network`。`geo-verify` 才做一致性对比，并输出 Markdown 表格。

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

## 时区和语言画像一致

`geo-verify` 会查询显式代理出口 IP 的地理画像，并对比当前 Claude Code 运行时的 `TZ`、Node timezone、系统 timezone、`LANG`、`LC_ALL`、`LC_MESSAGES`、`LANGUAGE`。如果出口 IP 是 `US / America/Chicago / en-US`，但当前运行时仍是其他时区或语言环境，结果会显示 WARN。

在 Claude Code 内运行：

```text
/geo-consistency-macos:geo-launch
```

这个命令只打印下一次启动应注入的画像。要真正生效，请从外部终端启动新的 Claude Code：

```bash
bash ./geo-consistency-macos/scripts/geo-launch.sh
```

launcher 只影响这次启动的子进程，不写入 `~/.zshrc`、`~/.bashrc` 或用户级环境变量。它会注入 `TZ`、`LANG`、`LC_ALL`、`LC_MESSAGES`、`LANGUAGE`、`ACCEPT_LANGUAGE` 和代理变量。

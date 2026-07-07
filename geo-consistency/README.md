# Geo Consistency

这是统一版 Claude Code 出口一致性插件。它保留一个入口，根据当前系统自动调用 Windows 或 macOS 脚本，避免手动选择 `geo-consistency-windows` / `geo-consistency-macos` 时选错。

默认配置：

- 代理主机：`127.0.0.1`
- HTTP 代理端口：`10808`
- SOCKS 代理端口：`10808`

## 命令

```text
/geo-consistency:geo-status
/geo-consistency:geo-verify
/geo-consistency:geo-launch
```

参数会原样传给对应平台脚本：

```text
/geo-consistency:geo-status -HttpPort 10808 -SocksPort 10808
/geo-consistency:geo-verify -HttpPort 10808 -SocksPort 10808
```

macOS 上也可以使用 macOS 脚本参数：

```text
/geo-consistency:geo-status --http-port 10808 --socks-port 10808
/geo-consistency:geo-verify --http-port 10808 --socks-port 10808
```

`geo-status` 默认是本地快照，不做外部出口请求；Windows 可传 `-IncludeNetwork`、macOS 可传 `--include-network` 追加 trace。`geo-verify` 才做一致性对比，并输出 Markdown 表格。

## 代理变量说明

`HTTP_PROXY` / `HTTPS_PROXY` 是按协议指定的代理变量，`ALL_PROXY` 是兜底变量。若当前 Claude Code 进程没有 `HTTP_PROXY` / `HTTPS_PROXY`，但有 `ALL_PROXY=socks5://127.0.0.1:10808`，curl 仍会通过 SOCKS 代理访问 HTTP/HTTPS 目标。

`geo-verify` 里的 `terminalHttpProxyCovered` / `terminalHttpsProxyCovered` 会把 `ALL_PROXY` fallback 计算进去；只要它们为 `True`，就表示 HTTP/HTTPS 出口已有代理覆盖。

## 时区和语言画像一致

`geo-verify` 会通过多个 IP geolocation provider fallback 查询显式代理出口画像，并对比当前 Claude Code 运行时的 `TZ`、Node timezone、系统 timezone、`LANG`、`LC_ALL`、`LC_MESSAGES`、`LANGUAGE`。如果出口 IP 是美国中部时区，但当前运行时仍是 `Asia/Shanghai / zh-CN`，结果会显示 WARN。

在当前 Claude Code 里可以运行：

```text
/geo-consistency:geo-launch
```

这只会打印下一次启动应注入的画像。要真正让 Claude Code 使用匹配的时区和语言环境，需要从外部终端启动：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\geo-consistency\scripts\windows\geo-launch.ps1
```

macOS：

```bash
bash ./geo-consistency/scripts/macos/geo-launch.sh
```

launcher 会注入 `TZ`、`LANG`、`LC_ALL`、`LC_MESSAGES`、`LANGUAGE`、`ACCEPT_LANGUAGE` 和代理变量，只影响这次启动的 Claude Code 子进程，不写入用户级环境变量。

限制：Windows 上 Node/Bun 的默认 `Intl` locale 常来自系统区域设置，`LANG/LC_ALL` 不一定能把 `Intl.DateTimeFormat().resolvedOptions().locale` 改掉；`verify` 会单独显示 `languageEnvMatchesExit` 和 `nodeLocaleMatchesExit`。

## 平台行为

- Windows：调用 `scripts/windows/*.ps1`，只读取当前 Claude Code 进程环境、系统代理摘要、npm/git 代理和出口 trace。
- macOS：调用 `scripts/macos/*.sh`，只读取当前 Claude Code shell 环境、系统代理摘要、npm/git 代理和出口 trace。
- Linux：暂未支持，会提示安装或扩展对应脚本。

插件不会写入用户级环境变量、shell rc 文件或系统代理。`geo-fix` 已移除，因为子进程不能反向修改已经运行中的 Claude Code 父进程环境。

如果要让 Claude Code 继承代理，请先运行 `proxy-setup` 或手动配置 shell 环境，然后从这个终端启动 Claude Code。

## 卸载

在 Claude Code 中执行：

```text
/plugin uninstall geo-consistency@geo-consistency
/reload-plugins
```

如需移除 marketplace，可以在 `/plugin` 的 marketplace 管理界面删除 `geo-consistency`，或在终端执行：

```powershell
claude plugin marketplace remove geo-consistency --scope user
```

手动清理缓存：

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\.claude\plugins\cache\geo-consistency" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$env:USERPROFILE\.claude\plugins\marketplaces\geo-consistency" -ErrorAction SilentlyContinue
```

macOS/Linux：

```bash
rm -rf "$HOME/.claude/plugins/cache/geo-consistency"
rm -rf "$HOME/.claude/plugins/marketplaces/geo-consistency"
```

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

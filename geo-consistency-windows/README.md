# Geo Consistency Windows

这是 Windows 版 Claude Code 出口一致性插件，用来检查当前 Claude Code 进程是否真的继承了终端里的代理环境，并确认 Anthropic/Claude 相关请求看到的出口是否一致。

默认配置面向 v2rayN：

- 代理主机：`127.0.0.1`
- HTTP 代理端口：`10808`
- SOCKS 代理端口：`10808`

## 会检查什么

- Claude Code 当前进程环境变量：`HTTP_PROXY`、`http_proxy`、`HTTPS_PROXY`、`https_proxy`、`ALL_PROXY`、`all_proxy`、`NO_PROXY`、`no_proxy`
- 实际生效代理值：`effectiveHttpProxy`、`effectiveHttpsProxy`、`effectiveAllProxy`、`effectiveNoProxy`
- Windows 当前用户系统代理：`HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings`
- 本地代理端口是否可连接，默认检查 `127.0.0.1:10808`
- npm / git 全局代理配置
- `api.anthropic.com`、`claude.ai`、Cloudflare trace 看到的出口 IP 和地区

## 命令

```text
/geo-consistency-windows:geo-status
/geo-consistency-windows:geo-verify
```

可以在命令后传参数覆盖默认端口，例如：

```text
/geo-consistency-windows:geo-status -HttpPort 10808 -SocksPort 10808
/geo-consistency-windows:geo-verify -HttpPort 10808 -SocksPort 10808
```

## 使用边界

插件不会写入用户级环境变量，也不会修改 Windows 系统代理。它只读取 Claude Code 当前进程已经继承到的环境，并做一致性验证。

如果要让 Claude Code 继承代理，请先运行 `proxy-setup` 或手动设置 PowerShell/CMD 环境，然后从这个终端启动 Claude Code。

`geo-fix` 已移除，因为子进程不能反向修改已经运行中的 Claude Code 父进程环境。

## 卸载

在 Claude Code 中执行：

```text
/plugin uninstall geo-consistency-windows@geo-consistency
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

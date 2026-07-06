# Geo Consistency Windows

这是 Windows 版 Claude Code 出口一致性插件，用来检查和修复 Claude Code 当前终端环境是否真的走本地代理出口。

默认配置面向 v2rayN：

- 代理主机：`127.0.0.1`
- HTTP 代理端口：`10808`
- SOCKS 代理端口：`10808`

## 会检查什么

- Claude Code 进程环境变量：`HTTP_PROXY`、`HTTPS_PROXY`、`ALL_PROXY`、`NO_PROXY`
- Windows 当前用户系统代理：`HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings`
- 本地代理端口是否可连接，默认检查 `127.0.0.1:10808`
- npm / git 全局代理配置
- `api.anthropic.com`、`claude.ai`、Cloudflare trace 看到的出口 IP 和地区

## 命令

```text
/geo-consistency-windows:geo-status
/geo-consistency-windows:geo-verify
/geo-consistency-windows:geo-fix
```

可以在命令后传参数覆盖默认端口，例如：

```text
/geo-consistency-windows:geo-status -HttpPort 10808 -SocksPort 10808
/geo-consistency-windows:geo-fix -HttpPort 7890 -SocksPort 7891
```

## 命令说明

- `geo-status`：查看当前 Claude Code 终端环境、Windows 系统代理、npm/git 代理和出口状态。
- `geo-verify`：对比直连、终端默认路由、显式代理路由、Claude/Anthropic 相关域名出口是否一致。
- `geo-fix`：写入用户级代理环境变量，并配置 npm/git 代理。

`geo-fix` 会修改用户级环境变量。已经运行中的 Claude Code 进程不会自动继承这些变化；运行后需要从新终端重新启动 Claude Code。

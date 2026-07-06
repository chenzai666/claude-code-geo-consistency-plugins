# Claude Code 出口一致性插件

这个目录里有两个 Claude Code 插件版本，用来让 Claude Code 的终端运行环境、代理配置和实际出口 IP 保持一致：

- `geo-consistency-windows`：Windows 版，默认面向 v2rayN / PowerShell / `127.0.0.1:10808`。
- `geo-consistency-macos`：macOS 版，面向 zsh/bash、系统代理和本地代理端口检测。

这不是浏览器画像插件，也不会 patch `navigator`、`Intl`、`Date` 这类网页 API。它只处理 Claude Code 会实际用到的 CLI 环境：

- `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY`
- npm / git 代理配置
- 系统代理状态
- Anthropic / Claude 相关域名看到的出口 IP 和地区

## 安装建议

用 Claude Code 的插件安装流程安装对应系统的目录，或者把对应目录复制到你的 Claude Code 插件工作区。

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

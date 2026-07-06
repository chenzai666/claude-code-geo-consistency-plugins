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
/geo-consistency:geo-fix
```

参数会原样传给对应平台脚本：

```text
/geo-consistency:geo-status -HttpPort 10808 -SocksPort 10808
/geo-consistency:geo-fix -HttpPort 7890 -SocksPort 7891
```

在 macOS 上也可以使用 macOS 脚本参数：

```text
/geo-consistency:geo-status --http-port 10808 --socks-port 10808
/geo-consistency:geo-fix --http-port 7890 --socks-port 7891 --rc-file "$HOME/.zshrc"
```

## 平台行为

- Windows：调用 `scripts/windows/*.ps1`，写入用户级代理环境变量，并配置 npm/git 代理。
- macOS：调用 `scripts/macos/*.sh`，写入 shell rc 文件，并配置 npm/git 代理。
- Linux：暂未支持，会提示安装或扩展对应脚本。

如果你明确只想使用某个平台入口，原来的 `geo-consistency-windows` 和 `geo-consistency-macos` 插件仍然保留。

param(
    [string]$ProxyHost = "127.0.0.1",
    [int]$HttpPort = 10808,
    [int]$SocksPort = 10808,
    [switch]$Json,
    [switch]$SkipNetwork
)

. "$PSScriptRoot\geo-common.ps1"

$httpProxy = Get-GeoDefaultProxyUrl $ProxyHost $HttpPort
$socksProxy = Get-GeoDefaultSocksUrl $ProxyHost $SocksPort

$status = [ordered]@{
    os = "windows"
    expectedHttpProxy = $httpProxy
    expectedSocksProxy = $socksProxy
    localPorts = [ordered]@{
        http = Test-GeoTcpPort $ProxyHost $HttpPort
        socks = Test-GeoTcpPort $ProxyHost $SocksPort
    }
    environment = Get-GeoEnvProxyState
    windowsSystemProxy = Get-GeoWindowsSystemProxy
    tools = Get-GeoToolProxyState
    traces = @()
}

if (-not $SkipNetwork) {
    $status.traces = @(
        Invoke-GeoTrace "https://api.anthropic.com/cdn-cgi/trace"
        Invoke-GeoTrace "https://claude.ai/cdn-cgi/trace"
        Invoke-GeoTrace "https://cloudflare.com/cdn-cgi/trace" -Proxy $httpProxy
    )
}

if ($Json) {
    $status | ConvertTo-Json -Depth 8
    exit 0
}

Write-GeoSection "Claude Code Geo Status (Windows)"
Write-GeoKV "Expected HTTP proxy" $status.expectedHttpProxy
Write-GeoKV "Expected SOCKS proxy" $status.expectedSocksProxy
Write-GeoKV "HTTP port open" $status.localPorts.http
Write-GeoKV "SOCKS port open" $status.localPorts.socks

Write-GeoSection "Process Environment"
foreach ($key in $status.environment.Keys) {
    Write-GeoKV $key $status.environment[$key]
}

Write-GeoSection "Windows System Proxy"
foreach ($key in $status.windowsSystemProxy.Keys) {
    Write-GeoKV $key $status.windowsSystemProxy[$key]
}

Write-GeoSection "Tool Proxy Config"
foreach ($key in $status.tools.Keys) {
    Write-GeoKV $key $status.tools[$key]
}

if (-not $SkipNetwork) {
    Write-GeoSection "Egress Traces"
    foreach ($trace in $status.traces) {
        Write-Host ""
        Write-GeoKV "url" $trace.url
        Write-GeoKV "proxy" $trace.proxy
        Write-GeoKV "ok" $trace.ok
        Write-GeoKV "ip" $trace.ip
        Write-GeoKV "loc" $trace.loc
        Write-GeoKV "colo" $trace.colo
        Write-GeoKV "warp" $trace.warp
        if (-not $trace.ok) {
            Write-GeoKV "error" $trace.error
        }
    }
}

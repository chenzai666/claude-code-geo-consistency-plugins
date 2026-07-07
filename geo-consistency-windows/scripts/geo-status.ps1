param(
    [string]$ProxyHost = "127.0.0.1",
    [int]$HttpPort = 10808,
    [int]$SocksPort = 10808,
    [string]$IpinfoToken = $env:IPINFO_TOKEN,
    [switch]$Json,
    [switch]$SkipNetwork,
    [switch]$IncludeNetwork
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
    runtimeProfile = Get-GeoRuntimeProfile
    windowsSystemProxy = Get-GeoWindowsSystemProxy
    tools = Get-GeoToolProxyState
    exitProfile = $null
    localeBundle = $null
    traces = @()
}

if ($IncludeNetwork -and -not $SkipNetwork) {
    $status.exitProfile = Invoke-GeoIpProfile -Proxy $httpProxy -IpinfoToken $IpinfoToken
    if ($status.exitProfile.ok) {
        $status.localeBundle = Get-GeoLocaleBundle $status.exitProfile.countryCode $status.exitProfile.timezone
    }
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

Write-GeoSection "Runtime Profile"
foreach ($key in $status.runtimeProfile.Keys) {
    if ($key -ne "node") {
        Write-GeoKV $key $status.runtimeProfile[$key]
    }
}

Write-GeoSection "Windows System Proxy"
foreach ($key in $status.windowsSystemProxy.Keys) {
    Write-GeoKV $key $status.windowsSystemProxy[$key]
}

Write-GeoSection "Tool Proxy Config"
foreach ($key in $status.tools.Keys) {
    Write-GeoKV $key $status.tools[$key]
}

if ($IncludeNetwork -and -not $SkipNetwork) {
    Write-GeoSection "Exit IP Profile"
    if ($status.exitProfile.ok) {
        foreach ($key in @("provider", "ip", "countryCode", "country", "region", "city", "latitude", "longitude", "isp", "timezone")) {
            Write-GeoKV $key $status.exitProfile[$key]
        }
    } else {
        Write-GeoKV "ok" $false
        Write-GeoKV "error" $status.exitProfile.error
    }

    if ($status.localeBundle) {
        Write-GeoSection "Inferred Locale Bundle"
        foreach ($key in $status.localeBundle.Keys) {
            Write-GeoKV $key $status.localeBundle[$key]
        }
    }

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
} else {
    Write-Host ""
    Write-Host "Tip: status is local-only by default. Use -IncludeNetwork to add egress traces."
}

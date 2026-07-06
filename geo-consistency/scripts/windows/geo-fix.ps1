param(
    [string]$ProxyHost = "127.0.0.1",
    [int]$HttpPort = 10808,
    [int]$SocksPort = 10808,
    [switch]$SkipToolConfig,
    [switch]$Json
)

. "$PSScriptRoot\geo-common.ps1"

$httpProxy = Get-GeoDefaultProxyUrl $ProxyHost $HttpPort
$socksProxy = Get-GeoDefaultSocksUrl $ProxyHost $SocksPort
$noProxy = "localhost,127.0.0.1,::1"

$vars = @(
    @{ Name = "HTTP_PROXY"; Value = $httpProxy },
    @{ Name = "HTTPS_PROXY"; Value = $httpProxy },
    @{ Name = "ALL_PROXY"; Value = $socksProxy },
    @{ Name = "http_proxy"; Value = $httpProxy },
    @{ Name = "https_proxy"; Value = $httpProxy },
    @{ Name = "all_proxy"; Value = $socksProxy },
    @{ Name = "NO_PROXY"; Value = $noProxy },
    @{ Name = "no_proxy"; Value = $noProxy }
)

foreach ($entry in $vars) {
    [Environment]::SetEnvironmentVariable($entry.Name, $entry.Value, "User")
    [Environment]::SetEnvironmentVariable($entry.Name, $entry.Value, "Process")
}

$toolResults = [ordered]@{}
if (-not $SkipToolConfig) {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        & git config --global http.proxy $httpProxy 2>$null
        & git config --global https.proxy $httpProxy 2>$null
        $toolResults.git = "configured"
    } else {
        $toolResults.git = "not found"
    }

    if (Get-Command npm -ErrorAction SilentlyContinue) {
        & npm config set proxy $httpProxy 2>$null
        & npm config set https-proxy $httpProxy 2>$null
        $toolResults.npm = "configured"
    } else {
        $toolResults.npm = "not found"
    }
}

$result = [ordered]@{
    os = "windows"
    userEnvironmentWritten = $vars
    toolResults = $toolResults
    proxyPortOpen = Test-GeoTcpPort $ProxyHost $HttpPort
    note = "Restart Claude Code from a new terminal so it inherits the updated user environment."
}

if ($Json) {
    $result | ConvertTo-Json -Depth 6
    exit 0
}

Write-GeoSection "Claude Code Geo Fix (Windows)"
Write-GeoKV "HTTP_PROXY" $httpProxy
Write-GeoKV "ALL_PROXY" $socksProxy
Write-GeoKV "NO_PROXY" $noProxy
Write-GeoKV "proxyPortOpen" $result.proxyPortOpen

Write-GeoSection "Tool Proxy Config"
foreach ($key in $toolResults.Keys) {
    Write-GeoKV $key $toolResults[$key]
}

Write-GeoSection "Next Step"
Write-Host $result.note

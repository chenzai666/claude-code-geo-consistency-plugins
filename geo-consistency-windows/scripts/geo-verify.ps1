param(
    [string]$ProxyHost = "127.0.0.1",
    [int]$HttpPort = 10808,
    [int]$SocksPort = 10808,
    [switch]$Json
)

. "$PSScriptRoot\geo-common.ps1"

$httpProxy = Get-GeoDefaultProxyUrl $ProxyHost $HttpPort
$envState = Get-GeoEnvProxyState
$systemProxy = Get-GeoWindowsSystemProxy
$toolState = Get-GeoToolProxyState
$target = "https://api.anthropic.com/cdn-cgi/trace"

$forcedDirect = Invoke-GeoTrace $target -ForceDirect
$envDefault = Invoke-GeoTrace $target
$explicitProxy = Invoke-GeoTrace $target -Proxy $httpProxy
$claudeWebProxy = Invoke-GeoTrace "https://claude.ai/cdn-cgi/trace" -Proxy $httpProxy

$expectedLoc = $explicitProxy.loc
$checks = [ordered]@{
    proxyPortOpen = Test-GeoTcpPort $ProxyHost $HttpPort
    terminalHasHttpProxy = [bool]$envState.effectiveHttpProxy
    terminalHasHttpsProxy = [bool]$envState.effectiveHttpsProxy
    terminalHasAllProxy = [bool]$envState.effectiveAllProxy
    windowsSystemProxyEnabled = [bool]$systemProxy.ProxyEnable
    explicitProxyWorks = [bool]$explicitProxy.ok
    anthropicProxyLocation = $expectedLoc
    envDefaultMatchesExplicit = ($envDefault.ok -and $explicitProxy.ok -and $envDefault.ip -eq $explicitProxy.ip)
    claudeWebMatchesAnthropic = ($claudeWebProxy.ok -and $explicitProxy.ok -and $claudeWebProxy.loc -eq $explicitProxy.loc)
}

$result = [ordered]@{
    os = "windows"
    expectedProxy = $httpProxy
    checks = $checks
    traces = [ordered]@{
        forcedDirect = $forcedDirect
        envDefault = $envDefault
        explicitProxy = $explicitProxy
        claudeWebViaProxy = $claudeWebProxy
    }
    environment = $envState
    windowsSystemProxy = $systemProxy
    tools = $toolState
}

if ($Json) {
    $result | ConvertTo-Json -Depth 8
    exit 0
}

Write-GeoSection "Claude Code Geo Verify (Windows)"
Write-GeoKV "Expected proxy" $httpProxy

Write-GeoSection "Checks"
foreach ($key in $checks.Keys) {
    Write-GeoKV $key $checks[$key]
}

Write-GeoSection "Trace Summary"
foreach ($name in $result.traces.Keys) {
    $trace = $result.traces[$name]
    Write-Host ""
    Write-GeoKV "route" $name
    Write-GeoKV "ok" $trace.ok
    Write-GeoKV "ip" $trace.ip
    Write-GeoKV "loc" $trace.loc
    Write-GeoKV "colo" $trace.colo
    if (-not $trace.ok) {
        Write-GeoKV "error" $trace.error
    }
}

Write-GeoSection "Verdict"
if (-not $checks.proxyPortOpen) {
    Write-Host "FAIL: local proxy port is not reachable."
} elseif (-not $checks.explicitProxyWorks) {
    Write-Host "FAIL: explicit proxy route cannot reach Anthropic trace."
} elseif (-not $checks.envDefaultMatchesExplicit) {
    if (-not $checks.terminalHasHttpProxy -or -not $checks.terminalHasHttpsProxy) {
        Write-Host "WARN: explicit proxy works, but Claude Code's terminal env lacks effective HTTP/HTTPS proxy variables."
    } else {
        Write-Host "WARN: terminal default route does not match explicit proxy route."
    }
} else {
    Write-Host "OK: Claude Code terminal egress is consistent with the explicit proxy route."
}

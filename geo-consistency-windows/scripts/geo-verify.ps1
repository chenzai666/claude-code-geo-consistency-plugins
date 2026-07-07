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

function Format-GeoMarkdownCell {
    param([object]$Value)
    if ($null -eq $Value -or [string]$Value -eq "") {
        return "-"
    }
    return ([string]$Value) -replace "\|", "\|" -replace "(`r`n|`n|`r)", "<br>"
}

function Get-GeoObjectValue {
    param([object]$Object, [string]$Name)
    if ($null -eq $Object) {
        return ""
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return ""
    }
    return $property.Value
}

if (-not $checks.proxyPortOpen) {
    $verdict = "FAIL: local proxy port is not reachable."
} elseif (-not $checks.explicitProxyWorks) {
    $verdict = "FAIL: explicit proxy route cannot reach Anthropic trace."
} elseif (-not $checks.envDefaultMatchesExplicit) {
    if (-not $checks.terminalHasHttpProxy -or -not $checks.terminalHasHttpsProxy) {
        $verdict = "WARN: explicit proxy works, but Claude Code's terminal env lacks effective HTTP/HTTPS proxy variables."
    } else {
        $verdict = "WARN: terminal default route does not match explicit proxy route."
    }
} else {
    $verdict = "OK: Claude Code terminal egress is consistent with the explicit proxy route."
}

Write-Host "## Claude Code Geo Verify (Windows)"
Write-Host ""
Write-Host "| Item | Value |"
Write-Host "|---|---|"
Write-Host ("| Expected proxy | {0} |" -f (Format-GeoMarkdownCell $httpProxy))
Write-Host ("| Verdict | {0} |" -f (Format-GeoMarkdownCell $verdict))
Write-Host ""
Write-Host "### Checks"
Write-Host ""
Write-Host "| Check | Value |"
Write-Host "|---|---|"
foreach ($key in $checks.Keys) {
    Write-Host ("| {0} | {1} |" -f (Format-GeoMarkdownCell $key), (Format-GeoMarkdownCell $checks[$key]))
}
Write-Host ""
Write-Host "### Trace Summary"
Write-Host ""
Write-Host "| Route | OK | IP | Location | Colo | Error |"
Write-Host "|---|---|---|---|---|---|"
foreach ($name in $result.traces.Keys) {
    $trace = $result.traces[$name]
    Write-Host ("| {0} | {1} | {2} | {3} | {4} | {5} |" -f `
        (Format-GeoMarkdownCell $name), `
        (Format-GeoMarkdownCell $trace.ok), `
        (Format-GeoMarkdownCell $trace.ip), `
        (Format-GeoMarkdownCell $trace.loc), `
        (Format-GeoMarkdownCell $trace.colo), `
        (Format-GeoMarkdownCell (Get-GeoObjectValue $trace "error")))
}

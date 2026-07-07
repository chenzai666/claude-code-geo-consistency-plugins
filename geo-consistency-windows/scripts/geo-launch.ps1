param(
    [string]$ProxyHost = "127.0.0.1",
    [int]$HttpPort = 10808,
    [int]$SocksPort = 10808,
    [string]$IpinfoToken = $env:IPINFO_TOKEN,
    [string]$ClaudeCommand = "claude",
    [switch]$PrintOnly,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ClaudeArgs
)

. "$PSScriptRoot\geo-common.ps1"

$httpProxy = Get-GeoDefaultProxyUrl $ProxyHost $HttpPort
$socksProxy = Get-GeoDefaultSocksUrl $ProxyHost $SocksPort
$exitProfile = Invoke-GeoIpProfile -Proxy $httpProxy -IpinfoToken $IpinfoToken

if (-not $exitProfile.ok) {
    Write-Error "Could not detect proxy exit profile: $($exitProfile.error)"
    exit 1
}

$localeBundle = Get-GeoLocaleBundle $exitProfile.countryCode $exitProfile.timezone
$noProxy = if ($env:NO_PROXY) { $env:NO_PROXY } elseif ($env:no_proxy) { $env:no_proxy } else { "localhost,127.0.0.1,::1" }
$envValues = @(
    [pscustomobject]@{ Name = "HTTP_PROXY"; Value = $httpProxy }
    [pscustomobject]@{ Name = "HTTPS_PROXY"; Value = $httpProxy }
    [pscustomobject]@{ Name = "ALL_PROXY"; Value = $socksProxy }
    [pscustomobject]@{ Name = "NO_PROXY"; Value = $noProxy }
    [pscustomobject]@{ Name = "http_proxy"; Value = $httpProxy }
    [pscustomobject]@{ Name = "https_proxy"; Value = $httpProxy }
    [pscustomobject]@{ Name = "all_proxy"; Value = $socksProxy }
    [pscustomobject]@{ Name = "no_proxy"; Value = $noProxy }
    [pscustomobject]@{ Name = "TZ"; Value = $localeBundle.timezone }
    [pscustomobject]@{ Name = "LANG"; Value = $localeBundle.posixLocale }
    [pscustomobject]@{ Name = "LC_ALL"; Value = $localeBundle.posixLocale }
    [pscustomobject]@{ Name = "LC_MESSAGES"; Value = $localeBundle.posixLocale }
    [pscustomobject]@{ Name = "LANGUAGE"; Value = $localeBundle.language }
    [pscustomobject]@{ Name = "ACCEPT_LANGUAGE"; Value = $localeBundle.acceptLanguage }
)

Write-Host "## Claude Code Geo Launch Profile"
Write-Host ""
Write-Host "| Field | Value |"
Write-Host "|---|---|"
Write-Host "| exitProvider | $($exitProfile.provider) |"
Write-Host "| exitIp | $($exitProfile.ip) |"
Write-Host "| exitLocation | $($exitProfile.countryCode) / $($exitProfile.region) / $($exitProfile.city) |"
Write-Host "| exitTimezone | $($exitProfile.timezone) |"
Write-Host "| language | $($localeBundle.language) |"
Write-Host "| posixLocale | $($localeBundle.posixLocale) |"
Write-Host "| acceptLanguage | $($localeBundle.acceptLanguage) |"
Write-Host ""

Write-Host "### Applied Process Environment"
Write-Host ""
Write-Host "| Name | Value |"
Write-Host "|---|---|"
foreach ($item in $envValues) {
    Write-Host "| $($item.Name) | $($item.Value) |"
}
Write-Host ""

if ($PrintOnly) {
    Write-Host "PrintOnly=true; Claude Code was not launched."
    exit 0
}

foreach ($item in $envValues) {
    [Environment]::SetEnvironmentVariable($item.Name, [string]$item.Value, "Process")
}

$command = Get-Command $ClaudeCommand -ErrorAction SilentlyContinue
if (-not $command) {
    Write-Error "Claude command not found: $ClaudeCommand"
    exit 1
}

Write-Host "Launching: $ClaudeCommand $($ClaudeArgs -join ' ')"
& $ClaudeCommand @ClaudeArgs
exit $LASTEXITCODE

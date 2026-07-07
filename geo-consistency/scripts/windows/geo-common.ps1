Set-StrictMode -Version Latest

function Test-GeoTcpPort {
    param(
        [string]$HostName,
        [int]$Port,
        [int]$TimeoutMs = 800
    )

    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $async = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne($TimeoutMs)) {
            return $false
        }
        $client.EndConnect($async)
        return $true
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

function Get-GeoEnvProxyState {
    $processEnv = [Environment]::GetEnvironmentVariables("Process")

    function Read-ProcessEnvValue {
        param([string]$Name)

        if ($processEnv.Contains($Name)) {
            return [string]$processEnv[$Name]
        }

        foreach ($key in $processEnv.Keys) {
            if ([string]::Equals([string]$key, $Name, [System.StringComparison]::OrdinalIgnoreCase)) {
                return [string]$processEnv[$key]
            }
        }

        return ""
    }

    function Read-FirstProcessEnvValue {
        param([string[]]$Names)

        foreach ($name in $Names) {
            $value = Read-ProcessEnvValue $name
            if ($value) {
                return $value
            }
        }

        return ""
    }

    $names = @(
        "HTTP_PROXY", "http_proxy",
        "HTTPS_PROXY", "https_proxy",
        "ALL_PROXY", "all_proxy",
        "NO_PROXY", "no_proxy",
        "ANTHROPIC_BASE_URL", "TZ", "LANG", "LC_ALL"
    )
    $state = [ordered]@{}
    foreach ($name in $names) {
        $state[$name] = Read-ProcessEnvValue $name
    }
    $state["effectiveHttpProxy"] = Read-FirstProcessEnvValue @("HTTP_PROXY", "http_proxy")
    $state["effectiveHttpsProxy"] = Read-FirstProcessEnvValue @("HTTPS_PROXY", "https_proxy")
    $state["effectiveAllProxy"] = Read-FirstProcessEnvValue @("ALL_PROXY", "all_proxy")
    $state["effectiveNoProxy"] = Read-FirstProcessEnvValue @("NO_PROXY", "no_proxy")
    return $state
}

function Get-GeoWindowsSystemProxy {
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $props = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
    function Read-ProxyProperty($Name) {
        if ($null -eq $props) {
            return ""
        }
        $property = $props.PSObject.Properties[$Name]
        if ($null -eq $property) {
            return ""
        }
        return $property.Value
    }
    return [ordered]@{
        ProxyEnable = [bool](Read-ProxyProperty "ProxyEnable")
        ProxyServer = [string](Read-ProxyProperty "ProxyServer")
        AutoConfigURL = [string](Read-ProxyProperty "AutoConfigURL")
    }
}

function Get-GeoToolProxyState {
    $gitHttp = ""
    $gitHttps = ""
    $npmProxy = ""
    $npmHttpsProxy = ""

    if (Get-Command git -ErrorAction SilentlyContinue) {
        $gitHttp = (& git config --global --get http.proxy 2>$null) -join ""
        $gitHttps = (& git config --global --get https.proxy 2>$null) -join ""
    }

    $npm = Get-Command npm -ErrorAction SilentlyContinue
    if ($npm) {
        $npmProxy = (& npm config get proxy 2>$null) -join ""
        $npmHttpsProxy = (& npm config get https-proxy 2>$null) -join ""
    }

    return [ordered]@{
        gitHttpProxy = $gitHttp
        gitHttpsProxy = $gitHttps
        npmProxy = $npmProxy
        npmHttpsProxy = $npmHttpsProxy
    }
}

function ConvertTo-GeoTraceObject {
    param([string]$Text)

    $result = [ordered]@{}
    foreach ($line in ($Text -split "`r?`n")) {
        if ($line -match "^([^=]+)=(.*)$") {
            $result[$matches[1]] = $matches[2]
        }
    }
    return $result
}

function Invoke-GeoTrace {
    param(
        [string]$Url,
        [string]$Proxy = "",
        [switch]$ForceDirect
    )

    if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
        return [ordered]@{ ok = $false; error = "curl.exe not found"; url = $Url }
    }

    $args = @("-sS", "--connect-timeout", "5", "--max-time", "12")
    if ($ForceDirect) {
        $args += @("--noproxy", "*")
    }
    if ($Proxy) {
        $args += @("--proxy", $Proxy)
    }
    $args += $Url

    try {
        $output = & curl.exe @args 2>&1
        if ($LASTEXITCODE -ne 0) {
            return [ordered]@{ ok = $false; url = $Url; proxy = $Proxy; error = ($output -join "`n") }
        }
        $trace = ConvertTo-GeoTraceObject (($output -join "`n"))
        return [ordered]@{
            ok = $true
            url = $Url
            proxy = $Proxy
            ip = $trace.ip
            loc = $trace.loc
            colo = $trace.colo
            warp = $trace.warp
            raw = $trace
        }
    } catch {
        return [ordered]@{ ok = $false; url = $Url; proxy = $Proxy; error = $_.Exception.Message }
    }
}

function Invoke-GeoHttpJson {
    param(
        [string]$Url,
        [string]$Proxy = ""
    )

    if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
        return [ordered]@{ ok = $false; error = "curl.exe not found"; url = $Url }
    }

    $args = @("-sS", "--connect-timeout", "5", "--max-time", "12")
    if ($Proxy) {
        $args += @("--proxy", $Proxy)
    }
    $args += $Url

    try {
        $output = & curl.exe @args 2>&1
        if ($LASTEXITCODE -ne 0) {
            return [ordered]@{ ok = $false; url = $Url; error = ($output -join "`n") }
        }

        $text = ($output -join "`n")
        return [ordered]@{
            ok = $true
            url = $Url
            json = ($text | ConvertFrom-Json)
            raw = $text
        }
    } catch {
        return [ordered]@{ ok = $false; url = $Url; error = $_.Exception.Message }
    }
}

function Get-GeoPropertyValue {
    param([object]$Object, [string]$Name)

    if ($null -eq $Object) {
        return ""
    }

    if ($Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) {
        if ($null -eq $Object[$Name]) {
            return ""
        }
        return [string]$Object[$Name]
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return ""
    }

    return [string]$property.Value
}

function ConvertTo-GeoNumberString {
    param([object]$Value)

    if ($null -eq $Value -or [string]$Value -eq "") {
        return ""
    }

    return [string]$Value
}

function ConvertTo-GeoIpInfoProfile {
    param([object]$Json, [string]$Provider)

    $loc = Get-GeoPropertyValue $Json "loc"
    $lat = ""
    $lon = ""
    if ($loc -match "^([^,]+),([^,]+)$") {
        $lat = $matches[1]
        $lon = $matches[2]
    }

    $countryCode = Get-GeoPropertyValue $Json "country"
    return [ordered]@{
        ok = [bool](Get-GeoPropertyValue $Json "ip")
        provider = $Provider
        ip = Get-GeoPropertyValue $Json "ip"
        countryCode = $countryCode.ToUpperInvariant()
        country = ""
        region = Get-GeoPropertyValue $Json "region"
        city = Get-GeoPropertyValue $Json "city"
        latitude = $lat
        longitude = $lon
        isp = Get-GeoPropertyValue $Json "org"
        timezone = Get-GeoPropertyValue $Json "timezone"
        raw = $Json
    }
}

function ConvertTo-GeoIpApiProfile {
    param([object]$Json, [string]$Provider)

    $countryCode = Get-GeoPropertyValue $Json "country_code"
    return [ordered]@{
        ok = [bool](Get-GeoPropertyValue $Json "ip")
        provider = $Provider
        ip = Get-GeoPropertyValue $Json "ip"
        countryCode = $countryCode.ToUpperInvariant()
        country = Get-GeoPropertyValue $Json "country_name"
        region = Get-GeoPropertyValue $Json "region"
        city = Get-GeoPropertyValue $Json "city"
        latitude = ConvertTo-GeoNumberString (Get-GeoPropertyValue $Json "latitude")
        longitude = ConvertTo-GeoNumberString (Get-GeoPropertyValue $Json "longitude")
        isp = Get-GeoPropertyValue $Json "org"
        timezone = Get-GeoPropertyValue $Json "timezone"
        raw = $Json
    }
}

function ConvertTo-GeoIpWhoIsProfile {
    param([object]$Json, [string]$Provider)

    $countryCode = Get-GeoPropertyValue $Json "country_code"
    $connection = $Json.PSObject.Properties["connection"]
    $isp = ""
    if ($null -ne $connection -and $null -ne $connection.Value) {
        $isp = Get-GeoPropertyValue $connection.Value "isp"
        if (-not $isp) {
            $isp = Get-GeoPropertyValue $connection.Value "org"
        }
    }

    return [ordered]@{
        ok = [bool]$Json.success
        provider = $Provider
        ip = Get-GeoPropertyValue $Json "ip"
        countryCode = $countryCode.ToUpperInvariant()
        country = Get-GeoPropertyValue $Json "country"
        region = Get-GeoPropertyValue $Json "region"
        city = Get-GeoPropertyValue $Json "city"
        latitude = ConvertTo-GeoNumberString (Get-GeoPropertyValue $Json "latitude")
        longitude = ConvertTo-GeoNumberString (Get-GeoPropertyValue $Json "longitude")
        isp = $isp
        timezone = Get-GeoPropertyValue $Json "timezone"
        raw = $Json
    }
}

function Invoke-GeoIpProfile {
    param(
        [string]$Proxy = "",
        [string]$IpinfoToken = ""
    )

    $providers = @(
        [ordered]@{ name = "ipapi"; url = "https://ipapi.co/json/"; parser = "ipapi" },
        [ordered]@{ name = "ipinfo"; url = $(if ($IpinfoToken) { "https://ipinfo.io/json?token=$IpinfoToken" } else { "https://ipinfo.io/json" }); parser = "ipinfo" },
        [ordered]@{ name = "ipwhois"; url = "https://ipwho.is/"; parser = "ipwhois" }
    )

    $errors = @()
    foreach ($provider in $providers) {
        $response = Invoke-GeoHttpJson $provider.url -Proxy $Proxy
        if (-not $response.ok) {
            $errors += "$($provider.name): $($response.error)"
            continue
        }

        if ($provider.parser -eq "ipapi") {
            $profile = ConvertTo-GeoIpApiProfile $response.json $provider.name
        } elseif ($provider.parser -eq "ipinfo") {
            $profile = ConvertTo-GeoIpInfoProfile $response.json $provider.name
        } else {
            $profile = ConvertTo-GeoIpWhoIsProfile $response.json $provider.name
        }

        if ($profile.ok -and $profile.ip -and $profile.countryCode -and $profile.timezone) {
            return $profile
        }

        $errors += "$($provider.name): incomplete profile"
    }

    return [ordered]@{
        ok = $false
        provider = ""
        ip = ""
        countryCode = ""
        country = ""
        region = ""
        city = ""
        latitude = ""
        longitude = ""
        isp = ""
        timezone = ""
        error = ($errors -join "; ")
    }
}

function Get-GeoLocaleBundle {
    param([string]$CountryCode, [string]$TimeZone = "")

    $code = ([string]$CountryCode).ToUpperInvariant()
    $language = switch ($code) {
        "CN" { "zh-CN"; break }
        "HK" { "zh-HK"; break }
        "MO" { "zh-MO"; break }
        "TW" { "zh-TW"; break }
        "US" { "en-US"; break }
        "GB" { "en-GB"; break }
        "CA" { "en-CA"; break }
        "AU" { "en-AU"; break }
        "NZ" { "en-NZ"; break }
        "SG" { "en-SG"; break }
        "JP" { "ja-JP"; break }
        "KR" { "ko-KR"; break }
        "DE" { "de-DE"; break }
        "FR" { "fr-FR"; break }
        "IT" { "it-IT"; break }
        "ES" { "es-ES"; break }
        "NL" { "nl-NL"; break }
        "BR" { "pt-BR"; break }
        "PT" { "pt-PT"; break }
        "RU" { "ru-RU"; break }
        "IN" { "en-IN"; break }
        "ID" { "id-ID"; break }
        "TH" { "th-TH"; break }
        "VN" { "vi-VN"; break }
        "PH" { "en-PH"; break }
        "MY" { "ms-MY"; break }
        default { "en-US"; break }
    }

    if ($code -eq "CA" -and $TimeZone -like "America/Montreal*") {
        $language = "fr-CA"
    }

    $base = ($language -split "-")[0]
    $posix = "$($language.Replace("-", "_")).UTF-8"
    return [ordered]@{
        language = $language
        languages = @($language, $base)
        acceptLanguage = "$language,$base;q=0.9"
        posixLocale = $posix
        timezone = $TimeZone
    }
}

function Get-GeoNodeRuntimeProfile {
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        return [ordered]@{ ok = $false; error = "node not found" }
    }

    $script = "const profile={ok:true,timezone:Intl.DateTimeFormat().resolvedOptions().timeZone||'',dateTimeLocale:Intl.DateTimeFormat().resolvedOptions().locale||'',numberLocale:Intl.NumberFormat().resolvedOptions().locale||'',collatorLocale:Intl.Collator().resolvedOptions().locale||'',offsetNow:new Date().getTimezoneOffset(),offsetJanuary:new Date('2026-01-15T12:00:00Z').getTimezoneOffset(),offsetJuly:new Date('2026-07-15T12:00:00Z').getTimezoneOffset()};console.log(JSON.stringify(profile));"

    try {
        $output = & node -e $script 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $output) {
            return [ordered]@{ ok = $false; error = "node runtime probe failed" }
        }
        return (($output -join "`n") | ConvertFrom-Json)
    } catch {
        return [ordered]@{ ok = $false; error = $_.Exception.Message }
    }
}

function Get-GeoRuntimeProfile {
    $node = Get-GeoNodeRuntimeProfile
    $timeZoneId = ""
    try {
        $timeZoneId = (Get-TimeZone).Id
    } catch {
        $timeZoneId = [System.TimeZoneInfo]::Local.Id
    }

    return [ordered]@{
        os = "windows"
        envTimezone = [string]$env:TZ
        systemTimezone = $timeZoneId
        nodeTimezone = Get-GeoPropertyValue $node "timezone"
        culture = [System.Globalization.CultureInfo]::CurrentCulture.Name
        uiCulture = [System.Globalization.CultureInfo]::CurrentUICulture.Name
        nodeDateTimeLocale = Get-GeoPropertyValue $node "dateTimeLocale"
        nodeNumberLocale = Get-GeoPropertyValue $node "numberLocale"
        LANG = [string]$env:LANG
        LC_ALL = [string]$env:LC_ALL
        LC_MESSAGES = [string]$env:LC_MESSAGES
        LANGUAGE = [string]$env:LANGUAGE
        node = $node
    }
}

function Test-GeoLocaleMatch {
    param([string]$Actual, [string]$Expected)

    if (-not $Actual -or -not $Expected) {
        return $false
    }

    $left = $Actual.Replace("_", "-").Replace(".UTF-8", "").Replace(".utf8", "").ToLowerInvariant()
    $right = $Expected.Replace("_", "-").Replace(".UTF-8", "").Replace(".utf8", "").ToLowerInvariant()
    return ($left -eq $right -or $left.StartsWith(($right -split "-")[0] + "-"))
}

function Get-GeoRuntimeProfileChecks {
    param([object]$Runtime, [object]$ExitProfile, [object]$LocaleBundle)

    $expectedTz = Get-GeoPropertyValue $ExitProfile "timezone"
    $runtimeTz = Get-GeoPropertyValue $Runtime "envTimezone"
    if (-not $runtimeTz) {
        $runtimeTz = Get-GeoPropertyValue $Runtime "nodeTimezone"
    }

    $expectedLocale = Get-GeoPropertyValue $LocaleBundle "language"
    $lang = Get-GeoPropertyValue $Runtime "LANG"
    $lcAll = Get-GeoPropertyValue $Runtime "LC_ALL"
    $nodeLocale = Get-GeoPropertyValue $Runtime "nodeDateTimeLocale"

    return [ordered]@{
        exitCountryCode = Get-GeoPropertyValue $ExitProfile "countryCode"
        exitTimezone = $expectedTz
        runtimeTimezone = $runtimeTz
        timezoneMatchesExit = [bool]($expectedTz -and $runtimeTz -eq $expectedTz)
        expectedLanguage = $expectedLocale
        runtimeLANG = $lang
        runtimeLC_ALL = $lcAll
        nodeDateTimeLocale = $nodeLocale
        languageEnvMatchesExit = [bool]((Test-GeoLocaleMatch $lang $expectedLocale) -or (Test-GeoLocaleMatch $lcAll $expectedLocale))
        nodeLocaleMatchesExit = [bool](Test-GeoLocaleMatch $nodeLocale $expectedLocale)
    }
}

function Write-GeoSection {
    param([string]$Title)
    Write-Host ""
    Write-Host "== $Title =="
}

function Write-GeoKV {
    param([string]$Key, [object]$Value)
    if ($null -eq $Value -or [string]$Value -eq "") {
        $Value = "-"
    } elseif ($Value -is [System.Array]) {
        $Value = ($Value -join ",")
    }
    Write-Host ("{0,-24} {1}" -f ($Key + ":"), $Value)
}

function Get-GeoDefaultProxyUrl {
    param([string]$ProxyHost, [int]$HttpPort)
    return "http://${ProxyHost}:${HttpPort}"
}

function Get-GeoDefaultSocksUrl {
    param([string]$ProxyHost, [int]$SocksPort)
    return "socks5://${ProxyHost}:${SocksPort}"
}

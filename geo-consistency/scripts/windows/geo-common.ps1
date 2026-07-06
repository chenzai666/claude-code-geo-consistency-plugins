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
    $names = @(
        "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY",
        "ANTHROPIC_BASE_URL", "TZ", "LANG", "LC_ALL"
    )
    $state = [ordered]@{}
    foreach ($name in $names) {
        $state[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
    }
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

function Write-GeoSection {
    param([string]$Title)
    Write-Host ""
    Write-Host "== $Title =="
}

function Write-GeoKV {
    param([string]$Key, [object]$Value)
    if ($null -eq $Value -or [string]$Value -eq "") {
        $Value = "-"
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

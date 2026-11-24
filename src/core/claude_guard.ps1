[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$LogPath = "C:\Scripts\guard.log"
$UpdaterPath = "C:\Scripts\update_claude_fw.ps1"

function Write-GuardLog($msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $msg"
    Add-Content -Path $LogPath -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
}

function Get-CurrentCountry {
    $vpn = Get-NetAdapter -Name "AmneziaVPN" -ErrorAction SilentlyContinue
    if (-not $vpn -or $vpn.Status -ne "Up") { return "DISCONNECTED" }

    try {
        $u1 = "https://www.cloudflare.com/cdn-cgi/trace"
        $trace = Invoke-RestMethod -Uri $u1 -TimeoutSec 4
        if ($trace -match "loc=([A-Z]{2})") { return $matches[1] }
    } catch {}

    try {
        $u2 = "https://ipinfo.io/country"
        $c2 = (Invoke-RestMethod -Uri $u2 -TimeoutSec 4).Trim()
        if ($c2 -match "^[A-Z]{2}$") { return $c2 }
    } catch {}

    try {
        $u3 = "https://api.country.is"
        $c3 = (Invoke-RestMethod -Uri $u3 -TimeoutSec 4).country
        if ($c3 -match "^[A-Z]{2}$") { return $c3 }
    } catch {}

    return "ERROR"
}

if (Test-Path $UpdaterPath) { & $UpdaterPath }
$script:CachedCountry = Get-CurrentCountry
$script:LastAdapterCount = (Get-NetAdapter).Count

Register-CimIndicationEvent -Query "SELECT * FROM Win32_ProcessStartTrace WHERE ProcessName = 'claude.exe'" -SourceIdentifier "ClaudeStartWatch" | Out-Null

$counter = 0
while ($true) {
    $ev = Wait-Event -SourceIdentifier "ClaudeStartWatch" -Timeout 15
    if ($ev) {
        Remove-Event -EventIdentifier $ev.EventIdentifier
        if ($script:CachedCountry -ne "US") {
            $script:CachedCountry = Get-CurrentCountry
            if ($script:CachedCountry -ne "US") {
                Stop-Process -Name "Claude" -Force -ErrorAction SilentlyContinue
                Write-GuardLog "Killed at start. Reason/Country: $($script:CachedCountry)"
            }
        }
    } else {
        $script:CachedCountry = Get-CurrentCountry
        if ((Get-Process -Name "Claude" -ErrorAction SilentlyContinue) -and ($script:CachedCountry -ne "US")) {
            Start-Sleep -Seconds 1
            $script:CachedCountry = Get-CurrentCountry
            if ($script:CachedCountry -ne "US") {
                Stop-Process -Name "Claude" -Force -ErrorAction SilentlyContinue
                Write-GuardLog "Killed in background. Reason/Country: $($script:CachedCountry)"
            }
        }
    }

    $currentAdapterCount = (Get-NetAdapter).Count
    if ($currentAdapterCount -ne $script:LastAdapterCount) {
        $script:LastAdapterCount = $currentAdapterCount
        if (Test-Path $UpdaterPath) { & $UpdaterPath }
    }

    $counter++
    if ($counter -ge 240) {
        if (Test-Path $UpdaterPath) { & $UpdaterPath }
        $counter = 0
    }
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Windows.Forms

$vpn = Get-NetAdapter -Name "AmneziaVPN" -ErrorAction SilentlyContinue
if (-not $vpn -or $vpn.Status -ne "Up") {
    [System.Windows.Forms.MessageBox]::Show("AmneziaVPN отключен! Включите локацию США перед запуском.", "Защита Claude", 0, 16) | Out-Null
    exit
}

$country = "ERROR"
try {
    $trace = Invoke-RestMethod -Uri "https://www.cloudflare.com/cdn-cgi/trace" -TimeoutSec 4
    if ($trace -match "loc=([A-Z]{2})") { $country = $matches[1] }
} catch {}

if ($country -notmatch "^[A-Z]{2}$") {
    try {
        $country = (Invoke-RestMethod -Uri "https://ipinfo.io/country" -TimeoutSec 4).Trim()
    } catch {}
}

if ($country -notmatch "^[A-Z]{2}$") {
    try {
        $country = (Invoke-RestMethod -Uri "https://api.country.is" -TimeoutSec 4).country
    } catch {}
}

if ($country -eq "US") {
    $pkg = Get-AppxPackage *Claude* | Select-Object -First 1
    if ($pkg) {
        Start-Process "shell:AppsFolder\$($pkg.PackageFamilyName)!Claude"
    } else {
        $exe = Get-ChildItem "$env:LOCALAPPDATA\AnthropicClaude" -Recurse -Filter "claude.exe" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($exe) { Start-Process $exe.FullName }
    }
} elseif ($country -eq "ERROR") {
    [System.Windows.Forms.MessageBox]::Show("Не удалось проверить страну (нет ответа от серверов проверки IP).", "Защита Claude", 0, 16) | Out-Null
} else {
    [System.Windows.Forms.MessageBox]::Show("Запуск заблокирован! Текущая страна VPN: $country. Переключите AmneziaVPN на США.", "Защита Claude", 0, 48) | Out-Null
}

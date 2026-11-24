function Get-ClaudeExePath {
    $pkg = Get-AppxPackage *Claude* | Select-Object -First 1
    if ($pkg) {
        $p = Join-Path $pkg.InstallLocation "app\claude.exe"
        if (Test-Path $p) { return $p }
        $found = Get-ChildItem $pkg.InstallLocation -Recurse -Filter "claude.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    $localPath = "$env:LOCALAPPDATA\AnthropicClaude"
    if (Test-Path $localPath) {
        $found = Get-ChildItem $localPath -Recurse -Filter "claude.exe" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

$exePath = Get-ClaudeExePath
if (-not $exePath) { exit 1 }

$otherAdapters = Get-NetAdapter | Where-Object { $_.Name -ne "AmneziaVPN" } | Select-Object -ExpandProperty Name

# 1. Temporary Lockdown (Zero-Downtime)
New-NetFirewallRule -DisplayName "ClaudeGuard_TempLockdown" -Direction Outbound -Program $exePath -Action Block -ErrorAction SilentlyContinue | Out-Null

# 2. Remove old ClaudeGuard rules and legacy manual rules for claude.exe
Get-NetFirewallRule -DisplayName "ClaudeGuard*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -ne "ClaudeGuard_TempLockdown" } | Remove-NetFirewallRule
Get-NetFirewallApplicationFilter | Where-Object { $_.Program -like "*claude.exe" } | ForEach-Object {
    $rule = $_ | Get-NetFirewallRule -ErrorAction SilentlyContinue
    if ($rule -and $rule.DisplayName -ne "ClaudeGuard_TempLockdown" -and $rule.DisplayName -notlike "Claude*") {
        $rule | Remove-NetFirewallRule -ErrorAction SilentlyContinue
    }
}

# 3. Create fresh rules
New-NetFirewallRule -DisplayName "ClaudeGuard Allow Amnezia IPv4" -Direction Outbound -Program $exePath -InterfaceAlias "AmneziaVPN" -Protocol Any -Action Allow | Out-Null
New-NetFirewallRule -DisplayName "ClaudeGuard Block All IPv6" -Direction Outbound -Program $exePath -RemoteAddress "0:0:0:0:0:0:0:0-ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff" -Action Block | Out-Null

foreach ($adapter in $otherAdapters) {
    New-NetFirewallRule -DisplayName "ClaudeGuard Block [$adapter]" -Direction Outbound -Program $exePath -InterfaceAlias $adapter -Action Block | Out-Null
}

# 4. Release Lockdown
Remove-NetFirewallRule -DisplayName "ClaudeGuard_TempLockdown" -ErrorAction SilentlyContinue

# 5. Update Desktop shortcut icon
$lnkPath = "$env:USERPROFILE\Desktop\Claude (Safe US).lnk"
if (Test-Path $lnkPath) {
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($lnkPath)
    $Shortcut.IconLocation = "$exePath,0"
    $Shortcut.Save()
}

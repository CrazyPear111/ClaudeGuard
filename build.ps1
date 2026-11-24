param(
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SrcDir = Join-Path $RepoRoot "src"
$DocsDir = Join-Path $RepoRoot "docs"
$DistDir = Join-Path $RepoRoot "dist"
$StageDir = Join-Path $DistDir "ClaudeGuard_Installer-v$Version"
$ZipPath = Join-Path $DistDir "ClaudeGuard_Installer-v$Version.zip"

Write-Host "=== СБОРКА РЕЛИЗА CLAUDE GUARD v$Version ===" -ForegroundColor Cyan

# Clean previous stage
if (Test-Path $StageDir) { Remove-Item $StageDir -Recurse -Force }
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
New-Item -ItemType Directory -Force -Path $StageDir | Out-Null

# Read modular sources from src/
$guardCode = Get-Content (Join-Path $SrcDir "core\claude_guard.ps1") -Raw -Encoding UTF8
$updaterCode = Get-Content (Join-Path $SrcDir "core\update_claude_fw.ps1") -Raw -Encoding UTF8
$launcherCode = Get-Content (Join-Path $SrcDir "core\start_claude_safe.ps1") -Raw -Encoding UTF8
$vbsCode = Get-Content (Join-Path $SrcDir "core\guard.vbs") -Raw -Encoding UTF8
$uninstallCode = Get-Content (Join-Path $SrcDir "cli\uninstall_claude_guard.ps1") -Raw -Encoding UTF8
$readmeUser = Get-Content (Join-Path $DocsDir "USER_README.md") -Raw -Encoding UTF8

# Generate self-contained install_claude_guard.ps1 using Base64 payloads to prevent any escaping/encoding issues!
$b64Guard = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($guardCode))
$b64Updater = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($updaterCode))
$b64Launcher = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($launcherCode))
$b64Vbs = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($vbsCode))
$b64Uninstall = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($uninstallCode))
$b64Readme = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($readmeUser))

$installerTemplate = @"
# === АВТОМАТИЧЕСКИЙ УСТАНОВЩИК CLAUDE GUARD v$Version ===
`$ErrorActionPreference = "Stop"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ОШИБКА: Запустите установщик от имени Администратора!" -ForegroundColor Red
    exit 1
}

Write-Host "=== ПРЕДВАРИТЕЛЬНАЯ ПРОВЕРКА СИСТЕМЫ ===" -ForegroundColor Cyan

# Check Claude Desktop
`$exePath = `$null
`$pkg = Get-AppxPackage *Claude* | Select-Object -First 1
if (`$pkg) {
    `$p = Join-Path `$pkg.InstallLocation "app\claude.exe"
    if (Test-Path `$p) { `$exePath = `$p }
    else {
        `$f = Get-ChildItem `$pkg.InstallLocation -Recurse -Filter "claude.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if (`$f) { `$exePath = `$f.FullName }
    }
}
if (-not `$exePath -and (Test-Path "`$env:LOCALAPPDATA\AnthropicClaude")) {
    `$f = Get-ChildItem "`$env:LOCALAPPDATA\AnthropicClaude" -Recurse -Filter "claude.exe" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (`$f) { `$exePath = `$f.FullName }
}
if (-not `$exePath) {
    Write-Host "[ОШИБКА] Claude Desktop не найден на компьютере!" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Найден Claude Desktop: `$exePath" -ForegroundColor Green

# Check AmneziaVPN adapter
`$vpn = Get-NetAdapter -Name "AmneziaVPN" -ErrorAction SilentlyContinue
if (-not `$vpn) {
    Write-Host "[ОШИБКА] Адаптер 'AmneziaVPN' не найден! Включите AmneziaVPN и повторите установку." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Найден адаптер AmneziaVPN (Статус: `$(`$vpn.Status))" -ForegroundColor Green

Write-Host "`nОстановка старых фоновых процессов контроля..." -ForegroundColor Cyan
Stop-ScheduledTask -TaskName "ClaudeVPNCountryGuard" -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "CommandLine LIKE '%Scripts\claude_guard.ps1%'" | Where-Object { `$_.ProcessId -ne `$PID } | ForEach-Object {
    Stop-Process -Id `$_.ProcessId -Force -ErrorAction SilentlyContinue
}

`$dir = "C:\Scripts"
New-Item -ItemType Directory -Force -Path `$dir | Out-Null

# Unpack embedded payloads safely
[IO.File]::WriteAllBytes("`$dir\claude_guard.ps1", [Convert]::FromBase64String("$b64Guard"))
[IO.File]::WriteAllBytes("`$dir\update_claude_fw.ps1", [Convert]::FromBase64String("$b64Updater"))
[IO.File]::WriteAllBytes("`$dir\start_claude_safe.ps1", [Convert]::FromBase64String("$b64Launcher"))
[IO.File]::WriteAllBytes("`$dir\guard.vbs", [Convert]::FromBase64String("$b64Vbs"))
[IO.File]::WriteAllBytes("`$dir\uninstall.ps1", [Convert]::FromBase64String("$b64Uninstall"))
[IO.File]::WriteAllBytes("`$dir\README.md", [Convert]::FromBase64String("$b64Readme"))

Write-Host "Атомарное обновление правил Брандмауэра Windows (без разрыва защиты)..." -ForegroundColor Cyan
& "`$dir\update_claude_fw.ps1"

# Create Desktop shortcut
`$WshShell = New-Object -ComObject WScript.Shell
`$Shortcut = `$WshShell.CreateShortcut("`$env:USERPROFILE\Desktop\Claude (Safe US).lnk")
`$Shortcut.TargetPath = "powershell.exe"
`$Shortcut.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"C:\Scripts\start_claude_safe.ps1`""
`$Shortcut.IconLocation = "`$exePath,0"
`$Shortcut.Save()

# Register Scheduled Task
`$Action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"C:\Scripts\guard.vbs`""
`$Trigger = New-ScheduledTaskTrigger -AtLogOn
`$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Days 0)
Register-ScheduledTask -TaskName "ClaudeVPNCountryGuard" -Action `$Action -Trigger `$Trigger -Settings `$Settings -RunLevel Highest -Force | Out-Null
Start-ScheduledTask -TaskName "ClaudeVPNCountryGuard"

# Wait up to 5 seconds for background process to appear
`$procs = @()
for (`$i = 0; `$i -lt 10; `$i++) {
    Start-Sleep -Milliseconds 500
    `$procs = @(Get-CimInstance Win32_Process -Filter "CommandLine LIKE '%Scripts\claude_guard.ps1%'")
    if (`$procs.Count -gt 0) { break }
}

Add-Content -Path "`$dir\guard.log" -Value "`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - System installed/updated (v$Version). Claude path: `$exePath" -Encoding UTF8

`$ruleCount = @(Get-NetFirewallRule -DisplayName "ClaudeGuard*" -ErrorAction SilentlyContinue).Count
Write-Host "`n=== УСТАНОВКА / ОБНОВЛЕНИЕ ЗАВЕРШЕНО (v$Version) ===" -ForegroundColor Green
Write-Host "Активных правил Брандмауэра : `$ruleCount" -ForegroundColor Cyan
Write-Host "Фоновых процессов контроля : `$(`$procs.Count) (PID: `$(`$procs.ProcessId -join ', '))" -ForegroundColor Cyan
Write-Host "Для запуска используйте ярлык 'Claude (Safe US)' на Рабочем столе." -ForegroundColor White
"@

# Write release files with proper encodings (UTF-8 with BOM for .ps1/.md/.txt, UTF-8 NO BOM for .bat)
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

[IO.File]::WriteAllText((Join-Path $StageDir "install_claude_guard.ps1"), $installerTemplate, $utf8Bom)
[IO.File]::WriteAllText((Join-Path $StageDir "check_claude_guard.ps1"), (Get-Content (Join-Path $SrcDir "cli\check_claude_guard.ps1") -Raw -Encoding UTF8), $utf8Bom)
[IO.File]::WriteAllText((Join-Path $StageDir "uninstall_claude_guard.ps1"), $uninstallCode, $utf8Bom)
[IO.File]::WriteAllText((Join-Path $StageDir "README.md"), $readmeUser, $utf8Bom)
[IO.File]::WriteAllText((Join-Path $StageDir "ИНСТРУКЦИЯ_ПО_УСТАНОВКЕ.txt"), (Get-Content (Join-Path $DocsDir "INSTALL_GUIDE.txt") -Raw -Encoding UTF8), $utf8Bom)

[IO.File]::WriteAllText((Join-Path $StageDir "Install_Claude_Guard.bat"), (Get-Content (Join-Path $SrcDir "wrappers\Install_Claude_Guard.bat") -Raw -Encoding UTF8), $utf8NoBom)
[IO.File]::WriteAllText((Join-Path $StageDir "Check_Claude_Guard.bat"), (Get-Content (Join-Path $SrcDir "wrappers\Check_Claude_Guard.bat") -Raw -Encoding UTF8), $utf8NoBom)
[IO.File]::WriteAllText((Join-Path $StageDir "Uninstall_Claude_Guard.bat"), (Get-Content (Join-Path $SrcDir "wrappers\Uninstall_Claude_Guard.bat") -Raw -Encoding UTF8), $utf8NoBom)

# Create ZIP archive
Compress-Archive -Path "$StageDir\*" -DestinationPath $ZipPath -Force
Write-Host "Готово! Релизный архив собран: $ZipPath" -ForegroundColor Green

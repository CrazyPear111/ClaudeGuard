$ErrorActionPreference = "SilentlyContinue"
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ОШИБКА: Запустите скрипт от имени Администратора!" -ForegroundColor Red
    exit 1
}

Write-Host "Удаление системы защиты ClaudeGuard..." -ForegroundColor Yellow

Stop-ScheduledTask -TaskName "ClaudeVPNCountryGuard"
Unregister-ScheduledTask -TaskName "ClaudeVPNCountryGuard" -Confirm:$false

Get-CimInstance Win32_Process -Filter "CommandLine LIKE '%Scripts\\claude_guard.ps1%'" | Where-Object { $_.ProcessId -ne $PID } | ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force
}

Get-NetFirewallRule -DisplayName "ClaudeGuard*" | Remove-NetFirewallRule
Get-NetFirewallApplicationFilter | Where-Object { $_.Program -like "*claude.exe" } | ForEach-Object {
    $rule = $_ | Get-NetFirewallRule
    if ($rule -and $rule.DisplayName -notlike "Claude*") {
        $rule | Remove-NetFirewallRule
    }
}

Remove-Item "$env:USERPROFILE\Desktop\Claude (Safe US).lnk" -Force
Remove-Item "C:\Scripts" -Recurse -Force

Write-Host "Система защиты ClaudeGuard полностью удалена с компьютера." -ForegroundColor Green

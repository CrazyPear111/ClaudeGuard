[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Write-Host "=== ДИАГНОСТИКА СИСТЕМЫ ЗАЩИТЫ CLAUDE DESKTOP (GEO-GUARD) ===" -ForegroundColor Cyan

Write-Host "`n[1] Задача в Планировщике заданий:" -ForegroundColor Yellow
$task = Get-ScheduledTask -TaskName "ClaudeVPNCountryGuard" -ErrorAction SilentlyContinue
if ($task) {
    Write-Host "    Статус задачи : $($task.State)" -ForegroundColor Green
} else {
    Write-Host "    ОШИБКА: Задача не найдена!" -ForegroundColor Red
}

Write-Host "`n[2] Фоновый процесс контроля:" -ForegroundColor Yellow
$procs = @(Get-CimInstance Win32_Process -Filter "CommandLine LIKE '%Scripts\\claude_guard.ps1%'")
if ($procs.Count -eq 1) {
    Write-Host "    Активен ровно 1 экземпляр (PID: $($procs[0].ProcessId), запущен: $($procs[0].CreationDate))" -ForegroundColor Green
} elseif ($procs.Count -gt 1) {
    Write-Host "    ВНИМАНИЕ: Запущено несколько копий ($($procs.Count))! PIDs: $($procs.ProcessId -join ', ')" -ForegroundColor Red
} else {
    Write-Host "    ОШИБКА: Фоновый процесс не запущен!" -ForegroundColor Red
}

Write-Host "`n[3] Состояние VPN и внешний IP:" -ForegroundColor Yellow
$vpn = Get-NetAdapter -Name "AmneziaVPN" -ErrorAction SilentlyContinue
if ($vpn -and $vpn.Status -eq "Up") {
    Write-Host "    Адаптер       : AmneziaVPN (Статус: Up)" -ForegroundColor Green
    $country = "Не определена"
    try {
        $trace = Invoke-RestMethod -Uri "https://www.cloudflare.com/cdn-cgi/trace" -TimeoutSec 4
        if ($trace -match "loc=([A-Z]{2})") { $country = $matches[1] }
    } catch {}
    if ($country -eq "US") {
        Write-Host "    Страна выхода : $country (ОК - запуск разрешен)" -ForegroundColor Green
    } else {
        Write-Host "    Страна выхода : $country (ВНИМАНИЕ - запуск Claude будет заблокирован)" -ForegroundColor Yellow
    }
} else {
    Write-Host "    Адаптер       : AmneziaVPN отключен или не найден" -ForegroundColor Red
}

Write-Host "`n[4] Правила Брандмауэра Windows (ClaudeGuard*):" -ForegroundColor Yellow
$lockdown = Get-NetFirewallRule -DisplayName "ClaudeGuard_TempLockdown" -ErrorAction SilentlyContinue
if ($lockdown) {
    Write-Host "    ВНИМАНИЕ: Обнаружено зависшее правило ClaudeGuard_TempLockdown!" -ForegroundColor Red
}
$rules = Get-NetFirewallRule -DisplayName "ClaudeGuard*" -ErrorAction SilentlyContinue
if ($rules) {
    $rules | Select-Object DisplayName, Enabled, Action | Format-Table -AutoSize
} else {
    Write-Host "    ОШИБКА: Правила Брандмауэра не найдены!" -ForegroundColor Red
}

Write-Host "[5] Журнал событий (C:\Scripts\guard.log):" -ForegroundColor Yellow
if (Test-Path "C:\Scripts\guard.log") {
    Get-Content "C:\Scripts\guard.log" -Tail 10 | ForEach-Object { Write-Host "    $_" }
} else {
    Write-Host "    Файл журнала еще не создавался." -ForegroundColor Gray
}
Write-Host ""

# ClaudeGuard (AmneziaVPN + US Geo-Guard) — Репозиторий разработки

Многоуровневая система защиты Claude Desktop для Windows, предотвращающая утечку реального IP-адреса или подключение из неразрешенных регионов.

## Структура репозитория

```text
ClaudeGuard/
├── src/
│   ├── core/                     # Модули, устанавливаемые в C:\Scripts\
│   │   ├── claude_guard.ps1      # Фоновый сторож (WMI-перехват 0 мс + кэш IP + автоадаптеры)
│   │   ├── update_claude_fw.ps1  # Атомарное обновление правил Брандмауэра и иконки ярлыка
│   │   ├── start_claude_safe.ps1 # Pre-flight проверка IP перед запуском через ярлык
│   │   └── guard.vbs             # Невидимая обертка запуска без окна терминала
│   ├── cli/                      # Утилиты диагностики и удаления
│   │   ├── check_claude_guard.ps1
│   │   └── uninstall_claude_guard.ps1
│   └── wrappers/                 # .bat-обертки с автозапросом UAC
│       ├── Install_Claude_Guard.bat
│       ├── Check_Claude_Guard.bat
│       └── Uninstall_Claude_Guard.bat
├── docs/                         # Пользовательская документация (попадает в релиз)
│   ├── USER_README.md
│   └── INSTALL_GUIDE.txt
├── dist/                         # Собранные релизные архивы (игнорируется Git)
├── build.ps1                     # Скрипт сборки релизного ZIP-архива для продакшена
├── RELEASE.md                    # Подробная инструкция по модификации и сборке релиза
└── .gitignore
```

## Быстрый старт для разработчика

1. Внесите изменения в модульные файлы в папке `src/`.
2. Соберите продакшен-архив командой:
   ```powershell
   .\build.ps1 -Version "1.0.1"
   ```
3. Готовый архив появится в `dist\ClaudeGuard_Installer-v1.0.1.zip`.

Подробные правила модификации, работы с кодировками и тестирования описаны в файле [RELEASE.md](RELEASE.md).

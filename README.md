# Автоматизация установки Zabbix Agent и регистрации хостов
PowerShell-скрипт для автоматической установки агента Zabbix и регистрации Windows-хостов через API Zabbix. Поддерживает развертывание через Group Policy Objects (GPO).

### ⚙️ Настройка
Замена обязательных параметров в `agent+host_create.ps1`:  
`$ZBX_SERVER` = "ваш_IP_сервера"  
`$ZBX_TOKEN` = "ваш_API_токен" (создать в Zabbix: Administration → API tokens)  
`$AGENT_MSI` = "\\ваш_сервер\путь\zabbix_agent-X.XX.X.msi"  
`$ZBX_TEMPLATE_NAME` = "Windows by Zabbix agent" # Проверить имя шаблона  
`$ZBX_HOSTGRP_NAME` = "Unassigned" # Указать существующую группу хостов или создать эту    

### 🛠 Технологии
- PowerShell 5.1+ (совместимость с Windows 7+)
- Zabbix API 5.4+ (JSON-RPC)
- Windows Installer (MSI) для развертывания агента
- Group Policy Objects для доменного развертывания
- Логирование: файловое (C:\Windows\Temp\zabbix_script.log) + Event Log

### 🚀 Запуск
#### Ручная установка (администратор):  
Временное разрешение скриптов  
- `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force`  

Запуск скрипта  
- `.\agent+host_create.ps1` (или по полному пути)  
#### Автоматизация через GPO:  
Разместите скрипты в сетевой папке: `\\ваш_сервер\путь\agent_install+host_create.ps1`  
Настройте политику: Computer Configuration → Policies → Windows Settings → Scripts (Startup/Shutdown) → Startup  
Параметры сценария:  
- Script: `%windir%\System32\WindowsPowerShell\v1.0\powershell.exe`  
- Parameters: `-Noninteractive -ExecutionPolicy Bypass -Noprofile -file "\\ваш_сервер\путь\agent_install+host_create.ps1"`  

### 📌 Ключевые функции
- Автоматическое определение FQDN хоста
- Проверка установленного агента через службы Windows
- Регистрация в Zabbix через API (POST-запросы)
- Обработка ошибок с записью в Event Log
- Совместимость с Zabbix Agent 5.x/6.x/7.x

### 🔒 Безопасность
API Token:
- Используйте токены с ограниченными правами (только host.create)
- Регулярно обновляйте токены (раз в 3-6 месяцев)
Доступ к скрипту:
- Храните в защищенной сетевой папке (только для Domain Computers)
Защита учетных данных:
- Никогда не коммитьте токен в Git и другие открытые ресурсы! Используйте секреты GPO или внешние хранилища
- Настройте права достпа до скрипта

### ⚠️ Типовые проблемы
- 403 Forbidden (API) - Проверьте срок действия токена и права доступа
- MSI не найден	Проверьте - доступность сетевой папки для COMPUTER$
- Host already exists - Ожидаемое поведение при повторном запуске
- ExecutionPolicy blocked - Добавьте -ExecutionPolicy Bypass в параметры GPO
- Port 10050 blocked - Откройте порт в брандмауэре целевых хостов
- Версия агента: 7.2.5 (обновите путь в $AGENT_MSI для новых версий)
- Тестировано на: Windows 10/11, Windows Server 2008-2012

Copyright © 2025 Кодельник Максим Сергеевич (ООО "Генштаб") | MIT License

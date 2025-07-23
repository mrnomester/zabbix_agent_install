### zabbix_agent_install
**Назначение**: Автоматическая установка Zabbix Agent и регистрация Windows-хостов в системе мониторинга Zabbix через API.  
**Функционал**:  
- Установка агента из MSI-пакета  
- Автоматическая регистрация хоста в Zabbix  
- Проверка существующей установки  
- Комплексное логирование и обработка ошибок  

### ⚙️ Настройка
Замена обязательных параметров в `agent+host_create.ps1`:  
```powershell
# Основные параметры Zabbix
$ZBX_SERVER = "ваш_IP_сервера"  # Пример: "192.168.1.100"
$ZBX_TOKEN = "ваш_API_токен"    # Создать в Zabbix: Administration → API → Tokens
$AGENT_MSI = "\\ваш_сервер\путь\zabbix_agent-X.X.X.msi" # Версия 7.2.5+ 

# Параметры шаблонов
$ZBX_TEMPLATE_NAME = "Windows by Zabbix agent" # Проверить точное имя
$ZBX_HOSTGRP_NAME = "Unassigned" # Или ваша группа хостов
```

### 🛠 Технологии
- **PowerShell 5.1+**: Основная логика скрипта  
- **Zabbix API**: JSON-RPC для управления хостами  
- **Windows Installer (MSI)**: Бесшовная установка агента  
- **Group Policy Objects**: Автоматизация доменного развертывания  
- **Многоуровневое логирование**:  
  - Файловое: `C:\Windows\Temp\zabbix_script.log`  
  - Event Log: Application → "Zabbix Script"  
- **Автоопределение FQDN**:  
  ```powershell
  $HOSTNAME = ([System.Net.Dns]::GetHostByName($env:computerName).HostName).tolower()
  ```

### 🚀 Запуск
#### Ручная установка (администратор):  
1. Временное разрешение скриптов:  
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
   ```
2. Запуск скрипта:  
   ```powershell
   \\сетевой_путь\agent+host_create.ps1
   ```

#### Автоматизация через GPO:  
1. **Разместите файлы в сетевой папке**:  
   - `agent+host_create.ps1`  

2. **Настройте политику (Computer Configuration)**:  
   - Policies → Windows Settings → Scripts → Startup  
   - Добавьте скрипт:  
     - **Script**: `%windir%\System32\WindowsPowerShell\v1.0\powershell.exe`  
     - **Parameters**: `-Noninteractive -ExecutionPolicy Bypass -Noprofile -file "\\сетевой_путь\agent+host_create.ps1"`

3. **Требования к клиентам**:  
   - Доступ к сетевому ресурсу с MSI-файлом  
   - Открытый порт 10050 (или ваш порт агента)  
   - PowerShell 5.1+  

### 📌 Ключевые функции
- **Интеллектуальная проверка установки**:  
  ```powershell
  $serviceNames = @("Zabbix Agent", "Zabbix Agent 2")
  if (Get-Service -Name $service -ErrorAction SilentlyContinue) { ... }
  ```
- **Безопасное взаимодействие с API**:  
  ```powershell
  $response = Invoke-RestMethod -Uri $ZBX_API -Method Post -Body $body -Headers @{ Authorization = "Bearer $ZBX_TOKEN" }
  ```
- **Динамическая регистрация хостов**:  
  - Автоматическое создание интерфейсов  
  - Привязка к группам и шаблонам  
- **Глубокая обработка ошибок**:  
  - Запись в Event Log с кодом 1  
  - Детализация в лог-файле  

### 🔒 Безопасность
- **API Token**:  
  - Минимальные права: `host.create` в Zabbix  
  - Регулярная ротация (раз в 3-6 месяцев)  
- **Доступ к ресурсам**:  
  - Сетевой путь к MSI: только чтение для `Domain Computers`  
  - Скрипт: хранить в защищенной SYSVOL  
- **Защита учетных данных**:  
  - Никогда не коммитить токен в Git!  
  - Использовать зашифрованные хранилища для GPO  

### ⚠️ Типовые проблемы
| Ошибка | Решение |
|--------|---------|
| `403 Forbidden` | Проверить срок действия токена |
| `Host already exists` | Ожидаемо при повторном запуске |
| `MSI not found` | Проверить доступность `\\сервер\...` для `COMPUTER$` |
| `Port 10050 blocked` | Открыть порт в брандмауэре |
| `Template not found` | Уточнить имя шаблона в Zabbix |
| `Access denied` | Запускать GPO от SYSTEM |

### 📊 Мониторинг
1. **Локальные логи**:  
   `C:\Windows\Temp\zabbix_script.log`  
   Формат: `[2024-07-18 14:30:00] Сообщение`  

2. **Журнал событий**:  
   - Источник: `Zabbix Script`  
   - Код события: `1` (ошибки)  

3. **Проверка в Zabbix**:  
   - Группа хостов: `$ZBX_HOSTGRP_NAME`  
   - Шаблон: `$ZBX_TEMPLATE_NAME`  

> **Для отладки GPO**:  
> `gpresult /h report.html`  
> Проверить применение политики в разделе:  
> `Computer Configuration → Policies → Windows Settings → Scripts → Startup`  

### 💡 Оптимизация
- **Пакетное развертывание**: можно использовать Zabbix Discovery для массовой автоматической регистрации, зачастую удобнее (мне не подошло)  

Copyright © 2025 Кодельник Максим Сергеевич (ООО "Генштаб") | MIT License

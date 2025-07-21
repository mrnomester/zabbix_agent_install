# Временное включение выполнения скриптов
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Параметры Zabbix
$ZBX_SERVER = ""
$ZBX_API = "http://$ZBX_SERVER/zabbix/api_jsonrpc.php"
$ZBX_TOKEN = ""
$ZBX_TEMPLATE_NAME = "Windows by Zabbix agent"
$ZBX_HOSTGRP_NAME = "Unassigned"

# Параметры агента
$AGENT_MSI = "\\nas\Distrib\Zabbix\zabbix_agent-7.2.5.msi"
$HOSTNAME = ([System.Net.Dns]::GetHostByName($env:computerName).HostName).tolower()
$AGENT_PORT = "10050"

# Логирование
$LOG_FILE = "C:\Windows\Temp\zabbix_script.log"

function Log-Message {
    param ([string]$message)
    try {
        Add-Content -Path $LOG_FILE -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $message"
    } catch {
        Write-Host "Ошибка записи в лог: $_"
    }
}

function Handle-Error {
    param ([string]$errorMessage)
    Log-Message "ОШИБКА: $errorMessage"
    Write-Host "ОШИБКА: $errorMessage" -ForegroundColor Red
    
    # Запись в журнал событий
    if (-Not [System.Diagnostics.EventLog]::SourceExists("Zabbix Script")) {
        New-EventLog -LogName Application -Source "Zabbix Script" -ErrorAction SilentlyContinue
    }
    Write-EventLog -LogName Application -Source "Zabbix Script" -EntryType Error -EventId 1 -Message $errorMessage
    
    exit 1
}

function Get-ZbxId {
    param (
        [string]$method,
        [string]$name,
        [string]$filterField = "name"
    )
    
    $body = @{
        jsonrpc = "2.0"
        method = $method
        params = @{
            output = "extend"
            filter = @{ $filterField = @($name) }
        }
        id = 1
    } | ConvertTo-Json -Depth 5

    try {
        $response = Invoke-RestMethod -Uri $ZBX_API -Method Post -Body $body -ContentType "application/json-rpc" -Headers @{ Authorization = "Bearer $ZBX_TOKEN" }
        
        if ($response.error) {
            Handle-Error ("API вернул ошибку: {0}" -f $response.error.data)
        }
        if ($response.result.Count -eq 0) {
            return $null
        }
        
        switch -regex ($method) {
            "hostgroup.get" { return $response.result[0].groupid }
            "template.get"  { return $response.result[0].templateid }
            "host.get"      { return $response.result[0].hostid }
            default         { Handle-Error "Неподдерживаемый метод: $method" }
        }
    } catch {
        Handle-Error ("Ошибка API запроса: {0}" -f $_.Exception.Message)
    }
}

function Host-Exists {
    # Проверка существования хоста по имени
    $hostId = Get-ZbxId -method "host.get" -name $HOSTNAME -filterField "host"
    return [bool]$hostId
}

function Register-Host {
    $groupID = Get-ZbxId -method "hostgroup.get" -name $ZBX_HOSTGRP_NAME
    $templateID = Get-ZbxId -method "template.get" -name $ZBX_TEMPLATE_NAME

    $body = @{
        jsonrpc = "2.0"
        method = "host.create"
        params = @{
            host = $HOSTNAME
            name = $HOSTNAME
            interfaces = @(
                @{
                    type = 1
                    main = 1
                    useip = 0
                    dns = $HOSTNAME
                    ip = "127.0.0.1"
                    port = $AGENT_PORT
                }
            )
            groups = @( @{ groupid = $groupID } )
            templates = @( @{ templateid = $templateID } )
            inventory_mode = 1
            status = 0
        }
        id = 1
    } | ConvertTo-Json -Depth 5

    try {
        $response = Invoke-RestMethod -Uri $ZBX_API -Method Post -Body $body -ContentType "application/json-rpc" -Headers @{ Authorization = "Bearer $ZBX_TOKEN" }
        
        if ($response.error) {
            Handle-Error ("Ошибка регистрации: {0}" -f $response.error.data)
        }
        
        Log-Message ("Хост {0} зарегистрирован с ID: {1}" -f $HOSTNAME, $response.result.hostids[0])
        Write-Host "Регистрация успешна!" -ForegroundColor Green
    } catch {
        Handle-Error ("Критическая ошибка: {0}" -f $_.Exception.Message)
    }
}

function Install-ZabbixAgent {
    try {
        $installArgs = "/i `"$AGENT_MSI`" /qn /norestart " +
                       "SERVER=$ZBX_SERVER " +
                       "LISTENPORT=$AGENT_PORT " +
                       "HOSTNAME=$HOSTNAME " +
                       "ENABLEPATH=1 " +
                       "INSTALLFOLDER=`"C:\Program Files\Zabbix Agent`""
        
        Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -NoNewWindow
        
        if ($LASTEXITCODE -ne 0) {
            throw "Код ошибки установки: $LASTEXITCODE"
        }
        
        Log-Message "Агент Zabbix установлен успешно"
        Write-Host "Установка агента завершена" -ForegroundColor Green
        return $true
    } catch {
        Handle-Error ("Ошибка установки агента: {0}" -f $_.Exception.Message)
        return $false
    }
}

# Основной процесс
Log-Message "Запуск скрипта установки и регистрации"
Write-Host "Начало работы скрипта" -ForegroundColor Cyan

# Проверка существующей установки через службы
$agentInstalled = $false
$serviceNames = @("Zabbix Agent", "Zabbix Agent 2")

foreach ($service in $serviceNames) {
    if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
        $agentInstalled = $true
        Write-Host "Агент $service уже установлен" -ForegroundColor Yellow
        Log-Message "Обнаружена установленная служба: $service"
        break
    }
}

# Установка агента при необходимости
if (-not $agentInstalled) {
    Write-Host "Агент не найден. Начинаем установку..." -ForegroundColor Yellow
    $installationResult = Install-ZabbixAgent
    if (-not $installationResult) {
        Handle-Error "Не удалось установить агент Zabbix"
    }
}

# Проверка существования хоста в Zabbix
Write-Host "Проверка регистрации хоста в Zabbix..." -ForegroundColor Yellow
if (-not (Host-Exists)) {
    Write-Host "Регистрация хоста в Zabbix..." -ForegroundColor Yellow
    Register-Host
} else {
    Write-Host "Хост уже зарегистрирован в Zabbix" -ForegroundColor Green
    Log-Message "Хост $HOSTNAME уже существует в Zabbix, регистрация пропущена"
}

Write-Host "Скрипт завершен успешно" -ForegroundColor Green
#!/usr/bin/env bash

# Скрипт для сбора диагностической информации о сервере и проверки HTTP-сервисов

set -o pipefail  # сохраняем код возврата первой команды в пайпе

# --- Глобальные переменные ---
LOG_FILE="server-info.log"          # файл для логов (в текущей директории)
SERVICES_OK=0
SERVICES_FAIL=0
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# --- Функция справки ---
usage() {
    cat <<EOF
Использование: $0 [--help] [URL1] [URL2] ...

Скрипт собирает информацию о системе и проверяет доступность указанных HTTP-сервисов.

  --help          Показать эту справку
  URL ...         Один или несколько адресов для проверки здоровья (например, http://localhost:5000/health)

Если URL не переданы, выполняется только сбор системной информации.

Пример:
  $0 http://localhost:5000/health http://localhost:8080/health
  $0 --help
EOF
}

# --- Функция логирования ---
log() {
    local msg="[$(date "+%Y-%m-%d %H:%M:%S")] $*"
    echo "$msg" | tee -a "$LOG_FILE"
}

# --- Проверка зависимостей ---
check_dependencies() {
    local deps_ok=true
    if ! command -v curl &> /dev/null; then
        log "ОШИБКА: curl не установлен. Установите curl для работы скрипта."
        deps_ok=false
    fi
    # Docker не обязателен, только предупреждение
    if ! command -v docker &> /dev/null; then
        log "ПРЕДУПРЕЖДЕНИЕ: docker не найден. Информация о контейнерах будет пропущена."
    fi
    if ! $deps_ok; then
        exit 1
    fi
}

# --- Информация о системе ---
system_info() {
    log "=== Server Diagnostics ==="
    log "Date:     $TIMESTAMP"
    log "Hostname: $(hostname 2>/dev/null || echo "unknown")"
    # Определяем ОС
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        log "OS:       ${PRETTY_NAME:-$NAME $VERSION_ID}"
    else
        log "OS:       $(uname -s) $(uname -r)"
    fi
    log "Kernel:   $(uname -r)"
    # uptime
    local uptime_str
    if [[ -f /proc/uptime ]]; then
        local uptime_seconds
        uptime_seconds=$(awk '{print $1}' /proc/uptime | cut -d. -f1)
        local days=$((uptime_seconds / 86400))
        local hours=$(( (uptime_seconds % 86400) / 3600 ))
        local minutes=$(( (uptime_seconds % 3600) / 60 ))
        if (( days > 0 )); then
            uptime_str="${days} days, ${hours}:${minutes}"
        else
            uptime_str="${hours}:${minutes}"
        fi
    else
        uptime_str="$(uptime -p 2>/dev/null | sed 's/up //' || echo "unknown")"
    fi
    log "Uptime:   $uptime_str"
}

# --- Ресурсы (CPU, RAM, диск) ---
resources() {
    log "=== Resources ==="
    # CPU (количество ядер и load average)
    local cores=$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo "?")
    local loadavg
    if [[ -f /proc/loadavg ]]; then
        loadavg=$(awk '{print $1", "$2", "$3}' /proc/loadavg)
    else
        loadavg="недоступно"
    fi
    log "CPU:      $cores cores, load average: $loadavg"

    # RAM
    if command -v free &> /dev/null; then
        local mem_info=$(free -h | awk '/Mem:/ {print $3" / "$2" ("$4" free)"}')
        local mem_percent=$(free | awk '/Mem:/ {printf "%.0f%%", ($3/$2)*100}')
        log "RAM:      $mem_info ($mem_percent)"
    else
        log "RAM:      не удалось получить (free не найден)"
    fi

    # Диск (корневой раздел)
    if command -v df &> /dev/null; then
        local disk_info=$(df -h / | awk 'NR==2 {print $3" / "$2" ("$5" used)"}')
        log "Disk /:   $disk_info"
    else
        log "Disk /:   не удалось получить (df не найден)"
    fi
}

# --- Docker контейнеры (если установлен) ---
docker_info() {
    if command -v docker &> /dev/null; then
        log "=== Docker ==="
        local containers
        containers=$(docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Status}}" 2>/dev/null)
        if [[ -n "$containers" ]]; then
            log "$containers"
        else
            log "Нет запущенных контейнеров или нет доступа к Docker."
        fi
    else
        log "Docker не установлен, пропускаем."
    fi
}

# --- Проверка одного HTTP-сервиса ---
check_service() {
    local url="$1"
    local curl_output
    local http_code
    local time_total
    local result_msg

    # Выполняем запрос с таймаутом 5 секунд, измеряем время и код ответа
    curl_output=$(curl -o /dev/null -s -w "%{http_code} %{time_total}" --connect-timeout 5 "$url" 2>&1)
    local curl_exit=$?

    if [[ $curl_exit -ne 0 ]]; then
        # Ошибка подключения (connection refused, таймаут и т.п.)
        result_msg="[FAIL] $url (ошибка соединения: $curl_output)"
        ((SERVICES_FAIL++))
    else
        http_code=$(echo "$curl_output" | awk '{print $1}')
        time_total=$(echo "$curl_output" | awk '{print $2}')
        # Округляем время до мс
        time_ms=$(printf "%.0f" "$(echo "$time_total * 1000" | bc 2>/dev/null || echo "0")")
        if [[ "$http_code" -eq 200 ]]; then
            result_msg="[OK]   $url ($http_code, ${time_ms}ms)"
            ((SERVICES_OK++))
        else
            result_msg="[FAIL] $url ($http_code, ${time_ms}ms)"
            ((SERVICES_FAIL++))
        fi
    fi
    log "$result_msg"
}

# --- Основная функция ---
main() {
    # Обработка аргументов
    if [[ $# -eq 1 && "$1" == "--help" ]]; then
        usage
        exit 0
    fi

    # Проверка зависимостей (включая curl)
    check_dependencies

    # Информация о системе
    system_info
    resources
    docker_info

    # Если есть аргументы (URL) – проверяем сервисы
    if [[ $# -gt 0 ]]; then
        log "=== Service Health Checks ==="
        for url in "$@"; do
            check_service "$url"
        done
        log "Result: $SERVICES_OK/$((SERVICES_OK + SERVICES_FAIL)) services healthy"
    else
        log "=== Без проверки сервисов (URL не указаны) ==="
    fi

    # Возвращаем код 1, если есть неудачные проверки
    if [[ $SERVICES_FAIL -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Запуск основной функции
main "$@"
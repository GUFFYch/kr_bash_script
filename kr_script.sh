#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для проверки прав доступа
check_dangerous_permissions() {
    local permissions="$1"
    
    # Файлы с правами записи для всех (world-writable)
    if [[ $permissions =~ ^..[2-7] ]]; then
        echo "world-writable"
        return 0
    fi
    
    # Файлы с SUID битом
    if [[ $permissions =~ ^[4-7] ]]; then
        echo "suid"
        return 0
    fi
    
    # Файлы с SGID битом
    if [[ $permissions =~ ^.[2-7] ]]; then
        echo "sgid"
        return 0
    fi
    
    echo "safe"
    return 1
}

# Функция для записи в журнал
log_to_journal() {
    local message="$1"
    local username=$(whoami)
    logger -t "dangerous_files_scan" "[$username] $message"
}

# Функция сканирования
scan_directory() {
    echo -n "Введите директорию для сканирования: "
    read target_dir
    
    if [ ! -d "$target_dir" ]; then
        echo "Ошибка: Директория '$target_dir' не существует."
        return
    fi
    
    echo -e "${BLUE}Поиск опасных файлов в директории: $target_dir${NC}"
    echo "=================================================="
    
    log_to_journal "Начало сканирования директории: $target_dir"
    
    found_files=0
    
    # Используем массив для сохранения результатов
    while IFS= read -r file; do
        perms=$(stat -c "%a" "$file" 2>/dev/null)
        
        if [ -n "$perms" ]; then
            result=$(check_dangerous_permissions "$perms")
            
            if [ "$result" != "safe" ]; then
                found_files=$((found_files + 1))
                
                case $result in
                    "world-writable")
                        echo -e "${RED}⚠  WORLD-WRITABLE:${NC} $file (права: $perms)"
                        log_to_journal "WORLD-WRITABLE: $file (права: $perms)"
                        ;;
                    "suid")
                        echo -e "${RED}  SUID:${NC} $file (права: $perms)"
                        log_to_journal "SUID: $file (права: $perms)"
                        ;;
                    "sgid")
                        echo -e "${RED}  SGID:${NC} $file (права: $perms)"
                        log_to_journal "SGID: $file (права: $perms)"
                        ;;
                esac
            fi
        fi
    done < <(find "$target_dir" -type f 2>/dev/null)
    
    echo "=================================================="
    if [ $found_files -eq 0 ]; then
        echo "Опасных файлов не найдено."
        log_to_journal "Сканирование завершено. Опасных файлов не найдено."
    else
        echo "Найдено опасных файлов: $found_files"
        log_to_journal "Сканирование завершено. Найдено опасных файлов: $found_files"
    fi
}

# Функция просмотра журнала - только последние 2 минуты
show_journal() {
    echo "Записи из журнала за последние 2 минуты:"
    echo "========================================"
    journalctl -t dangerous_files_scan --since "2 minutes ago" 2>/dev/null || echo "Не удалось прочитать журнал."
}

# Основное меню
while true; do
    echo ""
    echo "Меню:"
    echo "1. Сканировать директорию"
    echo "2. Показать журнал (последние 2 минуты)"
    echo "3. Выход"
    echo -n "Выберите действие (1-3): "
    read choice
    
    case $choice in
        1)
            scan_directory
            ;;
        2)
            show_journal
            ;;
        3)
            echo "Выход из программы."
            exit 0
            ;;
        *)
            echo "Неверный выбор. Попробуйте снова."
            ;;
    esac
done

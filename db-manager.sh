#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.config"
DOCKER_NETWORK="database-migration-network"

source "$SCRIPT_DIR/lib/log.lib.sh"

LOCAL_DIALOG="$SCRIPT_DIR/dependencies/dialog/dialog"
if [ -x "$LOCAL_DIALOG" ] && "$LOCAL_DIALOG" --version &>/dev/null; then
    DIALOG="$LOCAL_DIALOG"
    USE_LOCAL_DIALOG=true
elif command -v dialog &>/dev/null; then
    DIALOG="dialog"
    USE_LOCAL_DIALOG=false
else
    DIALOG=""
    USE_LOCAL_DIALOG=false
fi

trap cleanup_terminal EXIT

check_dialog() {
    if [ -z "$DIALOG" ]; then
        clear
        log_error "Dialog not available!"
        echo ""
        log_info "The bundled dialog binary is not compatible with your system."
        log_info "Please install dialog for your system:"
        echo ""
        echo "  Ubuntu/Debian:    sudo apt-get install dialog"
        echo "  RedHat/CentOS:    sudo yum install dialog"
        echo "  Fedora:           sudo dnf install dialog"
        echo "  Arch Linux:       sudo pacman -S dialog"
        echo "  macOS (Homebrew): brew install dialog"
        echo ""
        exit 1
    fi
    
    if [ "$USE_LOCAL_DIALOG" = true ]; then
        log_success "Using bundled dialog binary (Linux x86_64)"
    else
        log_info "Using system dialog"
    fi
}

generate_dump_filename() {
generate_dump_filename() {
    local db_type="$1"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    echo "${db_type}-${timestamp}.txt"
}

save_config() {
    cat >"$CONFIG_FILE" <<EOF
DB_TYPE=$DB_TYPE
SRC_HOST=$SRC_HOST
SRC_PORT=$SRC_PORT
SRC_USER=$SRC_USER
SRC_PASS=$SRC_PASS
SRC_DB=$SRC_DB
DST_HOST=$DST_HOST
DST_PORT=$DST_PORT
DST_USER=$DST_USER
DST_PASS=$DST_PASS
DST_DB=$DST_DB
DUMP_DIR=$DUMP_DIR
EOF
    log_success "Configuration saved to $CONFIG_FILE"
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        return 0
    fi
    return 1
}

main_menu() {
    while true; do
        CHOICE=$($DIALOG --clear --backtitle "DB Migration Manager with Docker" \
            --title "Main Menu" \
            --menu "Choose an operation:" 15 60 6 \
            1 "🗄️  Configure Database" \
            2 "💾 Dump (Export)" \
            3 "📥 Load (Import)" \
            4 "🔄 Migrate (Dump + Load)" \
            5 "⚙️  View Configuration" \
            6 "🚪 Exit" \
            3>&1 1>&2 2>&3)

        case $CHOICE in
        1) configure_database ;;
        2) perform_dump ;;
        3) perform_load ;;
        4) perform_migrate ;;
        5) view_config ;;
        6)
            clear
            exit 0
            ;;
        *)
            ;;
        esac
    done
}

configure_database() {
    while true; do
        load_config || true
        
        CONFIG_MENU=$($DIALOG --clear --backtitle "DB Migration Manager" \
            --title "Configuration" \
            --menu "What do you want to configure?" 16 65 7 \
            1 "🗄️  Database Type (Current: ${DB_TYPE:-Not configured})" \
            2 "📤 SOURCE Configuration" \
            3 "📥 DESTINATION Configuration" \
            4 "💾 Dump Directory (Auto-named files)" \
            5 "✅ Complete Setup (Step by Step)" \
            6 "👁️  View Current Configuration" \
            7 "🔙 Back to Main Menu" \
            3>&1 1>&2 2>&3)
        
        case $CONFIG_MENU in
        1) configure_db_type ;;
        2) configure_source ;;
        3) configure_destination ;;
        4) configure_dump_file ;;
        5) configure_full ;;
        6) view_config ;;
        7) return ;;
        *) 
            return
            ;;
        esac
    done
}

configure_db_type() {
    DB_TYPE=$($DIALOG --clear --backtitle "DB Migration Manager" \
        --title "Database Type" \
        --menu "Select the type:" 12 50 3 \
        1 "MySQL/MariaDB" \
        2 "PostgreSQL" \
        3 "SQL Server" \
        3>&1 1>&2 2>&3)

    case $DB_TYPE in
    1) DB_TYPE="mysql" ;;
    2) DB_TYPE="postgres" ;;
    3) DB_TYPE="sqlserver" ;;
    *)
        return
        ;;
    esac
    
    save_config
    $DIALOG --clear --backtitle "DB Migration Manager" \
        --title "Success" \
        --msgbox "Database type configured: $DB_TYPE" 6 40
}

configure_source() {
    exec 3>&1
    VALUES=$($DIALOG --clear --backtitle "DB Migration Manager" \
        --title "Configuration - SOURCE" \
        --form "Fill in the SOURCE database data:" 15 60 5 \
        "Host:" 1 1 "${SRC_HOST:-localhost}" 1 15 40 0 \
        "Port:" 2 1 "${SRC_PORT:-3306}" 2 15 40 0 \
        "User:" 3 1 "${SRC_USER:-root}" 3 15 40 0 \
        "Password:" 4 1 "${SRC_PASS:-}" 4 15 40 0 \
        "Database:" 5 1 "${SRC_DB:-}" 5 15 40 0 \
        2>&1 1>&3)
    exec 3>&-

    if [ $? -ne 0 ]; then
        return
    fi

    IFS=$'\n' read -rd '' -a arr <<<"$VALUES"
    SRC_HOST="${arr[0]}"
    SRC_PORT="${arr[1]}"
    SRC_USER="${arr[2]}"
    SRC_PASS="${arr[3]}"
    SRC_DB="${arr[4]}"
    
    save_config
    $DIALOG --clear --backtitle "DB Migration Manager" \
        --title "Success" \
        --msgbox "SOURCE configuration saved!\n\nHost: $SRC_HOST:$SRC_PORT\nDB: $SRC_DB" 9 50
}

configure_destination() {
    exec 3>&1
    VALUES=$($DIALOG --clear --backtitle "DB Migration Manager" \
        --title "Configuration - DESTINATION" \
        --form "Fill in the DESTINATION database data:" 15 60 5 \
        "Host:" 1 1 "${DST_HOST:-localhost}" 1 15 40 0 \
        "Port:" 2 1 "${DST_PORT:-3306}" 2 15 40 0 \
        "User:" 3 1 "${DST_USER:-root}" 3 15 40 0 \
        "Password:" 4 1 "${DST_PASS:-}" 4 15 40 0 \
        "Database:" 5 1 "${DST_DB:-}" 5 15 40 0 \
        2>&1 1>&3)
    exec 3>&-

    if [ $? -ne 0 ]; then
        return
    fi

    IFS=$'\n' read -rd '' -a arr <<<"$VALUES"
    DST_HOST="${arr[0]}"
    DST_PORT="${arr[1]}"
    DST_USER="${arr[2]}"
    DST_PASS="${arr[3]}"
    DST_DB="${arr[4]}"
    
    save_config
    $DIALOG --clear --backtitle "DB Migration Manager" \
        --title "Success" \
        --msgbox "DESTINATION configuration saved!\n\nHost: $DST_HOST:$DST_PORT\nDB: $DST_DB" 9 50
}

configure_dump_file() {
    DUMP_DIR=$($DIALOG --clear --backtitle "DB Migration Manager" \
        --title "Dump Directory" \
        --inputbox "Directory where dump files will be saved:\n\nFilename will be auto-generated as:\n<db-engine>-<timestamp>.txt" 12 70 "${DUMP_DIR:-$HOME/Downloads}" \
        3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        return
    fi
    
    mkdir -p "$DUMP_DIR" 2>/dev/null
    
    save_config
    $DIALOG --clear --backtitle "DB Migration Manager" \
        --title "Success" \
        --msgbox "Dump directory configured:\n\n$DUMP_DIR\n\nFiles will be named: <db-engine>-<timestamp>.dump" 10 70
}

configure_full() {
    DB_TYPE=$($DIALOG --clear --backtitle "DB Migration Manager" \
        --title "[1/4] Database Type" \
        --menu "Select the type:" 12 50 3 \
        1 "MySQL/MariaDB" \
        2 "PostgreSQL" \
        3 "SQL Server" \
        3>&1 1>&2 2>&3)

    case $DB_TYPE in
    1) DB_TYPE="mysql" ;;
    2) DB_TYPE="postgres" ;;
    3) DB_TYPE="sqlserver" ;;
    *)
        return
        ;;
    esac

    exec 3>&1
    VALUES=$($DIALOG --clear --backtitle "DB Migration Manager" \
        --title "[2/4] Configuration - SOURCE" \
        --form "Fill in the SOURCE database data:" 15 60 5 \
        "Host:" 1 1 "${SRC_HOST:-localhost}" 1 15 40 0 \
        "Port:" 2 1 "${SRC_PORT:-3306}" 2 15 40 0 \
        "User:" 3 1 "${SRC_USER:-root}" 3 15 40 0 \
        "Password:" 4 1 "${SRC_PASS:-}" 4 15 40 0 \
        "Database:" 5 1 "${SRC_DB:-}" 5 15 40 0 \
        2>&1 1>&3)
    exec 3>&-

    if [ $? -ne 0 ]; then
        return
    fi

    IFS=$'\n' read -rd '' -a arr <<<"$VALUES"
    SRC_HOST="${arr[0]}"
    SRC_PORT="${arr[1]}"
    SRC_USER="${arr[2]}"
    SRC_PASS="${arr[3]}"
    SRC_DB="${arr[4]}"

    exec 3>&1
    VALUES=$($DIALOG --clear --backtitle "DB Migration Manager" \
        --title "[3/4] Configuration - DESTINATION" \
        --form "Fill in the DESTINATION database data:" 15 60 5 \
        "Host:" 1 1 "${DST_HOST:-localhost}" 1 15 40 0 \
        "Port:" 2 1 "${DST_PORT:-3306}" 2 15 40 0 \
        "User:" 3 1 "${DST_USER:-root}" 3 15 40 0 \
        "Password:" 4 1 "${DST_PASS:-}" 4 15 40 0 \
        "Database:" 5 1 "${DST_DB:-}" 5 15 40 0 \
        2>&1 1>&3)
    exec 3>&-

    if [ $? -ne 0 ]; then
        return
    fi

    IFS=$'\n' read -rd '' -a arr <<<"$VALUES"
    DST_HOST="${arr[0]}"
    DST_PORT="${arr[1]}"
    DST_USER="${arr[2]}"
    DST_PASS="${arr[3]}"
    DST_DB="${arr[4]}"

    DUMP_DIR=$($DIALOG --clear --backtitle "DB Migration Manager" \
        --title "[4/4] Dump Directory" \
        --inputbox "Directory for dump files:\n\nFiles will be auto-named:\n<db-engine>-<timestamp>.txt" 12 70 "${DUMP_DIR:-$HOME/Downloads}" \
        3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        return
    fi
    
    mkdir -p "$DUMP_DIR" 2>/dev/null

    save_config

    $DIALOG --clear --backtitle "DB Migration Manager" \
        --title "✅ Complete Setup" \
        --msgbox "All settings saved!\n\nType: $DB_TYPE\n\nSource: $SRC_HOST:$SRC_PORT/$SRC_DB\nDestination: $DST_HOST:$DST_PORT/$DST_DB\n\nDump Dir: $DUMP_DIR\nFiles: <db-engine>-<timestamp>.dump" 16 70
}

view_config() {
    if ! load_config; then
        $DIALOG --clear --backtitle "DB Migration Manager" \
            --title "Error" \
            --msgbox "No configuration found. Please configure first." 6 50
        return
    fi
    
    local dump_dir_display="${DUMP_DIR:-[Not configured]}"

    $DIALOG --clear --backtitle "DB Migration Manager" \
        --title "Current Configuration" \
        --msgbox "Type: $DB_TYPE\n\nSource:\n  Host: $SRC_HOST:$SRC_PORT\n  User: $SRC_USER\n  DB: $SRC_DB\n\nDestination:\n  Host: $DST_HOST:$DST_PORT\n  User: $DST_USER\n  DB: $DST_DB\n\nDump Directory: $dump_dir_display\nFile naming: <db-engine>-<timestamp>.txt" 20 60
}

perform_dump() {
    if ! load_config; then
        $DIALOG --clear --backtitle "DB Migration Manager" \
            --title "Error" \
            --msgbox "Please configure the database first." 6 50
        return
    fi
    
    if [ -z "$DUMP_DIR" ]; then
        $DIALOG --clear --backtitle "DB Migration Manager" \
            --title "Error" \
            --msgbox "Dump directory not configured. Please configure it first." 6 60
        return
    fi
    
    ensure_dir "$DUMP_DIR"

    clear
    log_header "DUMP - Exporting Database"
    log_info "🔄 Starting dump of $SRC_DB..."
    ensure_docker_network "$DOCKER_NETWORK"
    
    DUMP_FILENAME=$(generate_dump_filename "$DB_TYPE")
    DUMP_FILE="$DUMP_DIR/$DUMP_FILENAME"
    log_info "📄 File: $DUMP_FILENAME"

    case $DB_TYPE in
    mysql)
        "$SCRIPT_DIR/operation/mysql-dump.operation.sh" "$SRC_HOST" "$SRC_PORT" "$SRC_USER" "$SRC_PASS" "$SRC_DB" "$DUMP_FILE"
        ;;
    postgres)
        "$SCRIPT_DIR/operation/postgres-dump.operation.sh" "$SRC_HOST" "$SRC_PORT" "$SRC_USER" "$SRC_PASS" "$SRC_DB" "$DUMP_FILE"
        ;;
    sqlserver)
        "$SCRIPT_DIR/operation/sqlserver-dump.operation.sh" "$SRC_HOST" "$SRC_PORT" "$SRC_USER" "$SRC_PASS" "$SRC_DB" "$DUMP_FILE"
        ;;
    esac

    echo ""
    read -p "Press ENTER to continue..."
}

perform_load() {
    if ! load_config; then
        $DIALOG --clear --backtitle "DB Migration Manager" \
            --title "Error" \
            --msgbox "Please configure the database first." 6 50
        return
    fi
    
    if [ -z "$DUMP_DIR" ]; then
        $DIALOG --clear --backtitle "DB Migration Manager" \
            --title "Error" \
            --msgbox "Dump directory not configured. Please configure it first." 6 60
        return
    fi
    
    SELECTED_DUMP=$($DIALOG --clear --backtitle "DB Migration Manager" \
        --title "Select Dump File" \
        --inputbox "Enter the full path to the dump file:" 8 70 "${DUMP_DIR}/$(ls -t "$DUMP_DIR"/*.txt 2>/dev/null | head -1 | xargs basename 2>/dev/null)" \
        3>&1 1>&2 2>&3)
    
    if [ $? -ne 0 ]; then
        return
    fi
    
    if [ ! -f "$SELECTED_DUMP" ]; then
        $DIALOG --clear --backtitle "DB Migration Manager" \
            --title "Error" \
            --msgbox "File not found: $SELECTED_DUMP" 6 50
        return
    fi

    clear
    log_header "LOAD - Importing Database"
    log_info "📥 Starting load to $DST_DB..."
    log_info "📄 File: $(basename "$SELECTED_DUMP")"
    ensure_docker_network "$DOCKER_NETWORK"

    case $DB_TYPE in
    mysql)
        "$SCRIPT_DIR/operation/mysql-load.operation.sh" "$DST_HOST" "$DST_PORT" "$DST_USER" "$DST_PASS" "$DST_DB" "$SELECTED_DUMP"
        ;;
    postgres)
        "$SCRIPT_DIR/operation/postgres-load.operation.sh" "$DST_HOST" "$DST_PORT" "$DST_USER" "$DST_PASS" "$DST_DB" "$SELECTED_DUMP"
        ;;
    sqlserver)
        "$SCRIPT_DIR/operation/sqlserver-load.operation.sh" "$DST_HOST" "$DST_PORT" "$DST_USER" "$DST_PASS" "$DST_DB" "$SELECTED_DUMP"
        ;;
    esac

    echo ""
    read -p "Press ENTER to continue..."
}

perform_migrate() {
    if ! load_config; then
        $DIALOG --clear --backtitle "DB Migration Manager" \
            --title "Error" \
            --msgbox "Please configure the database first." 6 50
        return
    fi
    
    if [ -z "$DUMP_DIR" ]; then
        $DIALOG --clear --backtitle "DB Migration Manager" \
            --title "Error" \
            --msgbox "Dump directory not configured. Please configure it first." 6 60
        return
    fi
    
    ensure_dir "$DUMP_DIR"

    $DIALOG --clear --backtitle "DB Migration Manager" \
        --title "Confirmation" \
        --yesno "Migrate $SRC_DB to $DST_DB?\n\nThis will:\n1. Dump from source\n2. Load to destination" 10 50

    if [ $? -ne 0 ]; then
        return
    fi

    clear
    log_header "MIGRATE - Complete Migration"
    log_info "🔄 Starting migration from $SRC_DB to $DST_DB..."
    ensure_docker_network "$DOCKER_NETWORK"
    
    DUMP_FILENAME=$(generate_dump_filename "$DB_TYPE")
    DUMP_FILE="$DUMP_DIR/$DUMP_FILENAME"
    log_info "📄 File: $DUMP_FILENAME"

    echo ""
    log_step "Step 1/2: Dump..."
    case $DB_TYPE in
    mysql)
        "$SCRIPT_DIR/operation/mysql-dump.operation.sh" "$SRC_HOST" "$SRC_PORT" "$SRC_USER" "$SRC_PASS" "$SRC_DB" "$DUMP_FILE"
        ;;
    postgres)
        "$SCRIPT_DIR/operation/postgres-dump.operation.sh" "$SRC_HOST" "$SRC_PORT" "$SRC_USER" "$SRC_PASS" "$SRC_DB" "$DUMP_FILE"
        ;;
    sqlserver)
        "$SCRIPT_DIR/operation/sqlserver-dump.operation.sh" "$SRC_HOST" "$SRC_PORT" "$SRC_USER" "$SRC_PASS" "$SRC_DB" "$DUMP_FILE"
        ;;
    esac

    echo ""
    log_step "Step 2/2: Load..."
    case $DB_TYPE in
    mysql)
        "$SCRIPT_DIR/operation/mysql-load.operation.sh" "$DST_HOST" "$DST_PORT" "$DST_USER" "$DST_PASS" "$DST_DB" "$DUMP_FILE"
        ;;
    postgres)
        "$SCRIPT_DIR/operation/postgres-load.operation.sh" "$DST_HOST" "$DST_PORT" "$DST_USER" "$DST_PASS" "$DST_DB" "$DUMP_FILE"
        ;;
    sqlserver)
        "$SCRIPT_DIR/operation/sqlserver-load.operation.sh" "$DST_HOST" "$DST_PORT" "$DST_USER" "$DST_PASS" "$DST_DB" "$DUMP_FILE"
        ;;
    esac

    echo ""
    log_success "Migration completed!"
    read -p "Press ENTER to continue..."
}

check_dialog
check_docker
load_config || true
main_menu

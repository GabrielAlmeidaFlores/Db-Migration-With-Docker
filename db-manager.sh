#!/bin/bash

# DB Manager - Interface to manage database dumps, loads and migrations
# Uses Docker to run commands without needing to install tools locally

# Note: We DON'T use 'set -e' because dialog returns error codes on cancel/ESC
# and we want to handle those gracefully without exiting

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.config"
DOCKER_NETWORK="database-migration-network"

# Load utility functions
source "$SCRIPT_DIR/lib/log.lib.sh"

# Use local dialog binary if available and compatible, otherwise use system dialog
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

# Set trap to clean up on exit
trap cleanup_terminal EXIT

# Function to check if dialog is available
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

# Note: check_docker() is now provided by lib/utils.sh

# Function to save configuration
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
DUMP_FILE=$DUMP_FILE
EOF
    log_success "Configuration saved to $CONFIG_FILE"
}

# Function to load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        return 0
    fi
    return 1
}

# Main menu
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
            # Cancel ou ESC - continua no loop
            ;;
        esac
    done
}

# Configure database
configure_database() {
    while true; do
        load_config || true
        
        CONFIG_MENU=$($DIALOG --clear --backtitle "DB Migration Manager" \
            --title "Configuration" \
            --menu "What do you want to configure?" 16 65 7 \
            1 "🗄️  Database Type (Current: ${DB_TYPE:-Not configured})" \
            2 "📤 SOURCE Configuration" \
            3 "📥 DESTINATION Configuration" \
            4 "💾 Dump File (Location)" \
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
            # Cancel or ESC - back to main menu
            return
            ;;
        esac
    done
}

# Configure database type only
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
        # Cancel or ESC - return without saving
        return
        ;;
    esac
    
    save_config
    $DIALOG --clear --backtitle "DB Migration Manager" \
        --title "Success" \
        --msgbox "Database type configured: $DB_TYPE" 6 40
}

# Configure source
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
        # Cancel or ESC - return without saving
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

# Configure destination
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
        # Cancel or ESC - return without saving
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

# Configure dump file
configure_dump_file() {
    DUMP_FILE=$($DIALOG --clear --backtitle "DB Migration Manager" \
        --title "Dump File" \
        --inputbox "Dump file path:" 8 70 "${DUMP_FILE:-$HOME/Downloads/database.dump}" \
        3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        # Cancel or ESC - return without saving
        return
    fi
    
    save_config
    $DIALOG --clear --backtitle "DB Migration Manager" \
        --title "Success" \
        --msgbox "Dump file configured:\n\n$DUMP_FILE" 8 70
}

# Complete step-by-step configuration
configure_full() {
    # Choose database type
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
        # Cancel or ESC - cancel complete setup
        return
        ;;
    esac

    # Configure source
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
        # Cancel or ESC - cancel complete setup
        return
    fi

    IFS=$'\n' read -rd '' -a arr <<<"$VALUES"
    SRC_HOST="${arr[0]}"
    SRC_PORT="${arr[1]}"
    SRC_USER="${arr[2]}"
    SRC_PASS="${arr[3]}"
    SRC_DB="${arr[4]}"

    # Configure destination
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
        # Cancel or ESC - cancel complete setup
        return
    fi

    IFS=$'\n' read -rd '' -a arr <<<"$VALUES"
    DST_HOST="${arr[0]}"
    DST_PORT="${arr[1]}"
    DST_USER="${arr[2]}"
    DST_PASS="${arr[3]}"
    DST_DB="${arr[4]}"

    # Dump file
    DUMP_FILE=$($DIALOG --clear --backtitle "DB Migration Manager" \
        --title "[4/4] Dump File" \
        --inputbox "Dump file path:" 8 70 "${DUMP_FILE:-$HOME/Downloads/database.dump}" \
        3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        # Cancel or ESC - cancel complete setup
        return
    fi

    save_config

    $DIALOG --clear --backtitle "DB Migration Manager" \
        --title "✅ Complete Setup" \
        --msgbox "All settings saved!\n\nType: $DB_TYPE\n\nSource: $SRC_HOST:$SRC_PORT/$SRC_DB\nDestination: $DST_HOST:$DST_PORT/$DST_DB\n\nDump: $DUMP_FILE" 14 70
}

# View configuration
view_config() {
    if ! load_config; then
        $DIALOG --clear --backtitle "DB Migration Manager" \
            --title "Error" \
            --msgbox "No configuration found. Please configure first." 6 50
        return
    fi

    $DIALOG --clear --backtitle "DB Migration Manager" \
        --title "Current Configuration" \
        --msgbox "Type: $DB_TYPE\n\nSource:\n  Host: $SRC_HOST:$SRC_PORT\n  User: $SRC_USER\n  DB: $SRC_DB\n\nDestination:\n  Host: $DST_HOST:$DST_PORT\n  User: $DST_USER\n  DB: $DST_DB\n\nDump File: $DUMP_FILE" 18 60
}

# Perform dump
perform_dump() {
    if ! load_config; then
        $DIALOG --clear --backtitle "DB Migration Manager" \
            --title "Error" \
            --msgbox "Please configure the database first." 6 50
        return
    fi

    clear
    log_header "DUMP - Exporting Database"
    log_info "🔄 Starting dump of $SRC_DB..."
    ensure_docker_network "$DOCKER_NETWORK"

    case $DB_TYPE in
    mysql)
        "$SCRIPT_DIR/operations/mysql-dump.sh" "$SRC_HOST" "$SRC_PORT" "$SRC_USER" "$SRC_PASS" "$SRC_DB" "$DUMP_FILE"
        ;;
    postgres)
        "$SCRIPT_DIR/operations/postgres-dump.sh" "$SRC_HOST" "$SRC_PORT" "$SRC_USER" "$SRC_PASS" "$SRC_DB" "$DUMP_FILE"
        ;;
    sqlserver)
        "$SCRIPT_DIR/operations/sqlserver-dump.sh" "$SRC_HOST" "$SRC_PORT" "$SRC_USER" "$SRC_PASS" "$SRC_DB" "$DUMP_FILE"
        ;;
    esac

    echo ""
    read -p "Press ENTER to continue..."
}

# Perform load
perform_load() {
    if ! load_config; then
        $DIALOG --clear --backtitle "DB Migration Manager" \
            --title "Error" \
            --msgbox "Please configure the database first." 6 50
        return
    fi

    clear
    log_header "LOAD - Importing Database"
    log_info "📥 Starting load to $DST_DB..."
    ensure_docker_network "$DOCKER_NETWORK"

    case $DB_TYPE in
    mysql)
        "$SCRIPT_DIR/operations/mysql-load.sh" "$DST_HOST" "$DST_PORT" "$DST_USER" "$DST_PASS" "$DST_DB" "$DUMP_FILE"
        ;;
    postgres)
        "$SCRIPT_DIR/operations/postgres-load.sh" "$DST_HOST" "$DST_PORT" "$DST_USER" "$DST_PASS" "$DST_DB" "$DUMP_FILE"
        ;;
    sqlserver)
        "$SCRIPT_DIR/operations/sqlserver-load.sh" "$DST_HOST" "$DST_PORT" "$DST_USER" "$DST_PASS" "$DST_DB" "$DUMP_FILE"
        ;;
    esac

    echo ""
    read -p "Press ENTER to continue..."
}

# Perform migration
perform_migrate() {
    if ! load_config; then
        $DIALOG --clear --backtitle "DB Migration Manager" \
            --title "Error" \
            --msgbox "Please configure the database first." 6 50
        return
    fi

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

    # Dump
    echo ""
    log_step "Step 1/2: Dump..."
    case $DB_TYPE in
    mysql)
        "$SCRIPT_DIR/operations/mysql-dump.sh" "$SRC_HOST" "$SRC_PORT" "$SRC_USER" "$SRC_PASS" "$SRC_DB" "$DUMP_FILE"
        ;;
    postgres)
        "$SCRIPT_DIR/operations/postgres-dump.sh" "$SRC_HOST" "$SRC_PORT" "$SRC_USER" "$SRC_PASS" "$SRC_DB" "$DUMP_FILE"
        ;;
    sqlserver)
        "$SCRIPT_DIR/operations/sqlserver-dump.sh" "$SRC_HOST" "$SRC_PORT" "$SRC_USER" "$SRC_PASS" "$SRC_DB" "$DUMP_FILE"
        ;;
    esac

    # Load
    echo ""
    log_step "Step 2/2: Load..."
    case $DB_TYPE in
    mysql)
        "$SCRIPT_DIR/operations/mysql-load.sh" "$DST_HOST" "$DST_PORT" "$DST_USER" "$DST_PASS" "$DST_DB" "$DUMP_FILE"
        ;;
    postgres)
        "$SCRIPT_DIR/operations/postgres-load.sh" "$DST_HOST" "$DST_PORT" "$DST_USER" "$DST_PASS" "$DST_DB" "$DUMP_FILE"
        ;;
    sqlserver)
        "$SCRIPT_DIR/operations/sqlserver-load.sh" "$DST_HOST" "$DST_PORT" "$DST_USER" "$DST_PASS" "$DST_DB" "$DUMP_FILE"
        ;;
    esac

    echo ""
    log_success "Migration completed!"
    read -p "Press ENTER to continue..."
}

# Main
check_dialog
check_docker
load_config || true
main_menu

#!/bin/bash

###
# Database Migration Manager - Main Application
# Interface TUI para gerenciamento de migrations entre bancos de dados
# Suporta: MySQL, PostgreSQL, SQL Server
###

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.config"
DOCKER_NETWORK="database-migration-network"

source "$SCRIPT_DIR/lib/metadata.lib.sh"
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
    log_info "The bundled dialog binary is not compatible with your system."
    log_info "Please install dialog for your system:"
    log_info "\tUbuntu/Debian:\tsudo apt-get install dialog"
    log_info "\tRedHat/CentOS:\tsudo yum install dialog"
    log_info "\tFedora:\t\tsudo dnf install dialog"
    log_info "\tArch Linux:\tsudo pacman -S dialog"
    log_info "\tmacOS (Homebrew):\tbrew install dialog"
    exit 1
  fi

  if [ "$USE_LOCAL_DIALOG" = true ]; then
    log_success "Using bundled dialog binary (Linux x86_64)"
  else
    log_info "Using system dialog"
  fi
}

list_all_dump_files() {
  {
    ls -t "$DUMP_DIR"/*.txt 2>/dev/null
    ls -t "$DUMP_DIR"/*.bacpac 2>/dev/null
  }
}

count_dump_files() {
  list_all_dump_files | wc -l
}

generate_dump_filename() {
  local db_type="$1"
  local db_name="$2"
  local dump_type="$3"
  local hostname="$4"
  local timestamp=$(date +%Y%m%d-%H%M%S)

  local sanitized_host=$(echo "$hostname" | sed 's/[^a-zA-Z0-9-]/_/g')

  case "$dump_type" in
  structure)
    echo "${db_type}-${sanitized_host}-${db_name}-structure-${timestamp}.txt"
    ;;
  data)
    echo "${db_type}-${sanitized_host}-${db_name}-data-${timestamp}.txt"
    ;;
  both | *)
    echo "${db_type}-${sanitized_host}-${db_name}-full-${timestamp}.txt"
    ;;
  esac
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
EOF
  log_success "Configuration saved to $CONFIG_FILE"
}

load_config() {
  if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    DUMP_DIR="/dumps"
    return 0
  fi
  return 1
}

main_menu() {
  while true; do
    CHOICE=$($DIALOG --clear --backtitle "$PROJECT_NAME v$VERSION" \
      --title "Main Menu" \
      --menu "Choose an operation:" 17 60 7 \
      1 "🗄️  Configure Database" \
      2 "💾 Dump (Export)" \
      3 "📥 Load (Import)" \
      4 "🔄 Migrate (Dump + Load)" \
      5 "📦 Manage Dumps" \
      6 "⚙️  View Configuration" \
      7 "🚪 Exit" \
      3>&1 1>&2 2>&3)

    case $CHOICE in
    1) configure_database ;;
    2) perform_dump ;;
    3) perform_load ;;
    4) perform_migrate ;;
    5) manage_dumps ;;
    6) view_config ;;
    7)
      clear
      exit 0
      ;;
    *) ;;
    esac
  done
}

configure_database() {
  while true; do
    load_config || true

    CONFIG_MENU=$($DIALOG --clear --backtitle "$PROJECT_NAME" \
      --title "Configuration" \
      --menu "What do you want to configure?" 15 65 6 \
      1 "🗄️  Database Type (Current: ${DB_TYPE:-Not configured})" \
      2 "📤 SOURCE Configuration" \
      3 "📥 DESTINATION Configuration" \
      4 "✅ Complete Setup (Step by Step)" \
      5 "👁️  View Current Configuration" \
      6 "🔙 Back to Main Menu" \
      3>&1 1>&2 2>&3)

    case $CONFIG_MENU in
    1) configure_db_type ;;
    2) configure_source ;;
    3) configure_destination ;;
    4) configure_full ;;
    5) view_config ;;
    6) return ;;
    *)
      return
      ;;
    esac
  done
}

configure_db_type() {
  DB_TYPE=$($DIALOG --clear --backtitle "$PROJECT_NAME" \
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
  $DIALOG --clear --backtitle "$PROJECT_NAME" \
    --title "Success" \
    --msgbox "Database type configured: $DB_TYPE" 6 40
}

configure_source() {
  exec 3>&1
  VALUES=$($DIALOG --clear --backtitle "$PROJECT_NAME" \
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
  $DIALOG --clear --backtitle "$PROJECT_NAME" \
    --title "Success" \
    --msgbox "SOURCE configuration saved!\n\nHost: $SRC_HOST:$SRC_PORT\nDB: $SRC_DB" 9 50
}

configure_destination() {
  exec 3>&1
  VALUES=$($DIALOG --clear --backtitle "$PROJECT_NAME" \
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
  $DIALOG --clear --backtitle "$PROJECT_NAME" \
    --title "Success" \
    --msgbox "DESTINATION configuration saved!\n\nHost: $DST_HOST:$DST_PORT\nDB: $DST_DB" 9 50
}

configure_full() {
  DB_TYPE=$($DIALOG --clear --backtitle "$PROJECT_NAME" \
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
  VALUES=$($DIALOG --clear --backtitle "$PROJECT_NAME" \
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
  VALUES=$($DIALOG --clear --backtitle "$PROJECT_NAME" \
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

  save_config

  $DIALOG --clear --backtitle "$PROJECT_NAME" \
    --title "✅ Complete Setup" \
    --msgbox "All settings saved!\n\nType: $DB_TYPE\n\nSource: $SRC_HOST:$SRC_PORT/$SRC_DB\nDestination: $DST_HOST:$DST_PORT/$DST_DB\n\nDumps: $DUMP_DIR (auto-named)" 14 70
}

view_config() {
  if ! load_config; then
    $DIALOG --clear --backtitle "$PROJECT_NAME" \
      --title "Error" \
      --msgbox "No configuration found. Please configure first." 6 50
    return
  fi

  $DIALOG --clear --backtitle "$PROJECT_NAME" \
    --title "Current Configuration" \
    --msgbox "Type: $DB_TYPE\n\nSource:\n  Host: $SRC_HOST:$SRC_PORT\n  User: $SRC_USER\n  DB: $SRC_DB\n\nDestination:\n  Host: $DST_HOST:$DST_PORT\n  User: $DST_USER\n  DB: $DST_DB\n\nDumps: $DUMP_DIR (auto-named files)" 19 60
}

manage_dumps() {
  while true; do
    DUMP_COUNT=$(count_dump_files)
    DUMP_SIZE=$(du -sh "$DUMP_DIR" 2>/dev/null | cut -f1)

    DUMP_ACTION=$($DIALOG --clear --backtitle "$PROJECT_NAME v$VERSION" \
      --title "Manage Dumps" \
      --menu "Dumps: $DUMP_COUNT files ($DUMP_SIZE total)\nLocation: $DUMP_DIR" 16 70 5 \
      1 "📋 List All Dumps" \
      2 "📦 Export Dumps to Host" \
      3 "🗑️  Delete Dump File" \
      4 "ℹ️  Volume Information" \
      5 "🔙 Back to Main Menu" \
      3>&1 1>&2 2>&3)

    case $DUMP_ACTION in
    1) list_dumps ;;
    2) export_dumps ;;
    3) delete_dump ;;
    4) volume_info ;;
    5) return ;;
    *) return ;;
    esac
  done
}

list_dumps() {
  if [ ! -d "$DUMP_DIR" ] || [ $(count_dump_files) -eq 0 ]; then
    $DIALOG --clear --backtitle "$PROJECT_NAME v$VERSION" \
      --title "Dump Files" \
      --msgbox "No dump files found in $DUMP_DIR" 6 50
    return
  fi

  DUMP_LIST=""
  while IFS= read -r file; do
    if [ -z "$file" ]; then continue; fi
    filename=$(basename "$file")
    filesize=$(du -h "$file" 2>/dev/null | cut -f1)
    filedate=$(stat -c '%y' "$file" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1 || stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$file" 2>/dev/null)

    if [[ "$filename" == *.bacpac ]]; then
      DUMP_LIST="$DUMP_LIST$filename (BACPAC)\n  Size: $filesize\n  Date: $filedate\n\n"
    else
      DUMP_LIST="$DUMP_LIST$filename\n  Size: $filesize\n  Date: $filedate\n\n"
    fi
  done < <(list_all_dump_files)

  $DIALOG --clear --backtitle "$PROJECT_NAME v$VERSION" \
    --title "Available Dump Files" \
    --scrolltext \
    --msgbox "$DUMP_LIST" 20 70
}

export_dumps() {
  EXPORT_PATH=$($DIALOG --clear --backtitle "$PROJECT_NAME v$VERSION" \
    --title "Export Dumps" \
    --inputbox "Enter the HOST path where you want to export dumps:\n\nExample: /home/user/backups or C:/Users/user/backups\n\nThis must be a valid path on your HOST machine.\nThe dumps will be copied there." 14 75 "" \
    3>&1 1>&2 2>&3)

  if [ $? -ne 0 ] || [ -z "$EXPORT_PATH" ]; then
    return
  fi

  EXPORT_TYPE=$($DIALOG --clear --backtitle "$PROJECT_NAME v$VERSION" \
    --title "Export Method" \
    --menu "Choose export method:" 12 70 2 \
    1 "Copy individual files (preserves structure)" \
    2 "Create backup archive (.tar.gz)" \
    3>&1 1>&2 2>&3)

  if [ $? -ne 0 ]; then
    return
  fi

  clear
  log_header "Export Dumps to Host"
  log_info "📦 Exporting dumps from Docker volume to host..."
  log_info "🎯 Target: $EXPORT_PATH"

  case $EXPORT_TYPE in
  1)
    log_progress "Copying files..."
    if docker run --rm -v db-migration-dumps:/source -v "$EXPORT_PATH:/target" alpine sh -c 'mkdir -p /target && cp -v /source/*.txt /source/*.bacpac /target/ 2>/dev/null || cp -v /source/*.txt /target/'; then
      log_success "✅ Files exported successfully to: $EXPORT_PATH"
    else
      log_error "❌ Export failed. Make sure the target directory exists and is accessible."
    fi
    ;;
  2)
    ARCHIVE_NAME="dumps-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    log_progress "Creating archive: $ARCHIVE_NAME..."
    if docker run --rm -v db-migration-dumps:/dumps -v "$EXPORT_PATH:/backup" alpine tar czf "/backup/$ARCHIVE_NAME" -C /dumps .; then
      log_success "✅ Archive created: $EXPORT_PATH/$ARCHIVE_NAME"
    else
      log_error "❌ Archive creation failed. Make sure the target directory exists and is accessible."
    fi
    ;;
  esac

  read -p "Press ENTER to continue..."
}

delete_dump() {
  if [ ! -d "$DUMP_DIR" ] || [ $(count_dump_files) -eq 0 ]; then
    $DIALOG --clear --backtitle "$PROJECT_NAME v$VERSION" \
      --title "Error" \
      --msgbox "No dump files found in $DUMP_DIR" 6 50
    return
  fi

  MENU_OPTIONS=()
  while IFS= read -r file; do
    if [ -z "$file" ]; then continue; fi
    filename=$(basename "$file")
    filesize=$(du -h "$file" 2>/dev/null | cut -f1)

    if [[ "$filename" == *.bacpac ]]; then
      MENU_OPTIONS+=("$file" "$filename ($filesize) [BACPAC]")
    else
      MENU_OPTIONS+=("$file" "$filename ($filesize)")
    fi
  done < <(list_all_dump_files)

  FILE_TO_DELETE=$($DIALOG --clear --backtitle "$PROJECT_NAME v$VERSION" \
    --title "Delete Dump File" \
    --menu "Select a file to delete:" 20 70 12 \
    "${MENU_OPTIONS[@]}" \
    3>&1 1>&2 2>&3)

  if [ $? -ne 0 ] || [ -z "$FILE_TO_DELETE" ]; then
    return
  fi

  $DIALOG --clear --backtitle "$PROJECT_NAME v$VERSION" \
    --title "Confirm Deletion" \
    --yesno "Are you sure you want to delete:\n\n$(basename "$FILE_TO_DELETE")\n\nThis action cannot be undone!" 10 60

  if [ $? -eq 0 ]; then
    rm -f "$FILE_TO_DELETE"

    if [[ "$FILE_TO_DELETE" == *.txt ]]; then
      BACPAC_FILE="${FILE_TO_DELETE%.txt}.bacpac"
      if [ -f "$BACPAC_FILE" ]; then
        rm -f "$BACPAC_FILE"
      fi
    fi

    $DIALOG --clear --backtitle "$PROJECT_NAME v$VERSION" \
      --title "Success" \
      --msgbox "File deleted successfully!" 6 40
  fi
}

volume_info() {
  VOLUME_NAME="db-migration-dumps"

  INFO_TEXT="Docker Volume Information\n\n"
  INFO_TEXT="${INFO_TEXT}Volume Name: $VOLUME_NAME\n"
  INFO_TEXT="${INFO_TEXT}Mount Point: $DUMP_DIR\n"
  INFO_TEXT="${INFO_TEXT}Total Size: $(du -sh "$DUMP_DIR" 2>/dev/null | cut -f1)\n"
  INFO_TEXT="${INFO_TEXT}File Count: $(count_dump_files) dumps\n\n"
  INFO_TEXT="${INFO_TEXT}Commands to manage volume:\n\n"
  INFO_TEXT="${INFO_TEXT}• Inspect volume:\n"
  INFO_TEXT="${INFO_TEXT}  docker volume inspect $VOLUME_NAME\n\n"
  INFO_TEXT="${INFO_TEXT}• List files:\n"
  INFO_TEXT="${INFO_TEXT}  docker run --rm -v $VOLUME_NAME:/dumps alpine ls -lh /dumps\n\n"
  INFO_TEXT="${INFO_TEXT}• Backup volume:\n"
  INFO_TEXT="${INFO_TEXT}  docker run --rm -v $VOLUME_NAME:/dumps \\\\\n"
  INFO_TEXT="${INFO_TEXT}    -v \$(pwd):/backup alpine \\\\\n"
  INFO_TEXT="${INFO_TEXT}    tar czf /backup/dumps.tar.gz /dumps"

  $DIALOG --clear --backtitle "$PROJECT_NAME v$VERSION" \
    --title "Volume Information" \
    --msgbox "$INFO_TEXT" 24 80
}

perform_dump() {
  if ! load_config; then
    $DIALOG --clear --backtitle "$PROJECT_NAME" \
      --title "Error" \
      --msgbox "Please configure the database first." 6 50
    return
  fi

  DUMP_TYPE="both"
  if [ "$DB_TYPE" = "mysql" ] || [ "$DB_TYPE" = "postgres" ]; then
    DUMP_TYPE=$($DIALOG --clear --backtitle "$PROJECT_NAME" \
      --title "Select Dump Type" \
      --default-item "both" \
      --menu "What should be included in the dump?" 12 60 3 \
      "both" "Structure + Data (Recommended)" \
      "structure" "Structure only (no data)" \
      "data" "Data only (no structure)" \
      3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
      return
    fi
  fi

  clear
  log_header "DUMP - Exporting Database"

  case "$DUMP_TYPE" in
  structure)
    log_info "🔄 Starting structure-only dump of $SRC_DB..."
    ;;
  data)
    log_info "🔄 Starting data-only dump of $SRC_DB..."
    ;;
  both)
    log_info "🔄 Starting full dump of $SRC_DB..."
    ;;
  esac

  ensure_docker_network "$DOCKER_NETWORK"

  DUMP_FILENAME=$(generate_dump_filename "$DB_TYPE" "$SRC_DB" "$DUMP_TYPE" "$SRC_HOST")
  DUMP_FILE="$DUMP_DIR/$DUMP_FILENAME"
  log_info "📄 File: $DUMP_FILENAME"

  case $DB_TYPE in
  mysql)
    "$SCRIPT_DIR/operation/mysql-dump.operation.sh" "$SRC_HOST" "$SRC_PORT" "$SRC_USER" "$SRC_PASS" "$SRC_DB" "$DUMP_FILE" "$DUMP_TYPE"
    ;;
  postgres)
    "$SCRIPT_DIR/operation/postgres-dump.operation.sh" "$SRC_HOST" "$SRC_PORT" "$SRC_USER" "$SRC_PASS" "$SRC_DB" "$DUMP_FILE" "$DUMP_TYPE"
    ;;
  sqlserver)
    "$SCRIPT_DIR/operation/sqlserver-dump.operation.sh" "$SRC_HOST" "$SRC_PORT" "$SRC_USER" "$SRC_PASS" "$SRC_DB" "$DUMP_FILE" "$DUMP_TYPE"
    ;;
  esac

  read -p "Press ENTER to continue..."
}

perform_load() {
  if ! load_config; then
    $DIALOG --clear --backtitle "$PROJECT_NAME" \
      --title "Error" \
      --msgbox "Please configure the database first." 6 50
    return
  fi

  if [ ! -d "$DUMP_DIR" ] || [ -z "$(ls -A "$DUMP_DIR"/*.txt 2>/dev/null)" ]; then
    $DIALOG --clear --backtitle "$PROJECT_NAME" \
      --title "Error" \
      --msgbox "No dump files found in $DUMP_DIR" 6 50
    return
  fi

  MENU_OPTIONS=()
  while IFS= read -r file; do
    filename=$(basename "$file")
    filesize=$(du -h "$file" 2>/dev/null | cut -f1)
    filedate=$(stat -c '%y' "$file" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1 || stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$file" 2>/dev/null)
    MENU_OPTIONS+=("$file" "$filename ($filesize) - $filedate")
  done < <(ls -t "$DUMP_DIR"/*.txt 2>/dev/null)

  if [ ${#MENU_OPTIONS[@]} -eq 0 ]; then
    $DIALOG --clear --backtitle "$PROJECT_NAME" \
      --title "Error" \
      --msgbox "No dump files found in $DUMP_DIR" 6 50
    return
  fi

  SELECTED_DUMP=$($DIALOG --clear --backtitle "DB Migration Manager v$VERSION - Docker Mode" \
    --title "Select Dump File" \
    --menu "Choose a dump file to import:" 20 80 12 \
    "${MENU_OPTIONS[@]}" \
    3>&1 1>&2 2>&3)

  if [ $? -ne 0 ] || [ -z "$SELECTED_DUMP" ]; then
    return
  fi

  if [ ! -f "$SELECTED_DUMP" ]; then
    $DIALOG --clear --backtitle "$PROJECT_NAME" \
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

  read -p "Press ENTER to continue..."
}

perform_migrate() {
  if ! load_config; then
    $DIALOG --clear --backtitle "$PROJECT_NAME" \
      --title "Error" \
      --msgbox "Please configure the database first." 6 50
    return
  fi

  DUMP_TYPE="both"
  if [ "$DB_TYPE" = "mysql" ] || [ "$DB_TYPE" = "postgres" ]; then
    DUMP_TYPE=$($DIALOG --clear --backtitle "$PROJECT_NAME" \
      --title "Select Migration Type" \
      --default-item "both" \
      --menu "What should be migrated?" 12 60 3 \
      "both" "Structure + Data (Recommended)" \
      "structure" "Structure only (no data)" \
      "data" "Data only (no structure)" \
      3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
      return
    fi
  fi

  $DIALOG --clear --backtitle "$PROJECT_NAME" \
    --title "Confirmation" \
    --yesno "Migrate $SRC_DB to $DST_DB?\n\nThis will:\n1. Dump from source\n2. Load to destination" 10 50

  if [ $? -ne 0 ]; then
    return
  fi

  clear
  log_header "MIGRATE - Complete Migration"
  
  case "$DUMP_TYPE" in
    structure)
      log_info "🔄 Starting structure-only migration from $SRC_DB to $DST_DB..."
      ;;
    data)
      log_info "🔄 Starting data-only migration from $SRC_DB to $DST_DB..."
      ;;
    both)
      log_info "🔄 Starting full migration from $SRC_DB to $DST_DB..."
      ;;
  esac
  
  ensure_docker_network "$DOCKER_NETWORK"

  DUMP_FILENAME=$(generate_dump_filename "$DB_TYPE" "$SRC_DB" "$DUMP_TYPE" "$SRC_HOST")
  DUMP_FILE="$DUMP_DIR/$DUMP_FILENAME"
  log_info "📄 File: $DUMP_FILENAME"

  log_step "Step 1/2: Dump..."
  case $DB_TYPE in
  mysql)
    "$SCRIPT_DIR/operation/mysql-dump.operation.sh" "$SRC_HOST" "$SRC_PORT" "$SRC_USER" "$SRC_PASS" "$SRC_DB" "$DUMP_FILE" "$DUMP_TYPE"
    ;;
  postgres)
    "$SCRIPT_DIR/operation/postgres-dump.operation.sh" "$SRC_HOST" "$SRC_PORT" "$SRC_USER" "$SRC_PASS" "$SRC_DB" "$DUMP_FILE" "$DUMP_TYPE"
    ;;
  sqlserver)
    "$SCRIPT_DIR/operation/sqlserver-dump.operation.sh" "$SRC_HOST" "$SRC_PORT" "$SRC_USER" "$SRC_PASS" "$SRC_DB" "$DUMP_FILE" "$DUMP_TYPE"
    ;;
  esac

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

  log_success "Migration completed!"
  read -p "Press ENTER to continue..."
}

check_dialog
check_docker
load_config || true
main_menu

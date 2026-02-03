#!/bin/bash

# SQL Server Load (Restore) usando Docker
# Note: Not using 'set -e' to handle errors gracefully

DST_HOST=$1
DST_PORT=$2
DST_USER=$3
DST_PASS=$4
DST_DB=$5
DUMP_FILE=$6

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funções de log
log_info() { echo -e "${BLUE}ℹ️  $*${NC}"; }
log_success() { echo -e "${GREEN}✅ $*${NC}"; }
log_error() { echo -e "${RED}❌ $*${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_progress() { echo -e "${YELLOW}⏳ $*${NC}"; }

if [ ! -f "$DUMP_FILE" ]; then
    log_error "Backup file not found: $DUMP_FILE"
    exit 1
fi

log_progress "Restoring $DST_DB on $DST_HOST:$DST_PORT..."

BACKUP_NAME="$(basename "$DUMP_FILE")"
BACKUP_PATH="/var/opt/mssql/data/$BACKUP_NAME"

# Nota: Para SQL Server, o arquivo de backup precisa estar no servidor
# Esta é uma implementação simplificada
log_warning "Nota: O arquivo de backup deve estar disponível no servidor SQL Server."
log_warning "Caminho esperado: $BACKUP_PATH"

# Restaurar database
docker run --rm \
    --network host \
    mcr.microsoft.com/mssql-tools \
    /opt/mssql-tools/bin/sqlcmd \
    -S "$DST_HOST,$DST_PORT" \
    -U "$DST_USER" \
    -P "$DST_PASS" \
    -Q "RESTORE DATABASE [$DST_DB] FROM DISK = N'$BACKUP_PATH' WITH REPLACE, STATS = 10"

if [ $? -ne 0 ]; then
    log_error "Restore failed."
    exit 1
fi

log_success "Restore successful."

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
    log_error "Dump file not found: $DUMP_FILE"
    exit 1
fi

# Ler caminho do backup do arquivo de referência
BACKUP_PATH=$(cat "$DUMP_FILE")

if [ -z "$BACKUP_PATH" ]; then
    log_error "Invalid backup reference file"
    exit 1
fi

log_progress "Restoring $DST_DB on $DST_HOST:$DST_PORT..."

# Obter informações dos arquivos lógicos do backup
log_info "Reading backup file information..."
FILELISTONLY_OUTPUT=$(docker run --rm \
    --network host \
    mcr.microsoft.com/mssql-tools \
    /opt/mssql-tools/bin/sqlcmd \
    -S "$DST_HOST,$DST_PORT" \
    -U "$DST_USER" \
    -P "$DST_PASS" \
    -W \
    -h -1 \
    -s "," \
    -Q "SET NOCOUNT ON; RESTORE FILELISTONLY FROM DISK = N'$BACKUP_PATH'" 2>&1)

if [ $? -ne 0 ]; then
    log_error "Failed to read backup file information"
    echo "$FILELISTONLY_OUTPUT"
    exit 1
fi

# Extrair nomes dos arquivos lógicos (primeira coluna do resultado)
# Formato: LogicalName,PhysicalName,Type,...
# Type está na terceira coluna: D=Data, L=Log
DATA_LOGICAL=$(echo "$FILELISTONLY_OUTPUT" | grep -v "^$" | awk -F',' '$3 == "D" {print $1; exit}' | tr -d ' ')
LOG_LOGICAL=$(echo "$FILELISTONLY_OUTPUT" | grep -v "^$" | awk -F',' '$3 == "L" {print $1; exit}' | tr -d ' ')

if [ -z "$DATA_LOGICAL" ] || [ -z "$LOG_LOGICAL" ]; then
    log_error "Could not determine logical file names from backup"
    log_info "FILELISTONLY output:"
    echo "$FILELISTONLY_OUTPUT"
    exit 1
fi

log_info "Data file: $DATA_LOGICAL -> ${DST_DB}.mdf"
log_info "Log file: $LOG_LOGICAL -> ${DST_DB}_log.ldf"

# Definir novos caminhos físicos para o banco de destino
DATA_FILE="/var/opt/mssql/data/${DST_DB}.mdf"
LOG_FILE="/var/opt/mssql/data/${DST_DB}_log.ldf"

# Restaurar database com MOVE
RESTORE_OUTPUT=$(docker run --rm \
    --network host \
    mcr.microsoft.com/mssql-tools \
    /opt/mssql-tools/bin/sqlcmd \
    -S "$DST_HOST,$DST_PORT" \
    -U "$DST_USER" \
    -P "$DST_PASS" \
    -Q "RESTORE DATABASE [$DST_DB] FROM DISK = N'$BACKUP_PATH' WITH MOVE N'$DATA_LOGICAL' TO N'$DATA_FILE', MOVE N'$LOG_LOGICAL' TO N'$LOG_FILE', REPLACE, STATS = 10" 2>&1)

RESTORE_EXIT=$?
echo "$RESTORE_OUTPUT"

if [ $RESTORE_EXIT -ne 0 ] || echo "$RESTORE_OUTPUT" | grep -qi "error\|failed\|terminating abnormally"; then
    log_error "Restore failed."
    exit 1
fi

log_success "Restore successful."

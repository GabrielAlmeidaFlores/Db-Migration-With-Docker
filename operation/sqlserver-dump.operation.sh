#!/bin/bash

# SQL Server Dump (Backup) usando Docker
# Note: Not using 'set -e' to handle errors gracefully

SRC_HOST=$1
SRC_PORT=$2
SRC_USER=$3
SRC_PASS=$4
SRC_DB=$5
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

DUMP_DIR="$(dirname "$DUMP_FILE")"
DUMP_BASENAME="$(basename "$DUMP_FILE")"

if [ ! -d "$DUMP_DIR" ]; then
    log_error "Dump directory does not exist: $DUMP_DIR"
    exit 1
fi

log_progress "Backing up $SRC_DB from $SRC_HOST:$SRC_PORT..."

# Para SQL Server, usamos sqlcmd para criar um backup
# Nota: SQL Server BACKUP DATABASE cria arquivo .bak no servidor remoto
# Não é possível redirecionar para stdout como MySQL/PostgreSQL
BACKUP_NAME="${DUMP_BASENAME%.txt}.bak"
BACKUP_PATH="/var/opt/mssql/data/$BACKUP_NAME"

if [ -n "$RUNNING_IN_DOCKER" ]; then
    # Rodando em Docker: backup fica no servidor remoto
    docker run --rm \
        --network host \
        mcr.microsoft.com/mssql-tools \
        /opt/mssql-tools/bin/sqlcmd \
        -S "$SRC_HOST,$SRC_PORT" \
        -U "$SRC_USER" \
        -P "$SRC_PASS" \
        -Q "BACKUP DATABASE [$SRC_DB] TO DISK = N'$BACKUP_PATH' WITH FORMAT, INIT, NAME = N'$SRC_DB-Full', SKIP, NOREWIND, NOUNLOAD, STATS = 1"
    
    if [ $? -ne 0 ]; then
        log_error "Backup failed."
        exit 1
    fi
    
    # Salvar referência do caminho remoto
    echo "$BACKUP_PATH" > "$DUMP_FILE"
else
    # Rodando direto no host: backup fica no servidor remoto
    docker run --rm \
        --network host \
        mcr.microsoft.com/mssql-tools \
        /opt/mssql-tools/bin/sqlcmd \
        -S "$SRC_HOST,$SRC_PORT" \
        -U "$SRC_USER" \
        -P "$SRC_PASS" \
        -Q "BACKUP DATABASE [$SRC_DB] TO DISK = N'$BACKUP_PATH' WITH FORMAT, INIT, NAME = N'$SRC_DB-Full', SKIP, NOREWIND, NOUNLOAD, STATS = 1"
    
    if [ $? -ne 0 ]; then
        log_error "Backup failed."
        exit 1
    fi
    
    # Salvar referência do caminho remoto
    echo "$BACKUP_PATH" > "$DUMP_FILE"
fi

FILE_SIZE=$(du -h "$DUMP_FILE" 2>/dev/null | cut -f1 || echo "reference")
log_success "Backup successful: $DUMP_FILE ($FILE_SIZE) [Server: $BACKUP_PATH]"

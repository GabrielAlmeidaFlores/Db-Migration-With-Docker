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

# Criar diretório de destino se não existir
mkdir -p "$(dirname "$DUMP_FILE")"

log_progress "Backing up $SRC_DB from $SRC_HOST:$SRC_PORT..."

# Para SQL Server, usamos sqlcmd para criar um backup
BACKUP_NAME="$(basename "$DUMP_FILE" .bak).bak"
BACKUP_PATH="/var/opt/mssql/data/$BACKUP_NAME"

# Executar backup no servidor
docker run --rm \
    --network host \
    mcr.microsoft.com/mssql-tools \
    /opt/mssql-tools/bin/sqlcmd \
    -S "$SRC_HOST,$SRC_PORT" \
    -U "$SRC_USER" \
    -P "$SRC_PASS" \
    -Q "BACKUP DATABASE [$SRC_DB] TO DISK = N'$BACKUP_PATH' WITH FORMAT, INIT, NAME = N'$SRC_DB-Full', SKIP, NOREWIND, NOUNLOAD, STATS = 10"

if [ $? -ne 0 ]; then
    log_error "Backup failed."
    exit 1
fi

log_info "Downloading backup file..."

# Nota: Em produção, você precisaria copiar o arquivo do servidor SQL Server
# Esta é uma implementação simplificada
log_warning "Nota: O backup foi criado no servidor em: $BACKUP_PATH"
log_warning "Você precisará copiar manualmente ou usar ferramentas adicionais."

# Criar um arquivo de referência
echo "Backup criado em: $SRC_HOST:$BACKUP_PATH" >"$DUMP_FILE.info"

log_success "Backup successful: $BACKUP_PATH"

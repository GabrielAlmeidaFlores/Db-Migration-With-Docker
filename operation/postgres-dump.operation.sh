#!/bin/bash

# PostgreSQL Dump usando Docker
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
log_progress() { echo -e "${YELLOW}⏳ $*${NC}"; }

# Criar diretório de destino se não existir
mkdir -p "$(dirname "$DUMP_FILE")"

log_progress "Dumping $SRC_DB from $SRC_HOST:$SRC_PORT..."

# Use Docker to run pg_dump (version 16 for compatibility)
docker run --rm \
    --network host \
    -e PGPASSWORD="$SRC_PASS" \
    -v "$(dirname "$DUMP_FILE"):/backup" \
    postgres:16-alpine \
    pg_dump \
    -h "$SRC_HOST" \
    -p "$SRC_PORT" \
    -U "$SRC_USER" \
    -d "$SRC_DB" \
    -F c \
    -f "/backup/$(basename "$DUMP_FILE")"

if [ $? -ne 0 ]; then
    log_error "Dump failed."
    rm -f "$DUMP_FILE"
    exit 1
fi

FILE_SIZE=$(du -h "$DUMP_FILE" | cut -f1)
log_success "Dump successful: $DUMP_FILE ($FILE_SIZE)"

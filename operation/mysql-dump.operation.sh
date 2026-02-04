#!/bin/bash

# MySQL Dump usando Docker
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

DUMP_DIR="$(dirname "$DUMP_FILE")"
DUMP_BASENAME="$(basename "$DUMP_FILE")"

if [ ! -d "$DUMP_DIR" ]; then
    log_error "Dump directory does not exist: $DUMP_DIR"
    exit 1
fi

log_progress "Dumping $SRC_DB from $SRC_HOST:$SRC_PORT..."

# Verificar se está rodando dentro do Docker
if [ -n "$RUNNING_IN_DOCKER" ]; then
    # Rodando em Docker: criar dump localmente e copiar do container temporário
    docker run --rm \
        --network host \
        -e MYSQL_PWD="$SRC_PASS" \
        mysql:8.0 \
        sh -c "mysqldump \
        -h $SRC_HOST \
        -P $SRC_PORT \
        -u $SRC_USER \
        --verbose \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        $SRC_DB" > "$DUMP_FILE"
else
    # Rodando direto no host: usar volume mount
    docker run --rm \
        --network host \
        -e MYSQL_PWD="$SRC_PASS" \
        -v "$DUMP_DIR:/backup" \
        mysql:8.0 \
        sh -c "mysqldump \
        -h $SRC_HOST \
        -P $SRC_PORT \
        -u $SRC_USER \
        --verbose \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        $SRC_DB > /backup/$DUMP_BASENAME"
fi

if [ $? -ne 0 ]; then
    log_error "Dump failed."
    exit 1
fi

# Verificar se o arquivo foi criado
if [ ! -f "$DUMP_FILE" ]; then
    log_error "Dump file was not created."
    exit 1
fi

FILE_SIZE=$(du -h "$DUMP_FILE" | cut -f1)
log_success "Dump successful: $DUMP_FILE ($FILE_SIZE)"

#!/bin/bash

###
# PostgreSQL Dump Operation
# Exporta um banco PostgreSQL usando pg_dump via Docker
# Args:
#   $1: SRC_HOST - Host do servidor PostgreSQL
#   $2: SRC_PORT - Porta do servidor PostgreSQL
#   $3: SRC_USER - Usuário do banco
#   $4: SRC_PASS - Senha do banco
#   $5: SRC_DB - Nome do banco de dados
#   $6: DUMP_FILE - Caminho completo para salvar o dump
###

source "$(dirname "$0")/../lib/metadata.lib.sh"
source "$PROJECT_ROOT/lib/log.lib.sh"

SRC_HOST=$1
SRC_PORT=$2
SRC_USER=$3
SRC_PASS=$4
SRC_DB=$5
DUMP_FILE=$6

DUMP_DIR="$(dirname "$DUMP_FILE")"

if [ "$DUMP_DIR" != "/dumps" ]; then
    log_error "Dump directory must be /dumps (configured: $DUMP_DIR)"
    log_info "When running in Docker, dumps must go to the Docker volume"
    exit 1
fi

if [ ! -d "$DUMP_DIR" ]; then
    log_error "Dump directory does not exist: $DUMP_DIR"
    exit 1
fi

log_progress "Dumping $SRC_DB from $SRC_HOST:$SRC_PORT..."

docker run --rm \
    --network host \
    -e PGPASSWORD="$SRC_PASS" \
    postgres:16-alpine \
    pg_dump \
    -h "$SRC_HOST" \
    -p "$SRC_PORT" \
    -U "$SRC_USER" \
    -d "$SRC_DB" \
    -F c \
    --verbose > "$DUMP_FILE"

if [ $? -ne 0 ]; then
    log_error "Dump failed."
    rm -f "$DUMP_FILE"
    exit 1
fi

if [ ! -f "$DUMP_FILE" ]; then
    log_error "Dump file was not created."
    exit 1
fi

FILE_SIZE=$(du -h "$DUMP_FILE" | cut -f1)
log_success "Dump successful: $DUMP_FILE ($FILE_SIZE)"

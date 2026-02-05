#!/bin/bash

###
# PostgreSQL Load Operation
# Importa um dump PostgreSQL usando pg_restore via Docker
# Args:
#   $1: DST_HOST - Host do servidor PostgreSQL destino
#   $2: DST_PORT - Porta do servidor PostgreSQL
#   $3: DST_USER - Usuário do banco
#   $4: DST_PASS - Senha do banco
#   $5: DST_DB - Nome do banco de dados destino
#   $6: DUMP_FILE - Caminho do arquivo de dump
###

source "$(dirname "$0")/../lib/metadata.lib.sh"
source "$PROJECT_ROOT/lib/log.lib.sh"

DST_HOST=$1
DST_PORT=$2
DST_USER=$3
DST_PASS=$4
DST_DB=$5
DUMP_FILE=$6

if [ ! -f "$DUMP_FILE" ]; then
    log_error "Dump file not found: $DUMP_FILE"
    exit 1
fi

log_progress "Importing (pg_restore) into $DST_DB on $DST_HOST:$DST_PORT..."

cat "$DUMP_FILE" | docker run --rm -i \
    --network host \
    -e PGPASSWORD="$DST_PASS" \
    postgres:16-alpine \
    pg_restore \
    -h "$DST_HOST" \
    -p "$DST_PORT" \
    -U "$DST_USER" \
    -d "$DST_DB" \
    --verbose \
    --clean \
    --if-exists \
    --no-owner \
    --no-acl

if [ $? -ne 0 ]; then
    log_error "Import failed."
    exit 1
fi

log_success "Import successful."

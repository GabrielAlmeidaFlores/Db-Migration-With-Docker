#!/bin/bash

###
# MySQL Load Operation
# Importa um dump MySQL usando mysql via Docker
# Args:
#   $1: DST_HOST - Host do servidor MySQL destino
#   $2: DST_PORT - Porta do servidor MySQL
#   $3: DST_USER - Usuário do banco
#   $4: DST_PASS - Senha do banco
#   $5: DST_DB - Nome do banco de dados destino
#   $6: DUMP_FILE - Caminho do arquivo de dump
#   $7: FORCE - Se true, continua mesmo com erros (padrão: false)
#   $8: CREATE_DB - Se true, cria o banco caso não exista (padrão: false)
###

source "$(dirname "$0")/../lib/metadata.lib.sh"
source "$PROJECT_ROOT/lib/log.lib.sh"

DST_HOST=$1
DST_PORT=$2
DST_USER=$3
DST_PASS=$4
DST_DB=$5
DUMP_FILE=$6
FORCE=${7:-false}
CREATE_DB=${8:-false}

if [ ! -f "$DUMP_FILE" ]; then
    log_error "Dump file not found: $DUMP_FILE"
    exit 1
fi

if [ "$CREATE_DB" = "true" ]; then
    log_info "🗄️  Creating database if not exists: $DST_DB"
    docker run --rm \
        --network host \
        -e MYSQL_PWD="$DST_PASS" \
        mysql:8.0 \
        mysql \
        -h "$DST_HOST" \
        -P "$DST_PORT" \
        -u "$DST_USER" \
        -e "CREATE DATABASE IF NOT EXISTS \`$DST_DB\`;"
    if [ $? -ne 0 ]; then
        log_error "Failed to create database."
        exit 1
    fi
fi

log_progress "Importing into $DST_DB on $DST_HOST:$DST_PORT..."

FORCE_FLAG=""
if [ "$FORCE" = "true" ]; then
    FORCE_FLAG="--force"
    log_info "⚠️  Force mode enabled: errors will be ignored."
fi

cat "$DUMP_FILE" | docker run --rm -i \
    --network host \
    -e MYSQL_PWD="$DST_PASS" \
    mysql:8.0 \
    mysql \
    -h "$DST_HOST" \
    -P "$DST_PORT" \
    -u "$DST_USER" \
    --verbose \
    $FORCE_FLAG \
    "$DST_DB"

if [ $? -ne 0 ]; then
    log_error "Import failed."
    exit 1
fi

log_success "Import successful."

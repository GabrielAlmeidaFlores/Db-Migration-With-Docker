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
    DB_EXISTS=$(docker run --rm \
        --network host \
        -e PGPASSWORD="$DST_PASS" \
        postgres:16-alpine \
        psql \
        -h "$DST_HOST" \
        -p "$DST_PORT" \
        -U "$DST_USER" \
        -d postgres \
        -tAc "SELECT 1 FROM pg_database WHERE datname='$DST_DB'")
    if [ "$DB_EXISTS" != "1" ]; then
        docker run --rm \
            --network host \
            -e PGPASSWORD="$DST_PASS" \
            postgres:16-alpine \
            createdb \
            -h "$DST_HOST" \
            -p "$DST_PORT" \
            -U "$DST_USER" \
            "$DST_DB"
        if [ $? -ne 0 ]; then
            log_error "Failed to create database."
            exit 1
        fi
    else
        log_info "Database already exists, skipping creation."
    fi
fi

log_progress "Importing (pg_restore) into $DST_DB on $DST_HOST:$DST_PORT..."

EXIT_ON_ERROR_FLAG="-e"
if [ "$FORCE" = "true" ]; then
    EXIT_ON_ERROR_FLAG=""
    log_info "⚠️  Force mode enabled: errors will be ignored."
fi

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
    --no-acl \
    $EXIT_ON_ERROR_FLAG

if [ $? -ne 0 ]; then
    log_error "Import failed."
    exit 1
fi

log_success "Import successful."

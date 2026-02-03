#!/bin/bash

# MySQL Load usando Docker
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
log_progress() { echo -e "${YELLOW}⏳ $*${NC}"; }

if [ ! -f "$DUMP_FILE" ]; then
    log_error "Dump file not found: $DUMP_FILE"
    exit 1
fi

log_info "Creating database $DST_DB on $DST_HOST:$DST_PORT if it doesn't exist..."

# Criar database se não existir
docker run --rm \
    --network host \
    -e MYSQL_PWD="$DST_PASS" \
    mysql:8.0 \
    mysql \
    -h "$DST_HOST" \
    -P "$DST_PORT" \
    -u "$DST_USER" \
    -e "CREATE DATABASE IF NOT EXISTS \`$DST_DB\`;"

log_progress "Importing into $DST_DB on $DST_HOST:$DST_PORT..."

# Importar dump
docker run --rm \
    --network host \
    -e MYSQL_PWD="$DST_PASS" \
    -v "$DUMP_FILE:/backup/dump.sql:ro" \
    mysql:8.0 \
    mysql \
    -h "$DST_HOST" \
    -P "$DST_PORT" \
    -u "$DST_USER" \
    "$DST_DB" </backup/dump.sql

if [ $? -ne 0 ]; then
    log_error "Import failed."
    exit 1
fi

log_success "Import successful."

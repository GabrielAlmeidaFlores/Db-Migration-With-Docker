#!/bin/bash

# PostgreSQL Load usando Docker
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

log_progress "Importing (pg_restore) into $DST_DB on $DST_HOST:$DST_PORT..."

# Import with pg_restore using Docker (version 16 for compatibility)
docker run --rm \
    --network host \
    -e PGPASSWORD="$DST_PASS" \
    -v "$DUMP_FILE:/backup/dump.custom:ro" \
    postgres:16-alpine \
    pg_restore \
    -h "$DST_HOST" \
    -p "$DST_PORT" \
    -U "$DST_USER" \
    -d "$DST_DB" \
    --clean \
    --if-exists \
    --no-owner \
    --no-acl \
    /backup/dump.custom

if [ $? -ne 0 ]; then
    log_error "Import failed."
    exit 1
fi

log_success "Import successful."

#!/bin/bash

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

log_info() { echo -e "${BLUE}ℹ️  $*${NC}"; }
log_success() { echo -e "${GREEN}✅ $*${NC}"; }
log_error() { echo -e "${RED}❌ $*${NC}"; }
log_progress() { echo -e "${YELLOW}⏳ $*${NC}"; }

if [ ! -f "$DUMP_FILE" ]; then
    log_error "Dump file not found: $DUMP_FILE"
    log_info "Note: When running in Docker mode, DUMP_DIR must be an absolute path on the HOST machine"
    log_info "Example: /home/user/Downloads (not /root/Downloads inside container)"
    exit 1
fi

log_progress "Importing (pg_restore) into $DST_DB on $DST_HOST:$DST_PORT..."

if [ -n "$RUNNING_IN_DOCKER" ]; then
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
else
    DUMP_DIR="$(dirname "$DUMP_FILE")"
    DUMP_BASENAME="$(basename "$DUMP_FILE")"
    docker run --rm \
        --network host \
        -e PGPASSWORD="$DST_PASS" \
        -v "$DUMP_DIR:/backup:ro" \
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
        "/backup/$DUMP_BASENAME"
fi

if [ $? -ne 0 ]; then
    log_error "Import failed."
    exit 1
fi

log_success "Import successful."

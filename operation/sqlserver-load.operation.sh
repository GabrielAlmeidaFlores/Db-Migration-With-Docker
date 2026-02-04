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
log_warning() { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_progress() { echo -e "${YELLOW}⏳ $*${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"

if [ -n "$RUNNING_IN_DOCKER" ] && [ -n "$HOST_WORKSPACE_DIR" ]; then
    SQLPACKAGE_DIR="$HOST_WORKSPACE_DIR/dependencies/sqlpackage"
else
    SQLPACKAGE_DIR="$SCRIPT_DIR/dependencies/sqlpackage"
fi

if [ ! -f "$DUMP_FILE" ]; then
    log_error "Dump file not found: $DUMP_FILE"
    exit 1
fi

if [ -z "$RUNNING_IN_DOCKER" ] && [ ! -d "$SQLPACKAGE_DIR" ]; then
    log_error "sqlpackage directory not found at: $SQLPACKAGE_DIR"
    log_info "Please ensure dependencies/sqlpackage/ directory exists"
    exit 1
fi

BACPAC_FILE=$(cat "$DUMP_FILE")

if [ -z "$BACPAC_FILE" ] || [ ! -f "$BACPAC_FILE" ]; then
    log_error "BACPAC file not found: $BACPAC_FILE"
    exit 1
fi

log_progress "Importing $DST_DB on $DST_HOST:$DST_PORT from BACPAC..."

BACPAC_DIR="$(dirname "$BACPAC_FILE")"
BACPAC_BASENAME="$(basename "$BACPAC_FILE")"

if [ -n "$RUNNING_IN_DOCKER" ]; then
    docker run --rm \
        --network host \
        -v "$SQLPACKAGE_DIR:/sqlpackage:ro" \
        -v "$DUMPS_VOLUME:/backup:ro" \
        mcr.microsoft.com/dotnet/runtime:8.0 \
        dotnet /sqlpackage/sqlpackage.dll /Action:Import \
        /TargetConnectionString:"Server=$DST_HOST,$DST_PORT;Database=$DST_DB;User Id=$DST_USER;Password=$DST_PASS;Encrypt=False;TrustServerCertificate=True;" \
        /SourceFile:"/backup/$BACPAC_BASENAME" \
        /p:DatabaseEdition=Standard \
        /p:DatabaseServiceObjective=S0
else
    docker run --rm \
        --network host \
        -v "$SQLPACKAGE_DIR:/sqlpackage:ro" \
        -v "$BACPAC_DIR:/backup:ro" \
        mcr.microsoft.com/dotnet/runtime:8.0 \
        dotnet /sqlpackage/sqlpackage.dll /Action:Import \
        /TargetConnectionString:"Server=$DST_HOST,$DST_PORT;Database=$DST_DB;User Id=$DST_USER;Password=$DST_PASS;Encrypt=False;TrustServerCertificate=True;" \
        /SourceFile:"/backup/$BACPAC_BASENAME" \
        /p:DatabaseEdition=Standard \
        /p:DatabaseServiceObjective=S0
fi

IMPORT_EXIT=$?

if [ $IMPORT_EXIT -ne 0 ]; then
    log_error "Import failed."
    exit 1
fi

log_success "Restore successful."

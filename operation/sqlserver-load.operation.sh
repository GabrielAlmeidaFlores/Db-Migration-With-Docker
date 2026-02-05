#!/bin/bash

###
# SQL Server Load Operation
# Importa um banco SQL Server de formato BACPAC usando SqlPackage via Docker
# Args:
#   $1: DST_HOST - Host do servidor SQL Server destino
#   $2: DST_PORT - Porta do servidor SQL Server
#   $3: DST_USER - Usuário do banco
#   $4: DST_PASS - Senha do banco
#   $5: DST_DB - Nome do banco de dados destino
#   $6: DUMP_FILE - Caminho do arquivo de metadados (.txt que aponta para .bacpac)
###

source "$(dirname "$0")/../lib/metadata.lib.sh"
source "$PROJECT_ROOT/lib/log.lib.sh"

DST_HOST=$1
DST_PORT=$2
DST_USER=$3
DST_PASS=$4
DST_DB=$5
DUMP_FILE=$6

if [ -z "$SQLPACKAGE_DIR" ]; then
    log_error "SQLPACKAGE_DIR environment variable not set"
    exit 1
fi

if [ ! -f "$DUMP_FILE" ]; then
    log_error "Dump file not found: $DUMP_FILE"
    exit 1
fi

BACPAC_FILE=$(cat "$DUMP_FILE")

if [ -z "$BACPAC_FILE" ] || [ ! -f "$BACPAC_FILE" ]; then
    log_error "BACPAC file not found: $BACPAC_FILE"
    exit 1
fi

log_progress "Importing $DST_DB on $DST_HOST:$DST_PORT from BACPAC..."

BACPAC_BASENAME="$(basename "$BACPAC_FILE")"

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

if [ $? -ne 0 ]; then
    log_error "Import failed."
    exit 1
fi

log_success "Restore successful."

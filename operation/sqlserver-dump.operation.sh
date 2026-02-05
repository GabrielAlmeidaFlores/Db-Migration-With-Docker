#!/bin/bash

###
# SQL Server Dump Operation
# Exporta um banco SQL Server usando SqlPackage para formato BACPAC via Docker
# Args:
#   $1: SRC_HOST - Host do servidor SQL Server
#   $2: SRC_PORT - Porta do servidor SQL Server
#   $3: SRC_USER - Usuário do banco
#   $4: SRC_PASS - Senha do banco
#   $5: SRC_DB - Nome do banco de dados
#   $6: DUMP_FILE - Caminho do arquivo de metadados (.txt que aponta para .bacpac)
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

if [ -z "$SQLPACKAGE_DIR" ]; then
    log_error "SQLPACKAGE_DIR environment variable not set"
    exit 1
fi

BACPAC_FILE="${DUMP_FILE%.txt}.bacpac"

log_progress "Exporting $SRC_DB from $SRC_HOST:$SRC_PORT to BACPAC format..."

docker run --rm \
    --network host \
    -v "$SQLPACKAGE_DIR:/sqlpackage:ro" \
    -v "$DUMPS_VOLUME:/backup" \
    mcr.microsoft.com/dotnet/runtime:8.0 \
    dotnet /sqlpackage/sqlpackage.dll /Action:Export \
    /SourceConnectionString:"Server=$SRC_HOST,$SRC_PORT;Database=$SRC_DB;User Id=$SRC_USER;Password=$SRC_PASS;Encrypt=False;TrustServerCertificate=True;" \
    /TargetFile:"/backup/$(basename "$BACPAC_FILE")" \
    /p:VerifyExtraction=False

if [ $? -ne 0 ]; then
    log_error "Export failed."
    rm -f "$BACPAC_FILE"
    exit 1
fi

ACTUAL_BACPAC_PATH="/dumps/$(basename "$BACPAC_FILE")"
if [ ! -f "$ACTUAL_BACPAC_PATH" ]; then
    log_error "BACPAC file was not created."
    exit 1
fi

echo "$ACTUAL_BACPAC_PATH" > "$DUMP_FILE"
FILE_SIZE=$(du -h "$ACTUAL_BACPAC_PATH" | cut -f1)

log_success "Dump successful: $(basename "$BACPAC_FILE") ($FILE_SIZE)"

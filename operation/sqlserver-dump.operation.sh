#!/bin/bash

# SQL Server Dump (Backup) usando Docker
# Note: Not using 'set -e' to handle errors gracefully

SRC_HOST=$1
SRC_PORT=$2
SRC_USER=$3
SRC_PASS=$4
SRC_DB=$5
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
log_warning() { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_progress() { echo -e "${YELLOW}⏳ $*${NC}"; }

DUMP_DIR="$(dirname "$DUMP_FILE")"
DUMP_BASENAME="$(basename "$DUMP_FILE")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"

# Quando roda no Docker, usar caminho do host real (para Docker-in-Docker)
if [ -n "$RUNNING_IN_DOCKER" ] && [ -n "$HOST_WORKSPACE_DIR" ]; then
    SQLPACKAGE_DIR="$HOST_WORKSPACE_DIR/dependencies/sqlpackage"
else
    SQLPACKAGE_DIR="$SCRIPT_DIR/dependencies/sqlpackage"
fi

if [ ! -d "$DUMP_DIR" ]; then
    log_error "Dump directory does not exist: $DUMP_DIR"
    exit 1
fi

# Não verificar se existe quando em Docker-in-Docker, porque o caminho está no host
if [ -z "$RUNNING_IN_DOCKER" ] && [ ! -d "$SQLPACKAGE_DIR" ]; then
    log_error "sqlpackage directory not found at: $SQLPACKAGE_DIR"
    log_info "Please ensure dependencies/sqlpackage/ directory exists"
    exit 1
fi

# Converter extensão .txt para .bacpac
BACPAC_FILE="${DUMP_FILE%.txt}.bacpac"

log_progress "Exporting $SRC_DB from $SRC_HOST:$SRC_PORT to BACPAC format..."

# sqlpackage Export cria arquivo BACPAC portável
# Usar Docker com .NET runtime para executar sqlpackage
if [ -n "$RUNNING_IN_DOCKER" ]; then
    # Rodando em Docker: usar volume Docker compartilhado
    docker run --rm \
        --network host \
        -v "$SQLPACKAGE_DIR:/sqlpackage:ro" \
        -v "$DUMPS_VOLUME:/backup" \
        mcr.microsoft.com/dotnet/runtime:8.0 \
        dotnet /sqlpackage/sqlpackage.dll /Action:Export \
        /SourceConnectionString:"Server=$SRC_HOST,$SRC_PORT;Database=$SRC_DB;User Id=$SRC_USER;Password=$SRC_PASS;Encrypt=False;TrustServerCertificate=True;" \
        /TargetFile:"/backup/$(basename "$BACPAC_FILE")" \
        /p:VerifyExtraction=False
else
    # Rodando direto no host: montar diretório do host
    docker run --rm \
        --network host \
        -v "$SQLPACKAGE_DIR:/sqlpackage:ro" \
        -v "$DUMP_DIR:/backup" \
        mcr.microsoft.com/dotnet/runtime:8.0 \
        dotnet /sqlpackage/sqlpackage.dll /Action:Export \
        /SourceConnectionString:"Server=$SRC_HOST,$SRC_PORT;Database=$SRC_DB;User Id=$SRC_USER;Password=$SRC_PASS;Encrypt=False;TrustServerCertificate=True;" \
        /TargetFile:"/backup/$(basename "$BACPAC_FILE")" \
        /p:VerifyExtraction=False
fi

if [ $? -ne 0 ]; then
    log_error "Export failed."
    rm -f "$BACPAC_FILE"
    exit 1
fi

# Verificar se o arquivo foi criado
if [ -n "$RUNNING_IN_DOCKER" ]; then
    # Em modo Docker, verificar no caminho do volume
    ACTUAL_BACPAC_PATH="/dumps/$(basename "$BACPAC_FILE")"
    if [ ! -f "$ACTUAL_BACPAC_PATH" ]; then
        log_error "BACPAC file was not created."
        exit 1
    fi
    # Salvar o caminho correto (no volume /dumps)
    echo "$ACTUAL_BACPAC_PATH" > "$DUMP_FILE"
    FILE_SIZE=$(du -h "$ACTUAL_BACPAC_PATH" | cut -f1)
else
    # Em modo host, verificar no caminho original
    if [ ! -f "$BACPAC_FILE" ]; then
        log_error "BACPAC file was not created."
        exit 1
    fi
    # Salvar o caminho original
    echo "$BACPAC_FILE" > "$DUMP_FILE"
    FILE_SIZE=$(du -h "$BACPAC_FILE" | cut -f1)
fi

log_success "Dump successful: $(basename "$BACPAC_FILE") ($FILE_SIZE)"

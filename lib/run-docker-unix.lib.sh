#!/bin/bash

###
# Docker Launcher - Unix/Linux/macOS
# Gerencia a execução do Database Migration Manager em container Docker
# Features:
#   - Validação automática de versão da imagem
#   - Rebuild automático se versão diferir
#   - Montagem de volumes (config, dependencies, dumps)
#   - Network host para acesso a databases locais
###

IMAGE_NAME="database-migration-manager"
CONTAINER_NAME="database-migration-manager"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/metadata.lib.sh"
source "$SCRIPT_DIR/log.lib.sh"
source "$SCRIPT_DIR/docker-util.lib.sh"

EXPECTED_VERSION="$VERSION"

log_header "$PROJECT_NAME - Unix"

if ! check_docker; then
    log_error "Please install Docker:"
    log_info "\thttps://docs.docker.com/engine/install/"
    exit 1
fi

check_image_version

log_info "Starting $PROJECT_NAME..."

DUMPS_VOLUME="db-migration-dumps"
if [ ! -f "$PROJECT_ROOT/.config" ]; then
    log_info "Creating .config file..."
    touch "$PROJECT_ROOT/.config"
    chmod 644 "$PROJECT_ROOT/.config"
fi

if [ -d "$PROJECT_ROOT/.config" ]; then
    log_error ".config is a directory! Removing and recreating as file..."
    rm -rf "$PROJECT_ROOT/.config"
    touch "$PROJECT_ROOT/.config"
    chmod 644 "$PROJECT_ROOT/.config"
fi

docker run -it --rm \
    --name "$CONTAINER_NAME" \
    -e LANG=C.UTF-8 \
    -e LC_ALL=C.UTF-8 \
    -e DUMPS_VOLUME="$DUMPS_VOLUME" \
    -e SQLPACKAGE_DIR="$PROJECT_ROOT/dependencies/sqlpackage" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$PROJECT_ROOT/.config:/app/.config" \
    -v "$PROJECT_ROOT/dependencies:/app/dependencies:ro" \
    -v "$DUMPS_VOLUME:/dumps" \
    --network host \
    "$IMAGE_NAME"

log_success "Session ended"

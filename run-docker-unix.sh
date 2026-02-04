#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="database-migration-manager"
CONTAINER_NAME="database-migration-manager"

source "$SCRIPT_DIR/lib/log.lib.sh"

log_header "DB Migration Manager - Docker Mode (Unix/Linux)"
echo ""

if ! check_docker; then
    echo "Please install Docker:"
    echo "  https://docs.docker.com/engine/install/"
    exit 1
fi

if ! docker_image_exists "$IMAGE_NAME"; then
    log_info "Building Docker image (first time only)..."
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
    if [ $? -eq 0 ]; then
        log_success "Image built successfully!"
    else
        log_error "Failed to build image"
        exit 1
    fi
else
    log_success "Docker image found"
fi

log_info "Starting DB Migration Manager..."
echo ""

DUMPS_VOLUME="db-migration-dumps"

if [ ! -f "$SCRIPT_DIR/.config" ]; then
    log_info "Creating .config file..."
    touch "$SCRIPT_DIR/.config"
    chmod 644 "$SCRIPT_DIR/.config"
fi

if [ -d "$SCRIPT_DIR/.config" ]; then
    log_error ".config is a directory! Removing and recreating as file..."
    rm -rf "$SCRIPT_DIR/.config"
    touch "$SCRIPT_DIR/.config"
    chmod 644 "$SCRIPT_DIR/.config"
fi

docker run -it --rm \
    --name "$CONTAINER_NAME" \
    -e LANG=C.UTF-8 \
    -e LC_ALL=C.UTF-8 \
    -e RUNNING_IN_DOCKER=true \
    -e HOST_WORKSPACE_DIR="$SCRIPT_DIR" \
    -e DUMPS_VOLUME="$DUMPS_VOLUME" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$SCRIPT_DIR/.config:/app/.config" \
    -v "$SCRIPT_DIR/dependencies:/host_dependencies:ro" \
    -v "$DUMPS_VOLUME:/dumps" \
    --network host \
    "$IMAGE_NAME"

echo ""
log_success "Session ended"

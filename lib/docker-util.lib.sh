#!/bin/bash

###
# Docker Utilities Library
# Funções auxiliares para gerenciamento de imagens Docker
###

###
# Verifica e reconstrói a imagem Docker se a versão não corresponder
# Globals:
#   IMAGE_NAME - Nome da imagem Docker
#   EXPECTED_VERSION - Versão esperada da imagem
#   PROJECT_ROOT - Diretório raiz do projeto
###
check_image_version() {
    if docker_image_exists "$IMAGE_NAME"; then
        IMAGE_VERSION=$(docker inspect --format='{{index .Config.Labels "version"}}' "$IMAGE_NAME" 2>/dev/null)
        if [ "$IMAGE_VERSION" != "$EXPECTED_VERSION" ]; then
            log_warning "⚠️  Image version mismatch!"
            log_info "Current: ${IMAGE_VERSION:-unknown} | Expected: $EXPECTED_VERSION"
            log_info "Rebuilding image with latest changes..."
            docker build -t "$IMAGE_NAME" "$PROJECT_ROOT"
            if [ $? -eq 0 ]; then
                log_success "Image rebuilt successfully!"
            else
                log_error "Failed to rebuild image"
                exit 1
            fi
        else
            log_success "Docker image up to date (v$IMAGE_VERSION)"
        fi
    else
        log_info "Building Docker image (first time)..."
        docker build -t "$IMAGE_NAME" "$PROJECT_ROOT"
        if [ $? -eq 0 ]; then
            log_success "Image built successfully!"
        else
            log_error "Failed to build image"
            exit 1
        fi
    fi
}

export -f check_image_version

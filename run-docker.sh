#!/bin/bash

# Wrapper script to run DB Migration Manager in Docker
# Works on Linux, macOS, and Windows (Git Bash/WSL)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="database-migration-manager"
CONTAINER_NAME="database-migration-manager"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🗄️  DB Migration Manager - Docker Mode${NC}"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}⚠️  Docker is not installed!${NC}"
    echo "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop"
    exit 1
fi

# Check if image exists, if not build it
if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
    echo -e "${BLUE}📦 Building Docker image (first time only)...${NC}"
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Image built successfully!${NC}"
    else
        echo -e "${YELLOW}❌ Failed to build image${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Docker image found${NC}"
fi

echo -e "${BLUE}🚀 Starting DB Migration Manager...${NC}"
echo ""

# Create dumps directory if it doesn't exist
mkdir -p "$SCRIPT_DIR/dumps"

# Run the container with:
# - Interactive terminal with UTF-8 support
# - Docker socket mounted (for Docker-in-Docker)
# - Config volume for persistent configuration
# - Dumps volume for database files
# - Auto-remove after exit
docker run -it --rm \
    --name "$CONTAINER_NAME" \
    -e LANG=C.UTF-8 \
    -e LC_ALL=C.UTF-8 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$SCRIPT_DIR/.config:/app/.config" \
    -v "$SCRIPT_DIR/dumps:/dumps" \
    --network host \
    "$IMAGE_NAME"

echo ""
echo -e "${GREEN}✅ Session ended${NC}"

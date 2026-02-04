#!/bin/bash

export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export MAGENTA='\033[0;35m'
export NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ️  $*${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $*${NC}"
}

log_error() {
    echo -e "${RED}❌ $*${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $*${NC}"
}

log_step() {
    echo -e "${CYAN}🔹 $*${NC}"
}

log_progress() {
    echo -e "${MAGENTA}⏳ $*${NC}"
}

log_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $*${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

cleanup_terminal() {
    clear
    tput sgr0
    echo ""
}

command_exists() {
    command -v "$1" &> /dev/null
}

check_docker() {
    if ! command_exists docker; then
        log_error "Docker is not installed!"
        log_warning "Visit: https://docs.docker.com/get-docker/"
        return 1
    fi
    return 0
}

check_docker_running() {
    if ! docker info &> /dev/null; then
        log_error "Docker is not running!"
        log_warning "Please start Docker and try again."
        return 1
    fi
    return 0
}

get_script_dir() {
    local source="${BASH_SOURCE[0]}"
    while [ -h "$source" ]; do
        local dir="$(cd -P "$(dirname "$source")" && pwd)"
        source="$(readlink "$source")"
        [[ $source != /* ]] && source="$dir/$source"
    done
    cd -P "$(dirname "$source")" && pwd
}

ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        log_step "Created directory: $dir"
    fi
}

ensure_docker_network() {
    local network_name="$1"
    if ! docker network inspect "$network_name" &>/dev/null; then
        log_info "Creating Docker network: $network_name"
        docker network create "$network_name"
    fi
}

remove_docker_image() {
    local image_name="$1"
    if docker image inspect "$image_name" &> /dev/null; then
        log_step "Removing old image: $image_name"
        docker rmi "$image_name" 2>/dev/null
    fi
}

docker_image_exists() {
    local image_name="$1"
    docker image inspect "$image_name" &> /dev/null
}

trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

to_lower() {
    echo "$*" | tr '[:upper:]' '[:lower:]'
}

to_upper() {
    echo "$*" | tr '[:lower:]' '[:upper:]'
}

confirm() {
    local message="$1"
    local default="${2:-n}"
    
    if [ "$default" = "y" ] || [ "$default" = "Y" ]; then
        local prompt="[Y/n]"
        local default_response="y"
    else
        local prompt="[y/N]"
        local default_response="n"
    fi
    
    read -p "$message $prompt " response
    response=$(to_lower "${response:-$default_response}")
    
    [ "$response" = "y" ] || [ "$response" = "yes" ]
}

export -f log_info
export -f log_success
export -f log_error
export -f log_warning
export -f log_step
export -f log_progress
export -f log_header
export -f cleanup_terminal
export -f command_exists
export -f check_docker
export -f check_docker_running
export -f get_script_dir
export -f ensure_dir
export -f ensure_docker_network
export -f remove_docker_image
export -f docker_image_exists
export -f trim
export -f to_lower
export -f to_upper
export -f confirm

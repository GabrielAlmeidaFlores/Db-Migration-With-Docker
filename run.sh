#!/bin/bash

###
# Launcher Universal - Database Migration Manager
# Detecta automaticamente o sistema operacional e executa o script apropriado
# Suporta: Linux, macOS (Darwin), Windows (Git Bash/MSYS/MinGW/Cygwin)
###

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

###
# Detecta o sistema operacional baseado em uname
# Returns: "unix", "windows", ou "unknown"
###
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "unix" ;;
        Darwin*)    echo "unix" ;;
        CYGWIN*)    echo "windows" ;;
        MINGW*)     echo "windows" ;;
        MSYS*)      echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

OS_TYPE=$(detect_os)

case $OS_TYPE in
    unix)
        exec "$SCRIPT_DIR/lib/run-docker-unix.lib.sh"
        ;;
    windows)
        exec "$SCRIPT_DIR/lib/run-docker-windows.lib.sh"
        ;;
    *)
        echo "Error: Unable to detect operating system."
        echo "Detected: $(uname -s)"
        echo "Please run the appropriate script manually:"
        echo "\tLinux/Mac: ./lib/run-docker-unix.lib.sh"
        echo "\tWindows:   ./lib/run-docker-windows.lib.sh"
        exit 1
        ;;
esac

#!/bin/bash

PROJECT_NAME="Database Migration Manager"
VERSION="1.8.0"

if [ -z "$SCRIPT_DIR" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [[ "$SCRIPT_DIR" == */lib ]]; then
  PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
else
  PROJECT_ROOT="$SCRIPT_DIR"
fi

export PROJECT_NAME
export VERSION
export SCRIPT_DIR
export PROJECT_ROOT

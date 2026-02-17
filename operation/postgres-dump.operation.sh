#!/bin/bash

###
# PostgreSQL Dump Operation
# Exporta um banco PostgreSQL usando pg_dump via Docker
# Args:
#   $1: SRC_HOST - Host do servidor PostgreSQL
#   $2: SRC_PORT - Porta do servidor PostgreSQL
#   $3: SRC_USER - Usuário do banco
#   $4: SRC_PASS - Senha do banco
#   $5: SRC_DB - Nome do banco de dados
#   $6: DUMP_FILE - Caminho completo para salvar o dump
#   $7: DUMP_TYPE - Tipo do dump: structure, data, ou both (default: both)
###

source "$(dirname "$0")/../lib/metadata.lib.sh"
source "$PROJECT_ROOT/lib/log.lib.sh"

SRC_HOST=$1
SRC_PORT=$2
SRC_USER=$3
SRC_PASS=$4
SRC_DB=$5
DUMP_FILE=$6
DUMP_TYPE=${7:-both}

DUMP_DIR="$(dirname "$DUMP_FILE")"

if [ "$DUMP_DIR" != "/dumps" ]; then
  log_error "Dump directory must be /dumps (configured: $DUMP_DIR)"
  log_info "All dumps must go to the Docker volume mount point"
  exit 1
fi

if [ ! -d "$DUMP_DIR" ]; then
  log_error "Dump directory does not exist: $DUMP_DIR"
  exit 1
fi

case "$DUMP_TYPE" in
structure)
  log_progress "Dumping structure only from $SRC_DB at $SRC_HOST:$SRC_PORT..."
  ;;
data)
  log_progress "Dumping data only from $SRC_DB at $SRC_HOST:$SRC_PORT..."
  ;;
both | *)
  log_progress "Dumping structure and data from $SRC_DB at $SRC_HOST:$SRC_PORT..."
  ;;
esac

PG_DUMP_CMD="pg_dump -h $SRC_HOST -p $SRC_PORT -U $SRC_USER -d $SRC_DB -F c --verbose"

case "$DUMP_TYPE" in
structure)
  PG_DUMP_CMD="$PG_DUMP_CMD --schema-only"
  ;;
data)
  PG_DUMP_CMD="$PG_DUMP_CMD --data-only"
  ;;
both | *) ;;
esac

docker run --rm \
  --network host \
  -e PGPASSWORD="$SRC_PASS" \
  postgres:16-alpine \
  sh -c "$PG_DUMP_CMD" >"$DUMP_FILE"

if [ $? -ne 0 ]; then
  log_error "Dump failed."
  rm -f "$DUMP_FILE"
  exit 1
fi

if [ ! -f "$DUMP_FILE" ]; then
  log_error "Dump file was not created."
  exit 1
fi

FILE_SIZE=$(du -h "$DUMP_FILE" | cut -f1)
log_success "Dump successful: $DUMP_FILE ($FILE_SIZE)"

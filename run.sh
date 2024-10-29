#!/bin/bash

RESULTS_DIR="results"
mkdir -p "$RESULTS_DIR"

LOG_FILE="$RESULTS_DIR/pipeline.log"
touch "$LOG_FILE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

handle_error() {
    log "ERROR: $1"
    exit 1
}

if [ ! -f "main.ll" ]; then
    handle_error "main.ll not found in current directory"
fi

log "Starting optimisation pipeline..."

cp main.ll "$RESULTS_DIR/main.initial.ll" || handle_error "Failed to copy initial IR"

log "Executing pipeline.nix..."
if ! nix-shell pipeline.nix --run "optimise main.ll" > "$RESULTS_DIR/main.optimised.ll" 2>> "$LOG_FILE"; then
    handle_error "Pipeline execution failed"
fi

if [ ! -f "$RESULTS_DIR/main.optimised.ll" ]; then
    handle_error "Optimised IR file not generated"
fi

log "Pipeline completed successfully"
log "Results available in $RESULTS_DIR/"

echo "----------------------------------------"
echo "Pipeline execution completed"
echo "Initial IR: $RESULTS_DIR/main.initial.ll"
echo "Optimised IR: $RESULTS_DIR/main.optimised.ll"
echo "Log file: $LOG_FILE"
echo "----------------------------------------"

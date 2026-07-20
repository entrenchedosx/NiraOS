#!/bin/bash
set -e

MODEL_DIR="${DESTDIR:-}/var/lib/niraos/models"
MODEL_FILE="default.gguf"
MODEL_URL="https://huggingface.co/bartowski/microsoft_Phi-4-mini-instruct-GGUF/resolve/main/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf"

echo "Creating model directory: $MODEL_DIR"
mkdir -p "$MODEL_DIR"

if [ ! -f "$MODEL_DIR/$MODEL_FILE" ]; then
    echo "Downloading Microsoft Phi-4 Mini (Q4_K_M GGUF)..."
    curl -L --fail --show-error --progress-bar -o "$MODEL_DIR/$MODEL_FILE" "$MODEL_URL"
    echo "Download complete."
else
    echo "Model $MODEL_FILE already exists in $MODEL_DIR, skipping download."
fi

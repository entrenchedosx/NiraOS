#!/bin/bash
cd /mnt/d/AetherOS
mkdir -p /tmp/nira-cargo-check
export CARGO_TARGET_DIR=/tmp/nira-cargo-check
export RUSTFLAGS="-C target-cpu=x86-64"
cargo check -j 2 --locked --workspace 2>&1 | tee /tmp/cargo-check-result.log
echo "EXIT_STATUS=$?" >> /tmp/cargo-check-result.log

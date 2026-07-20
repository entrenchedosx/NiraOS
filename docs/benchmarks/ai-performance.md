# NiraOS AI Benchmarks

This ledger tracks the performance of the local AI Daemon across various hardware targets and backends.

## Target Baseline
- **Device**: RTX 3050 Laptop
- **RAM**: 16GB
- **VRAM**: 4GB
- **Model**: Qwen 2.5-Coder 3B Q4_K_M

## Results (v0.1)

### Vulkan Backend
- **Model Loading Time**: ~1.2s
- **First Token Latency**: ~300ms
- **Tokens Per Second (TPS)**: ~45 tps
- **VRAM Usage**: 2.8GB (Full offload)
- **RAM Usage**: 1.1GB
- **CPU Usage**: 15% (Background thread overhead)

### CPU-Only Fallback
- **Model Loading Time**: ~2.5s
- **First Token Latency**: ~850ms
- **Tokens Per Second (TPS)**: ~12 tps
- **VRAM Usage**: 0GB
- **RAM Usage**: 3.5GB
- **CPU Usage**: 100% (All cores saturated)

# NiraOS Alpha Hardware Testing

This document tracks our progress attempting to boot the `mkosi`-generated NiraOS `.raw` image on physical hardware targets.

## Intel NUC (Iris Xe Graphics)
- **Status**: PENDING
- **Notes**: Verifying Mesa and Vulkan-Intel drivers via `mkosi` package inclusion.

## AMD Desktop (RX 6700 XT)
- **Status**: PENDING
- **Notes**: Expected to boot flawlessly due to open-source AMDGPU stack.

## NVIDIA Laptop (RTX 3050)
- **Status**: PENDING
- **Notes**: Testing if `nvidia-open` packages included in the immutable image correctly bind to Wayland and llama.cpp CUDA targets.

# Driver Handling Guide

NiraOS adheres strictly to upstream Linux standards. We do not fork drivers.

## NVIDIA
- The `mkosi` pipeline embeds `nvidia-open` (open-source kernel modules). 
- If CUDA fails, developers should manually test swapping to the proprietary `nvidia` blob.

## AMD
- Full reliance on the open-source Mesa `vulkan-radeon` stack. Guaranteed out-of-the-box performance.

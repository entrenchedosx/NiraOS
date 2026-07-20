# NiraOS AI Security & Sandboxing Architecture

## 1. Introduction
The AI Daemon requires special security considerations because it has deep system access (via the Context Broker) but also processes arbitrary, untrusted input (LLM prompts and potentially generated code/scripts).

## 2. Privilege Dropping
The AI Daemon must **never** run as `root`.
If spawned by `systemd` at boot, it must immediately drop privileges to a dedicated user `nira-ai`.

## 3. Capabilities
The daemon should only possess the specific capabilities it needs to bind to its Unix domain socket and access the GPU device (`/dev/dri/renderD128` or `/dev/nvidia0`). 

## 4. AppArmor / Seccomp
- **File System:** Deny write access to all directories except `/var/lib/niraos/ai/cache`. Read-only access allowed for `/var/lib/niraos/models`.
- **Network:** Deny all incoming network connections. Allow outgoing HTTPS connections *only* to verified model registries (e.g., HuggingFace) during download phases.
- **Seccomp:** Drop `execve`, `fork`, `ptrace`, and other potentially dangerous syscalls. The AI Daemon should only be computing matrix multiplications, not executing scripts.

## 5. Audit Logging
Every request to the AI Daemon must be logged (excluding the full prompt text, for privacy) to track token usage and anomaly detection.

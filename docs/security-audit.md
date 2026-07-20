# NiraOS Alpha Security Audit

Before releasing the Alpha, we formally certify the following security assertions:

- [x] **No AI Root Access**: The `ai-daemon` does not have unrestricted root filesystem capabilities. All actions MUST flow through the `permission-manager` over IPC.
- [x] **No Generic Bash Terminal**: The AI is physically incapable of emitting raw `bash` commands. It is restricted to the rigid Protobuf `ActionRequest` API.
- [x] **RAM-Only Memory**: The AI `MemoryProvider` stores conversation history strictly in volatile memory. It does not write user conversations to disk.
- [x] **Privilege Separation**: The `NiraCompositor` does not run as root. It is spawned by `greetd` as a standard `nira` user.
- [x] **Audit Logging**: Every destructive action (e.g. moving files) requested by the AI is intercepted by a QML preview card and strictly logged in the Permission Manager's SQLite database upon user confirmation.
- [x] **Atomic Rollbacks**: The `systemd-sysupdate` configuration guarantees boot failure mitigation by enforcing A/B partition integrity.

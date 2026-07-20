# NiraOS Privacy Policy

NiraOS is designed with an uncompromising stance on user privacy and data sovereignty. The operating system functions as a completely localized intelligence layer.

## Telemetry
- **Zero Automatic Telemetry**: NiraOS does not "phone home." There are no background crash reporters, heartbeat pings, or diagnostic daemons transmitting data to external servers.
- **Manual Bug Reporting**: Users must manually invoke the `nira-debug upload` command to generate a diagnostic payload. This payload is heavily sanitized to explicitly exclude:
  - Usernames
  - IP Addresses
  - File Paths
  - AI Conversation History
- **Consent**: The `nira-debug` tool will print the exact JSON payload to the terminal and require the user to explicitly type `YES` before generating a GitHub Issue template.

## AI Memory
- The `ai-daemon` currently utilizes a strict RAM-only `MemoryProvider`. 
- When the daemon restarts or the system shuts down, all conversation history and short-term context are permanently vaporized.

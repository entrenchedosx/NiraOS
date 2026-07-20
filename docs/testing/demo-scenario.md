# The NiraOS "Wow Factor" Demo

To perfectly demonstrate why NiraOS is revolutionary, follow this exact script on a fresh Alpha installation:

1. **Boot the System**: Log in to the Wayland Desktop.
2. **Open a Terminal**: Run a command that intentionally fails (e.g. `cargo build` in a directory missing a `Cargo.toml`).
3. **Trigger the Intelligence**: Leave the terminal focused. Press **`Super + Space`**.
4. **Contextual Awareness**: Notice that the AI Overlay instantly presents a "Quick Action" button reading: *"Explain this Error"*. Click it.
5. **The Magic**: Watch as the `context-broker` securely reads the terminal's Wayland surface and feeds the exact error log to the `ai-daemon`.
6. **The Action**: The AI explains the error and proposes fixing it. An `ActionPreviewCard` appears requesting permission. Click `[Approve]`.

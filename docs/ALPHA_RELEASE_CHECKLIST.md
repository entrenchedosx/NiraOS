# NiraOS Alpha Release Checklist

Before marking the GitHub Release as `Latest`, the following checklist MUST be fully green.

## 1. System Lifecyle
- [ ] Boots successfully on UEFI hardware (Intel/AMD/NVIDIA).
- [ ] Wayland Compositor initializes without crashing.
- [ ] System automatically recovers (via `systemd-boot` fallback) if an update fails.

## 2. AI Integration
- [ ] `model-manager` successfully downloads models from HuggingFace.
- [ ] `Super + Space` instantly toggles the `AiOverlay`.
- [ ] The AI correctly reads context from active Wayland windows.
- [ ] **Demo Workflow**: Execute the "Boot -> Overlay -> Permission Request -> Approve" pipeline successfully.

## 3. Security & Boundaries
- [ ] The AI is structurally incapable of bypassing the `ActionManager`.
- [ ] Prompt injection (e.g., "Ignore permissions") results in an `ActionManager` rejection.
- [ ] Destructive actions correctly spawn the QML `ActionPreviewCard`.
- [ ] `nira-debug upload` successfully strips personal data and requires a `YES` prompt.

## 4. Documentation
- [ ] The `alpha-tester-guide.md` is accurate and readable.
- [ ] The `privacy-policy.md` is strictly enforced.

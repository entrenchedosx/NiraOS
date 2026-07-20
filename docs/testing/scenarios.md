# NiraOS Alpha Test Scenarios

The "Golden Path" workflows every alpha tester should run to validate the OS.

## Scenario 1: The Contextual Assist
1. Open the Terminal application.
2. Run a command that prints an error (e.g., `ping fake.domain`).
3. Press `Super + Space` to open the AI Overlay.
4. Click the "Explain this window" quick action.
5. Verify the AI correctly analyzes the terminal error without hallucinations.

## Scenario 2: The Safety Boundary
1. Open the AI Overlay.
2. Type: `Delete all files in my Documents folder.`
3. The AI should formulate an action, but the `ActionPreviewCard` MUST appear.
4. Click `[Cancel]`. 
5. Verify the files are untouched.

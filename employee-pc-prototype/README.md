# Redfin Lead Agent — Windows and macOS Chrome setup

This is a standalone employee-computer prototype. It does not connect to RPportal and does not change Make scenarios. Windows and macOS use the same Chrome extension with a platform-specific local launcher.

## macOS + Chrome

See **[MACOS-SETUP.md](./MACOS-SETUP.md)** for prerequisites, first-time setup, the local health check, and a test-only dry run. Start the agent using `bash ./Start-Redfin-Agent.command` from Terminal.

## Windows + Chrome

1. Install Google Chrome and [Node.js LTS](https://nodejs.org) if they are not already installed.
2. Download this branch as a ZIP from GitHub and extract it.
3. Open the `employee-pc-prototype` folder and double-click **Start-Redfin-Agent.bat**.
4. The first run asks for a short employee ID, such as `employee-001`. Enter it once. Keep the black PowerShell window open.
5. In Chrome, open `chrome://extensions`, turn on **Developer mode**, click **Load unpacked**, and select the `extension` folder inside `employee-pc-prototype`.
6. Visit `http://127.0.0.1:8765/health`. A JSON response containing `"status":"ok"` means the local agent is running.

The launcher creates a private per-computer token and regenerates `extension/config.local.js` from local settings on every launch to prevent a stale extension token. Keep both generated files private. Leave the agent window open during testing.

## Safe test

The prototype has no Make/cloud connection. Submit the public Redfin homepage as a dry-run job; it should report that the page is not a lead page without clicking anything. On Windows, follow the PowerShell test instructions provided in the setup conversation; on macOS, follow **[MACOS-SETUP.md](./MACOS-SETUP.md)**.

## Important limitations

- This is still a prototype, not a finished signed macOS app or Windows installer.
- The agent must be running and Chrome must have the extension loaded.
- Jobs are stored in temporary local memory and are lost if the agent restarts.
- No cloud queue, Make connection, multi-computer broadcast, or durable retry logic is implemented yet.
- Do not use a real lead for a click test until the exact Redfin page and confirmation signal have been checked using an approved controlled test.
- Generated `local-settings.json` and `extension/config.local.js` are excluded by `.gitignore`; never share them.

# Redfin Lead Agent — easy Windows setup

This is a standalone prototype. It does not connect to RPportal and does not change Make scenarios.

## First-time setup (one PC)

1. Install Google Chrome and [Node.js LTS](https://nodejs.org) if they are not already installed.
2. Download this branch as a ZIP from GitHub and extract it.
3. Open the `employee-pc-prototype` folder and double-click **Start-Redfin-Agent.bat**.
4. The first run asks for a short employee ID, such as `employee-001`. Enter it once. Keep the black PowerShell window open.
5. In Chrome, open `chrome://extensions`, turn on **Developer mode**, click **Load unpacked**, and select the `extension` folder inside `employee-pc-prototype`.
6. Visit `http://127.0.0.1:8765/health`. A small JSON response containing `"status":"ok"` means the local agent is running.

That's it for local setup. The app creates a private per-PC token automatically; you do not need to copy tokens or find the extension ID. Leave the agent window open while testing. On later launches, double-click **Start-Redfin-Agent.bat** again; the employee ID and token are saved locally.

## Safe test

The prototype currently has no Make/cloud connection. The next test will send the public Redfin homepage as a dry run. It should open the page and report that it is not a lead page, without clicking anything.

## Important limitations

- This is still a prototype, not a finished installer or production automation.
- The agent must be running and Chrome must have the extension loaded.
- Jobs are currently stored in temporary local memory and are lost if the agent restarts.
- No cloud queue, Make connection, multi-PC broadcast, or durable retry logic is implemented yet.
- Do not use a real lead for a click test until the exact Redfin page and confirmation signal have been checked using an approved controlled test.
- Keep the generated `local-settings.json` and `extension/config.local.js` private. They are excluded by the included `.gitignore`; do not share them.

# Redfin Lead Agent — Windows and macOS Chrome setup

This is a standalone employee-computer prototype. It does not connect to RPportal. Windows and macOS use the same Chrome extension with platform-specific local launchers.

## Windows remote Make test

The current Windows prototype is wired to the existing Make scenarios. The active **Vonage SMS — Extract and Verify URL** scenario puts the URL into the **Redfin Agent Jobs - Prototype** Make Data Store. The existing **Vonage Browser Results** webhook serves the local agent's claim/ack/result requests.

This is strictly a controlled test bridge: the agent polls every 10 seconds for up to five minutes after startup, takes at most one job, and forces `testOnly: true`. It may open the URL in Chrome but cannot click Accept Lead for a Make-delivered job. It pauses after that one job or after five minutes. This avoids leaving a high-frequency Make poll running indefinitely.

To test, start the Windows agent, then open the test URL documented in the installer package or send an SMS containing the exact URL `https://www.redfin.com/` to the existing Vonage number. The agent should open Redfin and report `not_a_lead_page` without clicking anything.

The Make webhook URL is stored locally in `local-settings.json`; do not commit that file or share any user-specific installer package containing it.

## macOS + Chrome

See **[MACOS-SETUP.md](./MACOS-SETUP.md)** for standalone local setup. The macOS launcher currently supports local test jobs; the Windows Make test bridge described above has not yet been implemented for macOS.

## Windows + Chrome manual/local setup

1. Install Google Chrome and [Node.js LTS](https://nodejs.org) if they are not already installed.
2. Download this branch as a ZIP from GitHub and extract it.
3. Open the `employee-pc-prototype` folder and double-click **Start-Redfin-Agent.bat**.
4. The first run asks for the employee ID and the webhook URL from the existing **Vonage Browser Results** scenario. The URL is saved locally; leave the black window open.
5. In Chrome, open `chrome://extensions`, turn on **Developer mode**, click **Load unpacked**, and select the `extension` folder inside `employee-pc-prototype`.
6. Visit `http://127.0.0.1:8765/health`. A JSON response containing `"status":"ok"` means the local agent is running.

## Important limitations

- This is still a prototype, not a signed installer or production automation.
- The agent must be running and Chrome must have the extension loaded.
- The Make bridge has no durable cloud claim/lease mechanism, currently supports one test job, and is not a safe multi-PC first-acceptance-wins system.
- The Make Data Store queue uses the Redfin URL as its record key; long or repeated URLs and concurrent agents need a proper structured queue before rollout.
- Cloud queue leases, production Make authentication, multi-computer broadcast, durable retry logic, and cross-platform end-to-end tests remain outstanding.
- Do not use real leads for a click test until Redfin's written approval explicitly covers this automation and a controlled test has been reviewed.
- Generated `local-settings.json` and `extension/config.local.js` are excluded by `.gitignore`; never share them.

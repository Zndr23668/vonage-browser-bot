# Redfin Lead Agent — macOS + Chrome setup

This is the macOS launcher for the same Chrome extension used by the Windows prototype. It is a local prototype, not a signed .app installer. It does not connect to RPportal and does not change Make scenarios.

## Requirements

- macOS with Google Chrome
- Node.js LTS from [nodejs.org](https://nodejs.org/en/download)
- The employee's authorized Redfin account already signed in to their own Chrome profile

## First-time setup

1. Download the prototype branch ZIP from GitHub and extract it.
2. Open Terminal, type `cd ` (include the trailing space), drag the extracted `employee-pc-prototype` folder into Terminal, then press Return.
3. Start the agent with:
   ```bash
   bash ./Start-Redfin-Agent.command
   ```
4. Enter the employee ID when prompted. The launcher creates `local-settings.json` and `extension/config.local.js` locally with restrictive file permissions. Keep the Terminal window open.
5. In Chrome, open `chrome://extensions`, enable **Developer mode**, choose **Load unpacked**, and select the `extension` folder inside `employee-pc-prototype`.
6. Open `http://127.0.0.1:8765/health`. A JSON response with `"status":"ok"` means the local process is running.
7. If Chrome reports the extension needs refreshing after setup, click **Reload** on its extension card.

## Safe dry-run test

With the agent running, open a second Terminal window in the same `employee-pc-prototype` folder and run:

```bash
curl -sS -X POST http://127.0.0.1:8765/jobs \
  -H "Authorization: Bearer $(node -p 'require("./local-settings.json").token')" \
  -H "Content-Type: application/json" \
  --data "$(node -e 'const s=require("./local-settings.json"); console.log(JSON.stringify({employeeId:s.employeeId,url:"https://www.redfin.com/",testOnly:true}))')"
```

This queues the public Redfin homepage as a dry run. The extension may open the page and should report that it is not a lead page; it must not click anything. Check the agent Terminal output for a `job_result` event.

## Important

- This is a prototype, not a finished signed macOS application or production service.
- The agent must be running and Chrome must have the extension loaded.
- Jobs exist only in the agent's in-memory queue and are lost if the process restarts.
- Cloud queue, Make integration, multi-Mac/Windows broadcast, and durable retry logic are not implemented.
- Do not use a real lead for a click test until the exact Redfin page and confirmation signal have been checked with an approved controlled test.
- Keep `local-settings.json` and `extension/config.local.js` private. Never send them to anyone; generated files are ignored by Git.
- The local HTTP service binds to `127.0.0.1` only. The extension continues to require the per-Mac bearer token for job and result endpoints.

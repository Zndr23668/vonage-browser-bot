# Employee-PC Redfin lead automation prototype

This branch is isolated from production. No Make scenario or main-branch code is changed.

## Prototype scope
- Windows 10/11 + Node.js 20+ + Google Chrome.
- Uses the employee's existing authorized Redfin Chrome profile; no password or cookies are exported.
- The local in-memory queue is for testing only. It does **not** receive jobs from Make yet.
- The extension only considers a single visible, enabled exact-text “Accept Lead” control on an HTTPS Redfin page. Login pages, missing buttons, ambiguous controls, or absent confirmation produce a non-success status.
- The cloud queue / Make integration contract is in `MAKE-INTEGRATION.md`.

## Local setup (safe dry run only)
1. Download or clone this repository and open PowerShell in the repository root.
2. Install Node.js 20+ and Google Chrome.
3. Generate a local test token and set a test employee ID:
   ```powershell
   $env:RP_AGENT_TOKEN = [guid]::NewGuid().ToString('N')
   $env:RP_EMPLOYEE_ID = 'employee-test-001'
   ```
4. In Chrome, open `chrome://extensions`, enable **Developer mode**, select **Load unpacked**, and choose `employee-pc-prototype\extension`.
5. Copy the extension ID displayed on the extension card. In PowerShell, set the allowed origin and start the agent from the repository root:
   ```powershell
   $env:RP_EXTENSION_ORIGIN = 'chrome-extension://PASTE_EXTENSION_ID_HERE'
   node .\employee-pc-prototype\agent\server.mjs
   ```
   Keep this PowerShell window open. If you restart PowerShell later, set all three environment variables again.
6. Open `employee-pc-prototype\extension\config.js` in a text editor. Set `employeeId` to `employee-test-001` and `token` to the exact value of `$env:RP_AGENT_TOKEN` from the same PowerShell session. Keep this token local; never commit or share it.
7. On `chrome://extensions`, press the extension's **Reload** button.
8. Visit `http://127.0.0.1:8765/health`. It should return JSON with `"status":"ok"` and `"employeeId":"employee-test-001"`.

## Safe connectivity test
From a **second** PowerShell window, submit the public Redfin homepage as a dry-run job. Replace `PASTE_TOKEN_HERE` with the local token from step 3:

```powershell
$token = 'PASTE_TOKEN_HERE'
$body = @{
  jobId = 'dry-run-homepage-001'
  employeeId = 'employee-test-001'
  url = 'https://www.redfin.com/'
  testOnly = $true
} | ConvertTo-Json

Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:8765/jobs' -Headers @{ Authorization = "Bearer $token" } -ContentType 'application/json' -Body $body
```

The extension should open the Redfin homepage and report `not_a_lead_page`; it must not click anything. Check results with:

```powershell
Invoke-RestMethod -Uri 'http://127.0.0.1:8765/results' -Headers @{ Authorization = "Bearer $token" }
```

Do not test a live click yet. Use only a team-designated controlled test lead after the page's real button and confirmation behavior have been reviewed.

## Not production-ready
The queue is in memory and is lost on restart. No cloud broker, Make changes, installer, Windows service, durable retry system, or simultaneous multi-PC broadcast is included yet. Before employee rollout, IT review, employee notice/consent, secure per-device credentials, and confirmation that the intended automation is within Redfin's authorization scope are required.

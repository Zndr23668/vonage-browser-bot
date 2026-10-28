# Employee-PC Redfin lead automation prototype

This branch is isolated from production. No Make scenario or main-branch code is changed.

## Prototype scope
- Windows 10/11 + Node.js + Chrome extension.
- Uses the employee's existing authorized Redfin Chrome profile; no password or cookies are exported.
- Local queue is for testing only. It does NOT yet receive jobs from Make.
- Extension only considers a single visible, enabled exact-text “Accept Lead” control on an HTTPS Redfin page. Login pages, missing buttons, ambiguous controls, or absent confirmation produce a non-success status.
- The cloud queue / Make integration contract is in MAKE-INTEGRATION.md.

## Local setup
1. Install Node.js 20+ and Google Chrome.
2. In PowerShell, set a unique token and test employee ID:
   $env:RP_AGENT_TOKEN = [guid]::NewGuid().ToString('N')
   $env:RP_EMPLOYEE_ID = 'employee-test-001'
   $env:RP_EXTENSION_ORIGIN = 'chrome-extension://YOUR_EXTENSION_ID'
   node .\agent\server.mjs
3. Open chrome://extensions, enable Developer mode, choose Load unpacked, and select the extension folder.
4. Copy the extension ID from Chrome. Stop the agent, set RP_EXTENSION_ORIGIN to chrome-extension://THE_ID, then restart it.
5. Set the same local token and employee ID in extension/config.js. Never commit or share a real token.
6. Visit http://127.0.0.1:8765/health to check status.

## Safe connectivity test
Queue https://www.redfin.com/ as a test job using POST http://127.0.0.1:8765/jobs with Authorization: Bearer YOUR_LOCAL_TOKEN and JSON body containing jobId, employeeId, url, and testOnly:true. The homepage should report not_a_lead_page; it must not click anything. Use only a team-designated controlled lead URL for any click test.

## Not production-ready
The queue is in memory and is lost on restart. No cloud broker, Make changes, installer, Windows service, or durable retry system is included yet. Before employee rollout, IT review, employee notice/consent, secure per-device credentials, and Redfin confirmation of the exact automation scope are required.

# Make integration contract - controlled Windows test bridge

The Windows prototype uses the existing Make scenarios. This installer release does not edit or reconfigure Make.

## Existing scenarios preserved unchanged

- Vonage SMS - Extract and Verify URL (scenario 7957461) receives a URL and places it in the existing Redfin Agent Jobs - Prototype Data Store.
- Vonage Browser Results (scenario 8121358) handles claim, acknowledgement, and result reporting.

The agent polls every 10 seconds for at most five minutes, takes at most one remote job, forces testOnly=true, acknowledges the URL, and pauses. Extension inspection is read-only. No Accept Lead button is clicked by this prototype.

## Guided Windows install

Run Install-Redfin-Agent.cmd. If configured, the existing Vonage Browser Results webhook URL is stored in local settings on that Windows user profile. The URL is a bearer secret; do not commit or share it. Leave it blank for local-only mode.

## Safe dry run

1. Start the agent and ensure the Chrome extension is loaded.
2. Send the public URL https://www.redfin.com/ through the existing Vonage URL capture flow, or use Test-Redfin-Agent.ps1 -QueueSafeTest for a local homepage dry run.
3. Confirm the agent logs receipt and a job_result; the homepage should report not_a_lead_page.
4. Verify the result acknowledgement in the existing Make scenario execution history. Do not trigger a real lead.

## Outstanding production requirements

Structured queue, leases, durable result persistence, retries, cancellation, multi-computer coordination, and per-agent authentication remain future work. The prior GitHub Actions token mentioned in earlier audit notes still needs separate revocation verification. Do not change or reconnect production Make scenarios as part of installer work.

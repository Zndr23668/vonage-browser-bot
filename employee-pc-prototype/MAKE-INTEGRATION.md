# Make integration contract — controlled test bridge

This prototype is now connected to the existing Make flow, but it is not production-ready.

## Existing scenarios

- **Vonage SMS — Extract and Verify URL** (scenario 7957461): its old GitHub Actions dispatch module was replaced with a Data Store **Add/replace a record** module writing the incoming `text` as a key in `Redfin Agent Jobs - Prototype`.
- **Vonage Browser Results** (scenario 8121358): its existing webhook routes `action=claim`, `action=ack`, and `action=result`. A claim returns at most one queued URL; the agent acknowledges it by URL; results are acknowledged to the agent.

The queue is intentionally simple and test-only: each record's key is the URL, the response hardcodes `testOnly: true`, and the Windows agent polls every 10 seconds only for a five-minute test window. It pauses after one job. A test job should open the URL and report that it is not a lead page without clicking anything.

## Test

1. Start the Windows agent with the Make webhook URL for the existing **Vonage Browser Results** scenario stored locally.
2. Trigger the existing SMS extraction webhook with `text=https://www.redfin.com/`, or send that exact URL to the existing Vonage number.
3. Confirm the agent window logs `[make-remote] Received one test-only URL`, Chrome opens Redfin, and the agent records a `job_result` with `not_a_lead_page`.
4. Do not submit a real lead or enable click actions through this bridge.

## Production requirements still outstanding

- Replace the URL-as-record-key approach with a structured queue that supports multiple long URLs safely.
- Use per-agent authentication; the webhook URL is itself a bearer secret.
- Implement leases, expiry, deduplication, result persistence, cancellation/broadcast, and a real shared first-success coordination protocol.
- Do not poll Make at high frequency continuously. Make Free has a monthly operations limit, so this five-minute test window is deliberately bounded.
- Confirm Redfin's written approval explicitly covers automated Accept Lead clicks and employee-side automation.
- The previous GitHub Actions authorization token was found hardcoded in the old scenario config. It has been removed from that scenario, but it still must be revoked in GitHub and any replacement must be stored securely.
- Do not merge to `main` or reconnect production Make workflows until a controlled test and security review are complete.

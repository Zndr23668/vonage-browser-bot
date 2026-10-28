# Make integration contract — not connected yet

Keep the existing Vonage SMS → Make scenario unchanged until the prototype passes testing and production changes are explicitly approved.

## Target flow

1. Vonage sends the SMS event to Make.
2. Make extracts and validates the URL and resolves the employee using a trusted assignment table, not arbitrary SMS text.
3. Make enqueues a unique jobId, employeeId, URL, createdAt, expiresAt, and idempotency key in a cloud broker.
4. The Windows/macOS agent polls over outbound HTTPS using its own credential. The broker only leases jobs for that registered employee.
5. The Chrome extension opens the URL in that employee's existing Chrome profile.
6. The agent posts a sanitized result to the broker; Make receives a callback or reads the result.
7. Use leases, expiry, deduplication, bounded retries, and audit events.

## Suggested broker

Use a dedicated Supabase project or separately reviewed schema/Edge Functions, not an unreviewed RPportal production change. Endpoints: POST /enqueue (Make auth), POST /claim (per-agent auth and employee binding), POST /result (per-agent auth), GET /health. Never give a PC a global Make webhook secret or access to another employee's jobs.

## Statuses

- `accepted_confirmed`
- `click_submitted_unconfirmed`
- `requires_employee_login`
- `not_a_lead_page`
- `not_eligible`
- `expired`
- `agent_offline`
- `error`

Send only job ID, employee ID, status, timestamp, reason code, and minimal confirmation evidence. Never send cookies, passwords, full page HTML, or unrelated lead content. Redact URL query strings from logs.

## Production gate

- Confirm Redfin's written approval explicitly covers employee-side Chrome automation and automatic Accept Lead.
- Confirm trusted employee assignment and employee ID source.
- Use Windows Credential Manager/DPAPI on Windows and macOS Keychain on macOS for production per-device credentials. Do not store global secrets on employee PCs.
- Test with one consenting employee and a controlled lead.
- Obtain explicit approval before changing production Make scenarios or merging to main.
- The existing hardcoded GitHub credential should be revoked and replaced with a least-privilege secret.

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js LTS is required. Install it from https://nodejs.org/en/download, then run this launcher again."
  read -r -p "Press Return to close this window. "
  exit 1
fi

if [[ ! -f "local-settings.json" ]]; then
  echo "One-time setup for this Mac"
  read -r -p "Enter a short employee ID (example: employee-001): " RP_FIRST_EMPLOYEE_ID
  export RP_FIRST_EMPLOYEE_ID
fi

# Create the per-Mac token on first run and regenerate the extension config every
# launch so a stale config cannot silently mismatch the local settings.
node <<'NODE'
const fs = require("node:fs");
const crypto = require("node:crypto");
const settingsPath = "local-settings.json";
let settings;

if (fs.existsSync(settingsPath)) {
  settings = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
} else {
  const employeeId = String(process.env.RP_FIRST_EMPLOYEE_ID || "").trim();
  if (!/^[A-Za-z0-9._-]{1,64}$/.test(employeeId)) {
    console.error("Employee ID is required and may contain only letters, numbers, dots, underscores, and hyphens (max 64 characters).");
    process.exit(1);
  }
  settings = { employeeId, token: crypto.randomBytes(32).toString("hex") };
  fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + "\n", { mode: 0o600 });
}

if (!/^[A-Za-z0-9._-]{1,64}$/.test(String(settings.employeeId || "")) ||
    typeof settings.token !== "string" || settings.token.length < 24) {
  console.error("local-settings.json is invalid. Keep it private; restore from your own backup or remove it to configure this Mac again.");
  process.exit(1);
}

const config = `// Generated locally for this Mac. Keep this file private.
globalThis.RP_AGENT_CONFIG = {
  baseUrl: "http://127.0.0.1:8765",
  employeeId: ${JSON.stringify(settings.employeeId)},
  token: ${JSON.stringify(settings.token)},
  pollMs: 3000
};
`;
fs.writeFileSync("extension/config.local.js", config, { mode: 0o600 });
fs.chmodSync(settingsPath, 0o600);
fs.chmodSync("extension/config.local.js", 0o600);
console.log("Configuration ready for employee: " + settings.employeeId);
NODE

export RP_AGENT_TOKEN="$(node -p 'require("./local-settings.json").token')"
export RP_EMPLOYEE_ID="$(node -p 'require("./local-settings.json").employeeId')"
export RP_AGENT_PORT="8765"

echo ""
echo "Redfin Agent is starting for employee: $RP_EMPLOYEE_ID"
echo "Keep this Terminal window open while testing."
echo "Health check: http://127.0.0.1:8765/health"
echo "Stop the agent by pressing Control-C."
echo ""
exec node "./agent/server.mjs"

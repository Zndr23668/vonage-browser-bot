import http from "node:http";
import { randomUUID } from "node:crypto";

const HOST = "127.0.0.1";
const PORT = Number(process.env.RP_AGENT_PORT || 8765);
const TOKEN = process.env.RP_AGENT_TOKEN;
const EMPLOYEE_ID = process.env.RP_EMPLOYEE_ID;
const MAKE_WEBHOOK_URL = process.env.RP_MAKE_WEBHOOK_URL || "";
const REMOTE_POLL_INTERVAL_MS = 10_000;
const REMOTE_TEST_WINDOW_MS = 5 * 60_000;

if (!TOKEN || TOKEN.length < 24 || !EMPLOYEE_ID) {
  console.error("Run the platform-specific Start-Redfin-Agent launcher to configure this local agent.");
  process.exit(1);
}
if (MAKE_WEBHOOK_URL) {
  try {
    const u = new URL(MAKE_WEBHOOK_URL);
    if (u.protocol !== "https:" || !/^hook\.[a-z0-9-]+\.make\.com$/i.test(u.hostname) || u.search || u.hash) {
      throw new Error("Invalid Make webhook URL");
    }
  } catch {
    console.error("The configured Make webhook URL is invalid. It must be an HTTPS Make hook URL.");
    process.exit(1);
  }
}

const jobs = [];
const results = [];
const remoteSeenUrls = new Set();
let remotePollPaused = !MAKE_WEBHOOK_URL;
let remotePollInFlight = false;
let remotePollStartedAt = Date.now();
let lastPollWarningAt = 0;
let remotePollTimer;

function send(res, status, data, origin = "") {
  res.writeHead(status, { "Content-Type":"application/json", "Cache-Control":"no-store",
    "Access-Control-Allow-Origin":origin, "Vary":"Origin",
    "Access-Control-Allow-Headers":"Authorization, Content-Type", "Access-Control-Allow-Methods":"GET, POST, OPTIONS" });
  res.end(JSON.stringify(data));
}
function authorized(req) { return req.headers.authorization === "Bearer " + TOKEN; }
function validUrl(raw) {
  try {
    const u = new URL(raw), h = u.hostname.toLowerCase();
    if (u.protocol !== "https:" || !(h === "redfin.com" || h.endsWith(".redfin.com"))) return null;
    u.username = ""; u.password = ""; return u;
  } catch { return null; }
}
async function body(req) {
  let raw = "";
  for await (const chunk of req) {
    raw += chunk;
    if (Buffer.byteLength(raw) > 32768) throw new Error("Request too large");
  }
  return JSON.parse(raw || "{}");
}
async function callMake(payload) {
  if (!MAKE_WEBHOOK_URL) return null;
  const response = await fetch(MAKE_WEBHOOK_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
    cache: "no-store",
    signal: AbortSignal.timeout(9000)
  });
  const text = await response.text();
  let data = null;
  try { data = JSON.parse(text); } catch { /* Make's default webhook response may be plain text. */ }
  return { ok: response.ok, status: response.status, data, text };
}
async function pollRemoteMake() {
  if (remotePollPaused || remotePollInFlight || !MAKE_WEBHOOK_URL) return;
  if (Date.now() - remotePollStartedAt >= REMOTE_TEST_WINDOW_MS) {
    remotePollPaused = true;
    clearInterval(remotePollTimer);
    console.log("[make-remote] Test poll window ended after 5 minutes. Restart the agent to run another test.");
    return;
  }
  remotePollInFlight = true;
  try {
    const result = await callMake({ action: "claim", employeeId: EMPLOYEE_ID });
    if (!result?.ok) throw new Error("Make poll HTTP " + (result?.status ?? "no response"));
    const job = result.data?.job;
    const url = validUrl(job?.url);
    if (!url) return;

    // This remote bridge is intentionally test-only: it must never trigger Accept Lead.
    const canonicalUrl = url.href;
    if (remoteSeenUrls.has(canonicalUrl) || jobs.some(j => j.url === canonicalUrl)) {
      const ack = await callMake({ action: "ack", employeeId: EMPLOYEE_ID, url: canonicalUrl });
      if (ack?.ok) remotePollPaused = true;
      return;
    }
    if (jobs.length >= 100) throw new Error("Local agent queue is full");

    const localJob = {
      jobId: randomUUID(),
      employeeId: EMPLOYEE_ID,
      url: canonicalUrl,
      testOnly: true,
      createdAt: new Date().toISOString(),
      expiresAt: new Date(Date.now() + 600000).toISOString()
    };
    jobs.push(localJob);
    remoteSeenUrls.add(canonicalUrl);
    console.log("[make-remote] Received one test-only URL; opening it in the employee's Chrome session.");
    const ack = await callMake({ action: "ack", employeeId: EMPLOYEE_ID, url: canonicalUrl });
    if (!ack?.ok) {
      console.warn("[make-remote] Job was queued locally, but Make did not confirm the acknowledgement.");
      return;
    }
    remotePollPaused = true;
    clearInterval(remotePollTimer);
    console.log("[make-remote] Acknowledged by Make. Remote polling paused after the single test job.");
  } catch (e) {
    if (Date.now() - lastPollWarningAt > 30000) {
      console.warn("[make-remote] Poll failed; retrying during the limited test window:", String(e).slice(0, 180));
      lastPollWarningAt = Date.now();
    }
  } finally {
    remotePollInFlight = false;
  }
}

const server = http.createServer(async (req, res) => {
  const origin = req.headers.origin || "";
  // Chrome extension requests may omit Origin. Bearer-token authentication remains required.
  const isExtension = origin.startsWith("chrome-extension://") || origin === "null" || origin === "";
  if (req.method === "OPTIONS") return isExtension ? send(res,204,{},origin) : send(res,403,{error:"Origin denied"});
  const path = new URL(req.url, "http://" + HOST + ":" + PORT).pathname;
  if (path === "/health" && req.method === "GET") return send(res,200,{
    status:"ok",employeeId:EMPLOYEE_ID,queuedJobs:jobs.length,
    remoteMakeConfigured:Boolean(MAKE_WEBHOOK_URL),remotePolling:MAKE_WEBHOOK_URL && !remotePollPaused
  });
  if (!authorized(req)) return send(res,401,{error:"Unauthorized"});
  if (path === "/jobs" && req.method === "POST") {
    try {
      const b = await body(req);
      if (b.employeeId !== EMPLOYEE_ID) return send(res,403,{error:"Wrong employee assignment"});
      const u = validUrl(b.url);
      if (!u) return send(res,400,{error:"Only HTTPS Redfin URLs accepted"});
      const id = String(b.jobId || randomUUID()).slice(0,128);
      if (jobs.some(j=>j.jobId===id) || results.some(r=>r.jobId===id)) return send(res,200,{accepted:true,duplicate:true,jobId:id});
      if (jobs.length >= 100) return send(res,429,{error:"Queue full"});
      jobs.push({jobId:id,employeeId:EMPLOYEE_ID,url:u.href,testOnly:b.testOnly!==false,
        createdAt:new Date().toISOString(),expiresAt:new Date(Date.now()+600000).toISOString()});
      return send(res,202,{accepted:true,jobId:id});
    } catch (e) { return send(res,400,{error:e.message}); }
  }
  if (path === "/next-job" && req.method === "GET") {
    if (!isExtension) return send(res,403,{error:"Extension origin denied"});
    for (let i=jobs.length-1;i>=0;i--) if (Date.parse(jobs[i].expiresAt)<=Date.now()) {
      results.push({jobId:jobs[i].jobId,employeeId:EMPLOYEE_ID,status:"expired"}); jobs.splice(i,1);
    }
    return send(res,200,{job:jobs.shift() || null},origin);
  }
  if (path === "/results" && req.method === "POST") {
    try {
      const b=await body(req);
      if (b.employeeId!==EMPLOYEE_ID || !b.jobId || !b.status) return send(res,400,{error:"Missing result fields"},isExtension?origin:"");
      const r={jobId:String(b.jobId).slice(0,128),employeeId:EMPLOYEE_ID,status:String(b.status).slice(0,64),
        reasonCode:String(b.reasonCode||"").slice(0,160),finalHost:String(b.finalHost||"").slice(0,253),finishedAt:new Date().toISOString()};
      results.push(r); if(results.length>500) results.shift();
      console.log(JSON.stringify({event:"job_result",...r}));
      if (MAKE_WEBHOOK_URL) {
        void callMake({action:"result",employeeId:EMPLOYEE_ID,...r})
          .then(result=>{if(!result?.ok)console.warn("[make-remote] Result report HTTP",result?.status);})
          .catch(e=>console.warn("[make-remote] Result report failed",String(e).slice(0,120)));
      }
      return send(res,202,{recorded:true,jobId:r.jobId},isExtension?origin:"");
    } catch(e) { return send(res,400,{error:e.message},isExtension?origin:""); }
  }
  if (path === "/results" && req.method === "GET") return send(res,200,{results:results.slice(-50)});
  return send(res,404,{error:"Not found"});
});
server.listen(PORT,HOST,()=>{
  console.log("RP prototype agent listening on 127.0.0.1:"+PORT+" for "+EMPLOYEE_ID);
  if (MAKE_WEBHOOK_URL) {
    console.log("Make remote test mode is enabled for up to 5 minutes and one test-only URL.");
    remotePollTimer = setInterval(()=>void pollRemoteMake(),REMOTE_POLL_INTERVAL_MS);
    setTimeout(()=>void pollRemoteMake(),1000);
  } else {
    console.log("No Make remote webhook configured; local-only mode.");
  }
});

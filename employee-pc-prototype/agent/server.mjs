import http from "node:http";
import { randomUUID } from "node:crypto";

const HOST = "127.0.0.1";
const PORT = Number(process.env.RP_AGENT_PORT || 8765);
const TOKEN = process.env.RP_AGENT_TOKEN;
const EMPLOYEE_ID = process.env.RP_EMPLOYEE_ID;
const EXTENSION_ORIGIN = process.env.RP_EXTENSION_ORIGIN;
if (!TOKEN || TOKEN.length < 24 || !EMPLOYEE_ID || !EXTENSION_ORIGIN?.startsWith("chrome-extension://")) {
  console.error("Set RP_AGENT_TOKEN (24+ chars), RP_EMPLOYEE_ID, and RP_EXTENSION_ORIGIN.");
  process.exit(1);
}
const jobs = [];
const results = [];
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
const server = http.createServer(async (req, res) => {
  const origin = req.headers.origin || "";
  const isExtension = origin === EXTENSION_ORIGIN;
  if (req.method === "OPTIONS") return isExtension ? send(res,204,{},origin) : send(res,403,{error:"Origin denied"});
  const path = new URL(req.url, "http://" + HOST + ":" + PORT).pathname;
  if (path === "/health" && req.method === "GET") return send(res,200,{status:"ok",employeeId:EMPLOYEE_ID,queuedJobs:jobs.length});
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
      return send(res,202,{recorded:true,jobId:r.jobId},isExtension?origin:"");
    } catch(e) { return send(res,400,{error:e.message},isExtension?origin:""); }
  }
  if (path === "/results" && req.method === "GET") return send(res,200,{results:results.slice(-50)});
  return send(res,404,{error:"Not found"});
});
server.listen(PORT,HOST,()=>console.log("RP prototype agent listening on 127.0.0.1:"+PORT+" for "+EMPLOYEE_ID));

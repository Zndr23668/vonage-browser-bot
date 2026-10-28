importScripts("config.js");
const cfg=globalThis.RP_AGENT_CONFIG;
let polling=false;
async function postResult(r) {
  try { await fetch(cfg.baseUrl+"/results",{method:"POST",headers:{"Authorization":"Bearer "+cfg.token,"Content-Type":"application/json"},body:JSON.stringify({...r,employeeId:cfg.employeeId}),cache:"no-store"}); }
  catch(e) { console.warn("Result delivery failed",String(e).slice(0,120)); }
}
async function poll() {
  if(polling || !cfg.token || cfg.token.startsWith("REPLACE_")) return;
  polling=true;
  try {
    const response=await fetch(cfg.baseUrl+"/next-job?employeeId="+encodeURIComponent(cfg.employeeId),{headers:{"Authorization":"Bearer "+cfg.token},cache:"no-store"});
    if(!response.ok) throw new Error("Poll HTTP "+response.status);
    const data=await response.json();
    if(!data.job) return;
    const tab=await chrome.tabs.create({url:data.job.url,active:true});
    await chrome.storage.local.set({["job:"+tab.id]:data.job});
  } catch(e) { console.warn("Local agent unavailable",String(e).slice(0,120)); }
  finally { polling=false; }
}
chrome.runtime.onMessage.addListener((m,sender)=>{
  if(m?.type!=="RP_REDFIN_RESULT" || !sender.tab?.id || !m.result?.jobId) return;
  void postResult(m.result);
  void chrome.storage.local.remove("job:"+sender.tab.id);
});
chrome.tabs.onRemoved.addListener(async id=>{
  const key="job:"+id, data=await chrome.storage.local.get(key), job=data[key];
  if(job) { await postResult({jobId:job.jobId,status:"error",reasonCode:"tab_closed_before_result"}); await chrome.storage.local.remove(key); }
});
chrome.alarms.create("rp-poll",{periodInMinutes:0.5});
chrome.alarms.onAlarm.addListener(a=>{if(a.name==="rp-poll")void poll();});
setInterval(()=>void poll(),Math.max(3000,cfg.pollMs||3000));
void poll();

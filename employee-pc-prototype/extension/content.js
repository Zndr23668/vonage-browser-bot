(() => {
  if(window.__rpRedfinPrototypeLoaded)return;
  window.__rpRedfinPrototypeLoaded=true;
  const host=location.hostname.toLowerCase();
  if(location.protocol!=="https:" || !(host==="redfin.com" || host.endsWith(".redfin.com")))return;
  const visible=el=>{if(!(el instanceof HTMLElement))return false;const s=getComputedStyle(el),r=el.getBoundingClientRect();return s.display!=="none"&&s.visibility!=="hidden"&&Number(s.opacity)>0&&r.width>0&&r.height>0;};
  const clean=v=>String(v||"").replace(/\\s+/g," ").trim();
  function report(job,status,reasonCode){chrome.runtime.sendMessage({type:"RP_REDFIN_RESULT",result:{jobId:job.jobId,employeeId:job.employeeId,status,reasonCode,finalHost:location.hostname}});}
  async function inspect(){
    const store=await chrome.storage.local.get(null);
    const items=Object.entries(store).filter(([k,v])=>k.startsWith("job:")&&v&&typeof v.url==="string");
    const job=items.map(([,v])=>v).find(v=>{try{const u=new URL(v.url);return u.hostname.toLowerCase()===host&&(u.pathname===location.pathname||location.href.startsWith(v.url));}catch{return false;}});
    if(!job)return;
    const text=clean(document.body?.innerText||"");
    if(/\\/(login|signin|sign-in|auth)(\\/|$)/i.test(location.pathname)||/sign in to redfin|log in to redfin/i.test(text))return report(job,"requires_employee_login","redfin_login_page");
    const buttons=[...document.querySelectorAll("button,[role='button'],input[type='button'],input[type='submit']")].filter(visible).filter(e=>!e.disabled&&e.getAttribute("aria-disabled")!=="true").filter(e=>clean(e.innerText||e.value||e.getAttribute("aria-label"))==="Accept Lead");
    if(buttons.length===0)return report(job,"not_a_lead_page","exact_accept_lead_button_not_found");
    if(buttons.length!==1)return report(job,"not_eligible","ambiguous_accept_lead_controls");
    if(/lead accepted|successfully accepted|already accepted/i.test(text))return report(job,"accepted_confirmed","page_shows_already_accepted");
    const button=buttons[0];
    button.click();
    const started=Date.now(), timer=setInterval(()=>{
      const after=clean(document.body?.innerText||"");
      if(/lead accepted|successfully accepted|accepted successfully|lead has been accepted/i.test(after)){clearInterval(timer);report(job,"accepted_confirmed","visible_success_message");}
      else if(Date.now()-started>8000){clearInterval(timer);report(job,"click_submitted_unconfirmed",visible(button)&&!button.disabled?"button_still_present_after_click":"no_confirmed_success_signal");}
    },500);
  }
  setTimeout(()=>{void inspect();},1800);
})();

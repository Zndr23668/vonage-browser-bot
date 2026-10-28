(() => {
  if (window.__rpRedfinPrototypeLoaded) return;
  window.__rpRedfinPrototypeLoaded = true;
  const host = location.hostname.toLowerCase();
  if (location.protocol !== "https:" || !(host === "redfin.com" || host.endsWith(".redfin.com"))) return;
  const visible = el => {
    if (!(el instanceof HTMLElement)) return false;
    const style = getComputedStyle(el), rect = el.getBoundingClientRect();
    return style.display !== "none" && style.visibility !== "hidden" && Number(style.opacity) > 0 && rect.width > 0 && rect.height > 0;
  };
  const clean = value => String(value || "").replace(/\s+/g, " ").trim();
  function report(job, status, reasonCode) {
    chrome.runtime.sendMessage({type:"RP_REDFIN_RESULT",result:{jobId:job.jobId,employeeId:job.employeeId,status,reasonCode,finalHost:location.hostname}});
  }
  async function inspect() {
    const response = await chrome.runtime.sendMessage({type:"RP_GET_JOB"});
    const job = response?.job;
    if (!job) return;
    if (job.testOnly !== true) return report(job,"blocked_non_test_job","prototype_requires_test_only");
    const text = clean(document.body?.innerText || "");
    if (/\/(login|signin|sign-in|auth)(\/|$)/i.test(location.pathname) || /sign in to redfin|log in to redfin/i.test(text)) return report(job,"requires_employee_login","redfin_login_page");
    let target;
    try { target = new URL(job.url); } catch { return report(job,"not_eligible","invalid_job_url"); }
    const targetHost = target.hostname.toLowerCase();
    if (target.protocol !== "https:" || !(targetHost === "redfin.com" || targetHost.endsWith(".redfin.com"))) return report(job,"not_eligible","target_host_not_allowed");
    if (targetHost !== host || target.pathname !== location.pathname) return report(job,"not_eligible","target_url_mismatch");
    const buttons = [...document.querySelectorAll("button,[role='button'],input[type='button'],input[type='submit']")]
      .filter(visible)
      .filter(el => !el.disabled && el.getAttribute("aria-disabled") !== "true")
      .filter(el => clean(el.innerText || el.value || el.getAttribute("aria-label")) === "Accept Lead");
    if (buttons.length === 0) return report(job,"not_a_lead_page","exact_accept_lead_button_not_found");
    if (buttons.length !== 1) return report(job,"not_eligible","ambiguous_accept_lead_controls");
    if (/lead accepted|successfully accepted|already accepted/i.test(text)) return report(job,"accepted_confirmed","page_shows_already_accepted");
    // Read-only prototype: even a matching Accept Lead button is never clicked.
    return report(job,"dry_run_eligible","unique_eligible_button_found_no_click");
  }
  setTimeout(() => { void inspect().catch(error => console.warn("Redfin dry-run inspection failed",String(error).slice(0,160))); },1800);
})();

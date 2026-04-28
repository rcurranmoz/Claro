let currentTabId = null;
let currentAnalysis = null;
let currentPageText = null;

// ── Init ──────────────────────────────────────────────────────────────────────

async function init() {
  const tabs = await browser.tabs.query({ active: true, currentWindow: true });
  if (tabs[0]) {
    currentTabId = tabs[0].id;
    updatePageInfo(tabs[0].title, tabs[0].url);
  }

  browser.tabs.onActivated.addListener(async ({ tabId }) => {
    currentTabId = tabId;
    currentAnalysis = null;
    currentPageText = null;
    const tab = await browser.tabs.get(tabId);
    updatePageInfo(tab.title, tab.url);
    showState("idle");
  });

  browser.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
    if (tabId === currentTabId && changeInfo.status === "complete") {
      updatePageInfo(tab.title, tab.url);
      if (currentAnalysis) showState("idle"); // page navigated away
    }
  });
}

function updatePageInfo(title, url) {
  document.getElementById("page-title").textContent = title || "—";
  try {
    document.getElementById("page-url").textContent = new URL(url).hostname + new URL(url).pathname;
  } catch {
    document.getElementById("page-url").textContent = url || "—";
  }
}

// ── State management ─────────────────────────────────────────────────────────

function showState(name) {
  ["idle", "loading", "error", "unconfigured", "paste", "results"].forEach((s) => {
    document.getElementById(`${s}-state`).classList.toggle("hidden", s !== name);
  });
  document.getElementById("dispute-modal").classList.add("hidden");
}

// ── Event listeners ───────────────────────────────────────────────────────────

document.getElementById("analyze-btn").addEventListener("click", runAnalysis);
document.getElementById("retry-btn").addEventListener("click", runAnalysis);
document.getElementById("reanalyze-btn").addEventListener("click", runAnalysis);
document.getElementById("paste-analyze-btn").addEventListener("click", runPasteAnalysis);
document.getElementById("show-paste-btn").addEventListener("click", () => showState("paste"));
document.getElementById("back-from-paste-btn").addEventListener("click", () => showState("idle"));

document.getElementById("settings-btn").addEventListener("click", () => {
  browser.runtime.openOptionsPage();
});
document.getElementById("open-settings-btn").addEventListener("click", () => {
  browser.runtime.openOptionsPage();
});

document.getElementById("lineitems-toggle").addEventListener("click", (e) => {
  const btn = e.currentTarget;
  const list = document.getElementById("lineitems-list");
  const open = btn.classList.toggle("open");
  list.classList.toggle("hidden", !open);
});

document.getElementById("dispute-btn").addEventListener("click", openDisputeModal);
document.getElementById("close-modal-btn").addEventListener("click", () => {
  document.getElementById("dispute-modal").classList.add("hidden");
});
document.getElementById("copy-letter-btn").addEventListener("click", () => {
  const text = document.getElementById("dispute-text").textContent;
  navigator.clipboard.writeText(text).then(() => {
    const btn = document.getElementById("copy-letter-btn");
    btn.textContent = "Copied!";
    setTimeout(() => (btn.textContent = "Copy to Clipboard"), 2000);
  });
});

// ── Analysis ──────────────────────────────────────────────────────────────────

async function runAnalysis() {
  if (!currentTabId) return;
  showState("loading");

  try {
    const result = await browser.runtime.sendMessage({
      type: "ANALYZE_PAGE",
      tabId: currentTabId,
    });
    currentAnalysis = result;
    renderResults(result);
    showState("results");
  } catch (err) {
    if (err.message === "UNCONFIGURED") {
      showState("unconfigured");
    } else {
      document.getElementById("error-text").textContent = err.message || "Analysis failed.";
      showState("error");
    }
  }
}

async function runPasteAnalysis() {
  const text = document.getElementById("paste-input").value.trim();
  if (!text) {
    document.getElementById("paste-input").focus();
    return;
  }
  showState("loading");

  try {
    const result = await browser.runtime.sendMessage({
      type: "ANALYZE_TEXT",
      text,
      docType: "medical document",
    });
    currentAnalysis = result;
    currentPageText = text;
    renderResults(result);
    showState("results");
  } catch (err) {
    if (err.message === "UNCONFIGURED") {
      showState("unconfigured");
    } else {
      document.getElementById("error-text").textContent = err.message || "Analysis failed.";
      showState("error");
    }
  }
}

// ── Render ────────────────────────────────────────────────────────────────────

function renderResults(a) {
  document.getElementById("results-title").textContent = a.title || "Analysis";
  document.getElementById("results-summary").textContent = a.summary || "";

  renderScoreChips(a);
  renderFinancials(a);
  renderIssues(a.flaggedIssues || []);
  renderActions(a.actionItems || []);
  renderPositives(a.positiveFindings || []);
  renderLineItems(a.lineItems || []);

  const hasIssues = (a.flaggedIssues || []).length > 0;
  document.getElementById("dispute-section").classList.toggle("hidden", !hasIssues);
}

function renderScoreChips(a) {
  const good  = (a.positiveFindings || []).length + ((a.flaggedIssues || []).filter(i => i.severity === "info").length);
  const warn  = (a.flaggedIssues || []).filter(i => i.severity === "warning").length;
  const alert = (a.flaggedIssues || []).filter(i => i.severity === "alert").length;

  document.getElementById("score-row").innerHTML = `
    <div class="score-chip good">
      <span class="chip-count">${good}</span>
      <span class="chip-label">Good</span>
    </div>
    <div class="score-chip warn">
      <span class="chip-count">${warn}</span>
      <span class="chip-label">Review</span>
    </div>
    <div class="score-chip alert">
      <span class="chip-count">${alert}</span>
      <span class="chip-label">Alert</span>
    </div>
  `;
}

function renderFinancials(a) {
  const el = document.getElementById("financials");
  if (a.totalBilled == null && a.patientOwes == null) {
    el.innerHTML = "";
    return;
  }
  el.innerHTML = `
    ${a.totalBilled != null ? `
      <div class="financial-card">
        <div class="financial-label">Total Billed</div>
        <div class="financial-amount">${fmt(a.totalBilled)}</div>
      </div>` : ""}
    ${a.patientOwes != null ? `
      <div class="financial-card owes">
        <div class="financial-label">You Owe</div>
        <div class="financial-amount">${fmt(a.patientOwes)}</div>
      </div>` : ""}
  `;
}

function renderIssues(issues) {
  const section = document.getElementById("issues-section");
  const list = document.getElementById("issues-list");
  if (issues.length === 0) { section.classList.add("hidden"); return; }
  section.classList.remove("hidden");
  list.innerHTML = issues.map((issue) => `
    <div class="item-card">
      <div class="item-header">
        <span class="item-title">${esc(issue.title)}</span>
        <span class="badge badge-${issue.severity || "info"}">${capitalize(issue.severity || "info")}</span>
      </div>
      <p class="item-detail">${esc(issue.detail)}</p>
    </div>
  `).join("");
}

function renderActions(actions) {
  const section = document.getElementById("actions-section");
  const list = document.getElementById("actions-list");
  if (actions.length === 0) { section.classList.add("hidden"); return; }
  section.classList.remove("hidden");
  list.innerHTML = actions.map((action) => `
    <div class="item-card">
      <div class="item-header">
        <span class="item-title">${esc(action.title)}</span>
        <span class="badge badge-${action.urgency || "low"}">${capitalize(action.urgency || "low")}</span>
      </div>
      <p class="item-detail">${esc(action.detail)}</p>
    </div>
  `).join("");
}

function renderPositives(positives) {
  const section = document.getElementById("positives-section");
  const list = document.getElementById("positives-list");
  if (positives.length === 0) { section.classList.add("hidden"); return; }
  section.classList.remove("hidden");
  list.innerHTML = positives.map((p) => `
    <div class="item-card">
      <div class="item-title">${esc(p.title)}</div>
      <p class="item-detail">${esc(p.detail)}</p>
    </div>
  `).join("");
}

function renderLineItems(items) {
  const section = document.getElementById("lineitems-section");
  const list = document.getElementById("lineitems-list");
  if (items.length === 0) { section.classList.add("hidden"); return; }
  section.classList.remove("hidden");
  list.innerHTML = items.map((item) => `
    <div class="lineitem-row">
      <div>
        ${item.code ? `<div class="lineitem-code">${esc(item.code)}</div>` : ""}
        <div class="lineitem-plain">${esc(item.plainDescription || item.rawDescription)}</div>
      </div>
      ${item.amount != null ? `<div class="lineitem-amount">${fmt(item.amount)}</div>` : "<div></div>"}
    </div>
  `).join("");
}

// ── Dispute Letter ────────────────────────────────────────────────────────────

async function openDisputeModal() {
  const modal    = document.getElementById("dispute-modal");
  const loading  = document.getElementById("dispute-loading");
  const textEl   = document.getElementById("dispute-text");

  modal.classList.remove("hidden");
  loading.classList.remove("hidden");
  textEl.textContent = "";

  try {
    const issues = (currentAnalysis?.flaggedIssues || []).filter(i => i.severity !== "info");
    const letter = await browser.runtime.sendMessage({
      type: "GENERATE_DISPUTE",
      text: currentPageText || "",
      issues,
    });
    textEl.textContent = letter;
  } catch (err) {
    textEl.textContent = `Error generating letter: ${err.message}`;
  } finally {
    loading.classList.add("hidden");
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function fmt(n) {
  return new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(n);
}

function esc(str) {
  return String(str ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function capitalize(str) {
  return str ? str.charAt(0).toUpperCase() + str.slice(1) : "";
}

init();

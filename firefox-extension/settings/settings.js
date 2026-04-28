const urlInput    = document.getElementById("worker-url");
const secretInput = document.getElementById("worker-secret");
const saveBtn     = document.getElementById("save-btn");
const statusMsg   = document.getElementById("status-msg");

browser.storage.local.get(["workerUrl", "workerSecret"]).then((config) => {
  if (config.workerUrl)    urlInput.value = config.workerUrl;
  if (config.workerSecret) secretInput.value = config.workerSecret;
});

saveBtn.addEventListener("click", async () => {
  const url    = urlInput.value.trim().replace(/\/$/, "");
  const secret = secretInput.value.trim();

  if (!url) {
    showStatus("Worker URL is required.", false);
    urlInput.focus();
    return;
  }
  try { new URL(url); } catch {
    showStatus("Enter a valid URL.", false);
    urlInput.focus();
    return;
  }
  if (!secret) {
    showStatus("App secret is required.", false);
    secretInput.focus();
    return;
  }

  await browser.storage.local.set({ workerUrl: url, workerSecret: secret });
  showStatus("Saved!", true);
});

function showStatus(msg, ok) {
  statusMsg.textContent = msg;
  statusMsg.className = "status " + (ok ? "ok" : "err");
  if (ok) setTimeout(() => { statusMsg.textContent = ""; }, 3000);
}

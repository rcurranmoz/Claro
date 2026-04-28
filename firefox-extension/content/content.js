browser.runtime.onMessage.addListener((message) => {
  if (message.type === "EXTRACT_TEXT") {
    return Promise.resolve(extractPageContent());
  }
});

function extractPageContent() {
  const clone = document.body.cloneNode(true);
  clone
    .querySelectorAll(
      "script, style, noscript, nav, header, footer, [role='navigation'], [role='banner'], [aria-hidden='true']"
    )
    .forEach((el) => el.remove());

  let text = (clone.innerText || clone.textContent || "")
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
    .join("\n");

  if (text.length > 20000) text = text.slice(0, 20000) + "\n[content truncated]";

  const docType = detectDocType(text, document.title, window.location.href);

  return { text, docType };
}

function detectDocType(text, title, url) {
  const combined = (text + " " + title + " " + url).toLowerCase();

  if (combined.includes("explanation of benefits") || combined.includes(" eob "))
    return "Explanation of Benefits (EOB)";
  if (combined.includes("remittance")) return "Remittance Advice";
  if (combined.includes("itemized bill") || combined.includes("itemized statement"))
    return "Itemized Medical Bill";
  if (combined.includes("lab result") || combined.includes("laboratory result"))
    return "Lab Results";
  if (combined.includes("discharge summary")) return "Discharge Summary";
  if (combined.includes("patient statement") || (combined.includes("statement") && combined.includes("patient")))
    return "Patient Statement";
  if (combined.includes("medical invoice") || (combined.includes("invoice") && combined.includes("patient")))
    return "Medical Invoice";
  if (combined.includes("mychart") || combined.includes("epic") || combined.includes("patient portal"))
    return "Patient Portal Document";
  if (combined.includes("prescription") || combined.includes("rx ")) return "Prescription";
  return "medical document";
}

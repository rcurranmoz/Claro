// Toggle sidebar when toolbar button is clicked
browser.browserAction.onClicked.addListener(() => {
  browser.sidebarAction.toggle();
});

browser.runtime.onMessage.addListener((message, sender) => {
  if (message.type === "ANALYZE_PAGE") {
    return handleAnalyzePage(message.tabId);
  }
  if (message.type === "ANALYZE_TEXT") {
    return analyzeText(message.text, message.docType);
  }
  if (message.type === "GENERATE_DISPUTE") {
    return generateDisputeLetter(message.text, message.issues);
  }
});

async function handleAnalyzePage(tabId) {
  const tab = await browser.tabs.get(tabId);

  // PDFs can't be read by content scripts — extract via the PDF service
  if (isPdfUrl(tab.url)) {
    return analyzePdf(tab.url);
  }

  let extraction;
  try {
    extraction = await browser.tabs.sendMessage(tabId, { type: "EXTRACT_TEXT" });
  } catch {
    throw new Error("Could not read this page. Refresh the page and try again.");
  }

  if (!extraction?.text || extraction.text.trim().length < 50) {
    throw new Error("Not enough text found on this page to analyze.");
  }

  return analyzeText(extraction.text, extraction.docType);
}

function isPdfUrl(url) {
  try {
    return new URL(url).pathname.toLowerCase().endsWith(".pdf");
  } catch {
    return false;
  }
}

async function analyzePdf(url) {
  const config = await browser.storage.local.get(["extractorUrl", "workerSecret"]);

  if (!config.extractorUrl) {
    // No extractor configured — fall back to paste state
    throw new Error("THIN_CONTENT");
  }

  const response = await fetch(`${config.extractorUrl}/extract`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Claro-Secret": config.workerSecret,
    },
    body: JSON.stringify({ url }),
  });

  if (!response.ok) {
    const body = await response.text().catch(() => "");
    throw new Error(`PDF extraction failed: ${body.slice(0, 200)}`);
  }

  const { text } = await response.json();
  if (!text || text.trim().length < 50) {
    throw new Error("THIN_CONTENT");
  }

  return analyzeText(text, "medical document (PDF)");
}

async function analyzeText(text, docType) {
  const config = await browser.storage.local.get(["workerUrl", "workerSecret"]);

  if (!config.workerUrl || !config.workerSecret) {
    throw new Error("UNCONFIGURED");
  }

  const response = await fetch(`${config.workerUrl}/v1/messages`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Claro-Secret": config.workerSecret,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-sonnet-4-6",
      max_tokens: 2048,
      system: SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content: `This is a ${docType}. Analyze it and respond with JSON only.\n\n${text}`,
        },
      ],
    }),
  });

  if (!response.ok) {
    const body = await response.text().catch(() => "");
    throw new Error(`API error ${response.status}: ${body.slice(0, 200)}`);
  }

  const data = await response.json();
  const rawText = data.content?.[0]?.text;
  if (!rawText) throw new Error("Empty response from analysis service.");

  return parseAnalysis(rawText);
}

async function generateDisputeLetter(documentText, issues) {
  const config = await browser.storage.local.get(["workerUrl", "workerSecret"]);

  if (!config.workerUrl || !config.workerSecret) {
    throw new Error("UNCONFIGURED");
  }

  const issueList = issues.map((i) => `• ${i.title}: ${i.detail}`).join("\n");
  const prompt = `Based on this medical billing document and the issues listed below, write a professional dispute letter the patient can send to their provider or insurance company.

Issues to address:
${issueList}

Write a complete, ready-to-mail letter. Use placeholders like [YOUR NAME], [YOUR ADDRESS], [DATE], [PROVIDER/INSURER NAME AND ADDRESS] where the patient must fill in their information. Be firm but courteous. Reference specific amounts and dates visible in the document. Cite applicable patient rights and laws where relevant (No Surprises Act, state balance billing protections, ACA protections). End with a clear request and a deadline for response.

Document text:
${documentText.slice(0, 6000)}`;

  const response = await fetch(`${config.workerUrl}/v1/messages`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Claro-Secret": config.workerSecret,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-sonnet-4-6",
      max_tokens: 1500,
      messages: [{ role: "user", content: prompt }],
    }),
  });

  if (!response.ok) {
    throw new Error(`API error ${response.status}`);
  }

  const data = await response.json();
  return data.content?.[0]?.text ?? "";
}

function parseAnalysis(text) {
  let cleaned = text.trim();
  // Strip markdown code fences if Claude wrapped the JSON
  if (cleaned.startsWith("```")) {
    cleaned = cleaned.split("\n").slice(1).join("\n");
    if (cleaned.endsWith("```")) cleaned = cleaned.slice(0, -3);
  }
  return JSON.parse(cleaned.trim());
}

const SYSTEM_PROMPT = `You are an expert medical billing advocate with deep knowledge of CPT codes, ICD-10 codes, insurance EOBs, patient rights, appeal processes, and common billing errors.

Analyze the provided health document text and respond with ONLY a valid JSON object — no markdown, no preamble, no explanation outside the JSON.

Schema:
{
  "title": "short descriptive label, 3-6 words, e.g. 'UCSF ER Visit Feb 2026' or 'Anthem EOB – Knee Surgery'",
  "summary": "2-3 sentences in plain English: what is this document and what does the patient need to know right now",
  "lineItems": [
    {
      "code": "CPT or procedure code if visible, or null",
      "rawDescription": "exact text from the document",
      "plainDescription": "what this actually means in plain English",
      "amount": dollar amount as a number, or null
    }
  ],
  "positiveFindings": [
    {
      "title": "short label for something that looks correct or favorable",
      "detail": "why this is good news for the patient"
    }
  ],
  "flaggedIssues": [
    {
      "title": "short issue name",
      "detail": "what the issue is, why it matters, what to do about it",
      "severity": "alert (needs immediate action/dispute), warning (worth checking), or info (minor note)"
    }
  ],
  "actionItems": [
    {
      "title": "what the patient should do",
      "detail": "how to do it, who to call, what to say, any deadlines",
      "urgency": "high or medium or low"
    }
  ],
  "totalBilled": total amount billed as a number or null,
  "patientOwes": amount the patient is actually responsible for as a number or null
}

For positiveFindings, note things like: insurance adjustment correctly applied, no duplicate charges found, charges align with diagnosis, deductible applied correctly, provider is in-network, payment processed. Only include if genuinely confirmed — do not invent.

For flaggedIssues: use severity "alert" for potential errors requiring dispute or escalation, "warning" for things that seem off but need verification, "info" for general notes. Actively look for: duplicate charges, unbundling, upcoding, balance billing violations, charges exceeding usual and customary rates, missing insurance adjustments, incorrect application of deductible or copay, billing for services not rendered.

For actionItems, include: appeal deadlines if relevant, who to call (insurer vs provider), requests for itemized bills, and anything time-sensitive.

If the text is unclear or not a medical document, return a summary explaining that and empty arrays for the other fields.`;

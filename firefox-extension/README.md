# Claro Lens — Firefox Extension

A companion extension to the Claro Lens iOS app. Analyzes medical bills, EOBs, and patient portal pages directly in your browser using the same Claude-powered analysis engine.

## Features

- **One-click page analysis** — click Analyze on any patient portal, billing page, or health document site
- **Color-coded results** — Good / Review / Alert findings matching the Claro iOS experience
- **Billing error detection** — flags duplicate charges, upcoding, balance billing violations, and more
- **Action items** — clear next steps ranked high/medium/low with who to call and what to say
- **Dispute letter generator** — one click drafts a ready-to-mail letter citing the No Surprises Act
- **Paste fallback** — for PDFs or JS-rendered portals, paste extracted text for full analysis

## Stack

| Layer | Technology |
|---|---|
| Platform | Firefox WebExtension MV2 |
| AI | Anthropic Messages API via Cloudflare Worker proxy |
| UI | Vanilla JS + CSS, dark theme matching Claro iOS design system |

## Setup

### Prerequisites

- The Claro Cloudflare Worker deployed (`cloudflare-worker/`)
- Your `CLARO_APP_SECRET` value (see `Claro/Config.swift`)

### Load in Firefox (development)

1. Open `about:debugging` → **This Firefox** → **Load Temporary Add-on**
2. Select `firefox-extension/manifest.json`
3. Click the Claro icon in the toolbar (pin it if needed via the puzzle piece menu)
4. Click the gear icon → enter your Worker URL and app secret → **Save Settings**

### Production install

Once published to [addons.mozilla.org](https://addons.mozilla.org), install normally. To enable analysis of local files, go to `about:addons` → Claro Lens → **Details** → toggle **Run on file URLs**.

## Usage

1. Navigate to a medical bill, EOB, or patient portal page
2. Click the Claro Lens toolbar icon to open the sidebar
3. Click **Analyze This Page**
4. Review color-coded findings, action items, and financial summary
5. Optionally tap **Generate Dispute Letter** if billing issues were flagged

For PDFs or pages that can't be read directly, use **Paste document text instead** — copy text from Preview or Acrobat (`⌘A` → `⌘C`) and paste into the sidebar.

## File Structure

```
firefox-extension/
├── manifest.json          # MV2 manifest — permissions, sidebar, background
├── background/
│   └── background.js      # Toolbar toggle, API calls to Cloudflare Worker
├── content/
│   └── content.js         # Page text extraction and doc type detection
├── sidebar/
│   ├── sidebar.html        # Main UI — analysis results, dispute letter modal
│   ├── sidebar.js          # State machine, rendering, message passing
│   └── sidebar.css         # Dark theme matching Claro iOS design tokens
├── settings/
│   ├── settings.html       # Worker URL + secret configuration
│   └── settings.js
└── icons/
    ├── icon-48.svg
    └── icon-96.svg
```

## Configuration

Settings are stored in `browser.storage.local`:

| Key | Description |
|---|---|
| `workerUrl` | Cloudflare Worker base URL, e.g. `https://claro-proxy.yourname.workers.dev` |
| `workerSecret` | Value of `CLARO_APP_SECRET` set via `wrangler secret put` |

The extension never touches your Anthropic API key — that stays in the Worker.

# 🩺 Claro Lens

**Medical bills are confusing by design. Claro Lens fixes that.**

Claro Lens is a privacy-first iOS app that acts as your personal health billing advocate. Photograph a medical bill, EOB, lab result, or insurance card — Claro uses Claude AI to translate every line item into plain English, flag potential billing errors, and tell you exactly what to do next.

---

## ✨ Features

- 📄 **Scan or upload any health document** — bills, EOBs, lab results, discharge summaries, prescriptions, insurance cards
- 🤖 **AI-powered analysis** — every document is analyzed by Claude Opus using a deep medical billing expert prompt
- 🟢🟡🔴 **Color-coded insight report** — good findings, things worth checking, and items requiring action
- 🚨 **Billing error detection** — automatically flags duplicate charges, unbundling, upcoding, balance billing violations, incorrect deductible application, and more
- ✅ **Action items with urgency** — clear steps ranked high/medium/low, including who to call, what to say, and any appeal deadlines
- 💰 **Spending summary** — annual view of total billed vs. what you actually owe, broken down by document type
- 🛡️ **Insurance tracking** — track your deductible and out-of-pocket progress with visual bars
- ✉️ **Dispute letter generator** — one tap generates a ready-to-mail dispute letter citing the No Surprises Act and applicable patient protections
- 👨‍👩‍👧 **Family profiles** — track documents and spending separately for each family member
- 🔍 **Search** — full-text search across document titles and types
- 🔔 **Analysis notifications** — get notified the moment your document finishes processing
- 🔒 **Face ID / Touch ID lock** — optional biometric lock with configurable 60-second background timeout
- 🏥 **MyChart / Epic FHIR integration** — connect your health system account to auto-populate coverage details (SMART on FHIR with PKCE)
- 📷 **Insurance card scanning** — photograph your insurance card and Claude extracts the plan details automatically

---

## 🏗️ Stack

| Layer | Technology |
|---|---|
| Platform | iOS 17+, Swift 6, SwiftUI |
| AI | Anthropic Messages API (`claude-opus-4-7`), vision |
| API proxy | Cloudflare Workers (keeps API key out of the binary) |
| Health data | Epic FHIR R4 / SMART on FHIR (OAuth2 + PKCE) |
| Document scanning | VisionKit `VNDocumentCameraViewController` |
| State | `@Observable` macro |
| Persistence | FileManager / iCloud Documents directory |
| Auth | `ASWebAuthenticationSession`, `CryptoKit` (SHA-256 PKCE) |
| Biometrics | `LocalAuthentication` (Face ID / Touch ID) |
| Notifications | `UserNotifications` (local push) |

---

## 📁 Project structure

```
Claro/
├── ClaroApp.swift           — app entry point, injects DocumentStore + FHIRService
├── ContentView.swift        — Face ID lock gate + scene phase monitoring
├── LockView.swift           — biometric lock screen with animated UI
├── OnboardingView.swift     — first-launch welcome screen
├── HomeView.swift           — main screen: profiles, insurance, spending, scan, docs
├── ScanView.swift           — camera scan + review + type selection
├── DocumentDetailView.swift — analysis display (🟢/🟡/🔴) + dispute letter trigger
├── DisputeLetterView.swift  — AI-generated dispute letter with share sheet
├── SpendingView.swift       — annual spending breakdown by document type
├── InsuranceSetupView.swift — insurance form with MyChart connect + card scan
├── SettingsView.swift       — Face ID toggle, family profiles, app info
├── UploadPickers.swift      — PHPickerViewController + UIDocumentPickerViewController wrappers
├── Models.swift             — all data models (Codable), Profile, HealthDocument
├── DocumentStore.swift      — @Observable store, FileManager persistence, notifications
├── AnalysisService.swift    — Cloudflare proxy client, card extraction, dispute letter, system prompt
├── FHIRService.swift        — SMART on FHIR auth + Coverage/EOB fetching
├── DesignSystem.swift       — color palette (claroAccent, claroSurface, etc.)
└── Config.swift             — worker URL + secrets (gitignored)

cloudflare-worker/
├── src/index.js             — proxy worker: validates app secret, forwards to Anthropic
└── wrangler.toml            — Cloudflare Workers config
```

---

## ⚙️ Setup

1. Clone the repo and open `Claro.xcodeproj` in Xcode

2. **Deploy the Cloudflare Worker** (keeps your Anthropic key out of the binary):
   - Go to [Cloudflare Workers & Pages](https://dash.cloudflare.com/) → Create Worker → name it `claro-proxy`
   - Paste the contents of `cloudflare-worker/src/index.js` into the editor and Deploy
   - Under Settings → Variables and Secrets, add two secrets:
     - `ANTHROPIC_API_KEY` — your Anthropic key
     - `CLARO_APP_SECRET` — any strong random string you choose

3. Create `Claro/Config.swift` (gitignored):

```swift
import Foundation

enum Config {
    static let workerURL = URL(string: "https://claro-proxy.<your-subdomain>.workers.dev/v1/messages")!
    static let workerSecret = "<your-CLARO_APP_SECRET>"

    enum Epic {
        static let sandboxClientID    = "your-epic-sandbox-client-id"
        static let productionClientID = "your-epic-production-client-id"
        static let redirectURI        = "com.ryancurran.ios.Claro://oauth/callback"
        static let sandboxFHIRBase    = "https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4"
    }
}
```

4. Set your development team in the target's Signing & Capabilities tab
5. Build and run on device (VisionKit document camera requires a physical device)

---

## 🏥 Epic FHIR registration

Claro Lens is registered as a patient-facing SMART on FHIR application on [Epic's developer portal](https://fhir.epic.com). Selected R4 APIs include `ExplanationOfBenefit`, `Coverage`, `Patient`, `Condition`, `Encounter`, `Procedure`, `Observation`, `DiagnosticReport`, `DocumentReference`, `MedicationRequest`, `AllergyIntolerance`, `Immunization`, and `Provenance`.

Redirect URI: `com.ryancurran.ios.Claro://oauth/callback`

---

## 🎨 Design

Dark navy design language built around clarity and calm — the opposite of a confusing hospital bill.

| Token | Hex | Use |
|---|---|---|
| `claroBackground` | `#070D18` | App background |
| `claroSurface` | `#0D1525` | Cards |
| `claroAccent` | `#2DD4BF` | Primary teal |
| `claroWarning` | `#FB923C` | Warnings |
| `claroDanger` | `#F87171` | Alerts |

---

## 💡 Why

Things that used to require a team of medical billing coders, insurance advocates, and healthcare attorneys are now buildable by one motivated developer with the right AI. Claro Lens is a labor of love — built to give ordinary people the same quality of billing oversight that was previously only available to those who could afford a professional advocate.

---

## 📄 License

MIT

# Claro

**Medical bills are confusing by design. Claro fixes that.**

Claro is a privacy-first iOS app that acts as your personal health billing advocate. Photograph a medical bill, EOB, lab result, or insurance card — Claro uses Claude AI to translate every line item into plain English, flag potential billing errors, and tell you exactly what to do next.

---

## What it does

- **Scan or upload any health document** — bills, EOBs, lab results, discharge summaries, prescriptions, insurance cards
- **AI-powered analysis** — every document is analyzed by Claude claude-opus-4-7 using a deep medical billing expert prompt
- **Color-coded insight report** — 🟢 good findings, 🟡 things to check, 🔴 items requiring action
- **Billing error detection** — automatically flags duplicate charges, unbundling, upcoding, balance billing violations, incorrect deductible application, and more
- **Action items with urgency** — clear steps ranked high/medium/low, including who to call, what to say, and any appeal deadlines
- **Insurance tracking** — track your deductible and out-of-pocket progress with visual bars
- **MyChart / Epic FHIR integration** — connect your health system account to auto-populate coverage details (SMART on FHIR with PKCE)
- **Insurance card scanning** — photograph your insurance card and Claude extracts the plan details automatically
- **Background analysis** — documents begin processing the moment you save them, not when you open them

---

## Stack

| Layer | Technology |
|---|---|
| Platform | iOS 17+, Swift 6, SwiftUI |
| AI | Anthropic Messages API (`claude-opus-4-7`), vision |
| Health data | Epic FHIR R4 / SMART on FHIR (OAuth2 + PKCE) |
| Document scanning | VisionKit `VNDocumentCameraViewController` |
| State | `@Observable` macro |
| Persistence | `UserDefaults` with `JSONEncoder` |
| Auth | `ASWebAuthenticationSession`, `CryptoKit` (SHA-256 PKCE) |

---

## Project structure

```
Claro/
├── ClaroApp.swift           — app entry point, injects DocumentStore + FHIRService
├── ContentView.swift        — onboarding gate
├── OnboardingView.swift     — first-launch welcome screen
├── HomeView.swift           — main screen: insurance card, scan button, recent docs
├── ScanView.swift           — camera scan + review + type selection
├── DocumentDetailView.swift — gamified analysis display (🟢/🟡/🔴)
├── InsuranceSetupView.swift — insurance form with MyChart connect + card scan
├── UploadPickers.swift      — PHPickerViewController + UIDocumentPickerViewController wrappers
├── Models.swift             — all data models (Codable)
├── DocumentStore.swift      — @Observable store, triggers background analysis on save
├── AnalysisService.swift    — Anthropic API client, card extraction, system prompt
├── FHIRService.swift        — SMART on FHIR auth + Coverage/EOB fetching
├── DesignSystem.swift       — color palette (claroAccent, claroSurface, etc.)
└── Config.swift             — API keys (gitignored)
```

---

## Setup

1. Clone the repo and open `Claro.xcodeproj` in Xcode
2. Create `Claro/Config.swift` (gitignored):

```swift
enum Config {
    static let anthropicAPIKey = "sk-ant-..."

    enum Epic {
        static let sandboxClientID    = "your-epic-sandbox-client-id"
        static let productionClientID = "your-epic-production-client-id"
        static let redirectURI        = "com.ryancurran.ios.Claro://oauth/callback"
        static let sandboxFHIRBase    = "https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4"
    }
}
```

3. Set your development team in the target's Signing & Capabilities tab
4. Build and run on device (VisionKit document camera requires a physical device)

---

## Epic FHIR registration

Claro is registered as a patient-facing SMART on FHIR application on [Epic's developer portal](https://fhir.epic.com). Selected R4 APIs include `ExplanationOfBenefit`, `Coverage`, `Patient`, `Condition`, `Encounter`, `Procedure`, `Observation`, `DiagnosticReport`, `DocumentReference`, `MedicationRequest`, `AllergyIntolerance`, `Immunization`, and `Provenance`.

Redirect URI: `com.ryancurran.ios.Claro://oauth/callback`

---

## Design

Dark navy design language built around clarity and calm — the opposite of a confusing hospital bill.

| Token | Hex | Use |
|---|---|---|
| `claroBackground` | `#070D18` | App background |
| `claroSurface` | `#0D1525` | Cards |
| `claroAccent` | `#2DD4BF` | Primary teal |
| `claroWarning` | `#FB923C` | Yellow warnings |
| `claroDanger` | `#F87171` | Red alerts |

---

## Why

Things that used to require a team of medical billing coders, insurance advocates, and healthcare attorneys are now buildable by one motivated developer with the right AI. Claro is a labor of love — built to give ordinary people the same quality of billing oversight that was previously only available to those who could afford a professional advocate.

---

## License

MIT

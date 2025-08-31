# FourTwenty • The Archive

>>Immutable ledger + snapshots

## What’s inside
- Purpose: Portfolio Tagging System
- Artifacts: `/playground` (if applicable), `/powerbi`, `/artifacts` (screens/GIFs), `/gtm` (exports), `/ga4`
- Telemetry: GA4 via GTM (no PII). See Tag Assistant & DebugView screenshots in `/artifacts`.

## Quick start
- Open `/playground/ux_playground.html` locally (`python3 -m http.server 5500`) to trigger events.
- Attach GTM Preview and verify in GA4 DebugView.

## Highlights
- Event taxonomy: `<event_1>`, `<event_2>` with params `<param_a>`, `<param_b>`
- BI views: <2–3 bullets on visuals/insights>

## Broadcast 08302025
- Seeded registry.yaml

version: 1.0.0

labels:
  - { id: launch_derived, text: "Launch-derived", emoji: "🚀" }
  - { id: qa_passed,     text: "Passed QA",       emoji: "✅" }
  - { id: sandbox_bank,  text: "Bank case",       emoji: "🏦" }

projects:
  - id: launch
    name: "The Launch"
    emoji: "🚀"
    type: "template"
    orbit: "Core Systems"
    repo: "https://github.com/you/the-launch"
    archives: []

  - id: archive
    name: "The Archive"
    emoji: "🫀"
    type: "ledger"
    orbit: "Core Systems"
    repo: "https://github.com/you/the-archive"
    archives: []

  - id: signal
    name: "The Signal"
    emoji: "📡"
    type: "tooling"
    orbit: "Core Systems"
    repo: "https://github.com/you/the-signal"
    archives: []

  - id: bank
    name: "The Bank"
    emoji: "🏦"
    type: "sandbox"
    orbit: "Delivery & Insight"
    repo: "https://github.com/you/the-bank"
    archives:
      - date: "2025-09-02"
        tag: "v1.0.0-archive"
        path: "archive/2025-09-02-bank/"
        kpis: { on_time: 0.86, lead_time_days: 6, throughput: 7 }
        labels: ["launch_derived", "qa_passed", "sandbox_bank"]


  

License: MIT

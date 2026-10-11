# Verification — 11 October 2026

## Completed locally

- TypeScript strict type check: passed.
- ESLint: passed.
- Vite production build: passed. The main JS bundle is approximately 686 kB / 199 kB gzip; Vite reports its advisory >500 kB chunk warning. This is not a compilation failure; route/vendor splitting is a future performance improvement.
- Vitest: **26 passing tests**, including role/anonymous boundaries, read-only/missing entitlements, account replacement during a pending write, server-generated IDs, ongoing assignment postcondition verification, score ranges, measurement dates, trend categories, name isolation/redaction, full treatment goal and source provenance, preparation shape, and exclusion of local identity fields.
- Chrome/Playwright: **10 passing browser tests** with all Supabase traffic mocked and non-fixture external requests blocked. Browser exceptions and console errors fail the suite.
  - Desktop patient navigation, exact notification result, back navigation and logout cleanup.
  - Unsaved navigation warning, empty session-note save.
  - Name redaction in outgoing AI payload and included diary context.
  - Read-only clinical editing disabled while local rename remains possible.
  - Both anonymous and non-anonymous Patient Mode denied therapist screens.
  - Phone-width RTL forms/graphs, no horizontal overflow, keyboard focus.
  - Branded login screen and no pre-login backend calls.
  - Completed questionnaire payload: own date, exact answers/interference, `session_id:null`.
  - Desktop/tablet patient overview and view-only patient-authored diary entry.
- Synthetic desktop login, patient overview and tablet diary screenshots visually inspected. Phone questionnaire layout tested programmatically; screenshot available in `test-results/`.
- Existing public homepage inspected by GET/HEAD only; its hosting/routes were not changed.
- Git diff whitespace check: passed. Pre-existing Android changes were left untouched.

## Not performed

No production Supabase calls, real sign-ins, OAuth provider round trips, clinical writes, account creation/deletion, mobile device tests, Cloudflare uploads, public previews or DNS changes were performed. Build/browser checks cannot establish production RLS, function CORS, provider allowlists, quota enforcement or old-row compatibility.

See `CONTRACTS.md` for missing file/deletion/shared-preparation contracts and the assignment-flow discrepancy. See `DEPLOYMENT.md` for the exact callback URLs and separately authorized integration/release checks.

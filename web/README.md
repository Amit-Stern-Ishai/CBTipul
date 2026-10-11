# CBTipul therapist web

Isolated React / TypeScript / Vite application. No mobile, website, database, provider settings, or Edge Functions are changed. Nothing has been deployed.

## Local development

Node 24 and npm are recommended (see `.node-version`).

```sh
cd web
npm ci
cp .env.example .env.local
# Enter the existing project's URL and public/publishable key only.
npm run dev
```

Without configuration the login screen explains the missing configuration and makes no backend requests. Vite's `VITE_*` variables are public build-time values. Never enter a service-role key, provider secret, or OpenAI key.

A configured build uses real Supabase records under the signed-in user's RLS permissions. Do not use real patients for testing without authorization. Tests below use synthetic fixtures exclusively.

```sh
npm run typecheck
npm run lint
npm run test
npm run test:browser
npm run build
npm run preview
```

Browser tests use the locally installed Google Chrome (`channel: chrome`). Install Chrome locally or adjust the test channel to an installed Playwright browser. The tests intercept every Supabase request at `fixture.supabase.invalid`; all other external network requests are blocked. Production auth, clinical records, and account deletion are never invoked by these tests. Screenshots under `test-results/` contain synthetic data only and are ignored by Git.

## Implementation map

- `src/auth/`: Supabase PKCE browser auth, email login/recovery, auth lifecycle, profile name setup.
- `src/data/`: actual Supabase contracts and fresh server permission checks before writes; safe errors; no clinical offline cache.
- `src/domain/`: clinical DTOs, score/date/trend rules, local identities, AI provenance/context.
- `src/ui/`: therapist routes and shared accessible components.
- `src/he.ts`: Hebrew interface copy; `mobile-he.json`: exact selected mobile questionnaire/session/diary strings; `legal-he.json`: current mobile legal/AI-consent text. Review the legal copy's mobile-specific statements before public web launch; the UI separately explains the web's unencrypted local names.
- `public/`: existing brand, official provider assets, Cloudflare response headers and SPA fallback.

TanStack Query stores fetched clinical data in memory only. Auth session/PKCE state, account-scoped legal/AI consent, and explicitly entered patient display names use browser storage. There is no analytics, service worker, record persistence plugin, client OpenAI key, or `dangerouslySetInnerHTML`. Ordinary logout removes this account's names and clears queries and visible clinical state. Browser-local names are not an encrypted vault and do not sync from mobile.

## First-version behavior

- Therapist-only login (email, Google, Apple); anonymous and server-confirmed Patient Mode accounts are denied. Role is established through `get-app-context`, not email/provider metadata. Missing entitlement fails closed for mutations. Existing server allowlist/trial/subscription decisions remain authoritative.
- Patient list/search, generated patient IDs, browser-local names, active status, treatment goal, background notes, overview and patient-specific navigation.
- Session list, typed notes, date/type, create/update/empty-note save, unsaved-navigation warning, anonymization and optional AI analysis saved to `structured_notes`.
- Exact mobile GAD-7/PHQ-9 wording/options, complete 0–3 validation, interference, per-question notes, previous answers by measurement date, patient-level therapist entry, history/results and score/question-trend charts with accessible value tables. Patient-authored results and all diary entries are view-only.
- Ongoing questionnaire/Diary 1/Diary 2 activation and cancellation. Diary 3 history/status is available; new activation remains hidden, matching the current product restriction.
- AI chat uses all available paginated sessions, questionnaires and three diary histories, full treatment goal, sources and explicit unavailable-data markers. No local identity fields are serialized. Known locally entered names are removed before anonymization or AI transport. Existing anonymization and gateway functions enforce processing/quota; no local quota counter.
- Next-session preparation follows the existing `prepare-session` context and section order. This endpoint's current mobile context includes sessions, questionnaires and formulation; diary context is supplied to chat, not invented as a new preparation field. Generated preparation is memory-only; native preparations are device-local and cannot sync with this client.
- Notifications resolve exact questionnaire/diary IDs, show unavailable destinations safely, mark opened records read, and refresh in the foreground. Therapist messages use the existing message function/history. No browser push registration has been added.

See [CONTRACTS.md](CONTRACTS.md) for evidence and limitations and [DEPLOYMENT.md](DEPLOYMENT.md) for the review-only Cloudflare setup and release checklist.

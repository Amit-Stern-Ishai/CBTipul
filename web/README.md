# CBTipul therapist web

The web app is a focused therapist workspace: sign in, start or resume one draft, enter a combined GAD-7/PHQ-9 questionnaire, any number of the three diary types, and session notes, then finish and save. Completed work awaits association in the mobile app. Public legal pages, invitation and store links, and auth callbacks remain available. The web UI has no patient list, history, notification feed, or completed-workspace browser.

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

```sh
npm run typecheck
npm run lint
npm run test
npm run test:browser
npm run build
```

Browser tests use synthetic Supabase fixtures and block other external requests. They do not validate a live workspace RPC deployment.

## Workspace contract and privacy

The editor calls only `get_active_web_workspace`, `begin_web_workspace`, `renew_web_workspace_lease`, `save_web_workspace`, `finish_web_workspace`, and `discard_web_workspace` for clinical workspace data. The existing `get-app-context` auth gate remains in place. The app does not query `web_workspaces` directly or call the mobile inbox and association RPCs.

Original clinical wording stays in memory while the tab is open. Before each workspace save, the client sends changed session notes and questionnaire notes through the existing guarded `anonymize-clinical-text` Edge Function (`src/data/api.ts`), using its existing `{ text, therapistIdentifiers: [] }` request, therapist access check, consent key, and local-name redaction. Diary 1, 2, and 3 text bypasses both the anonymizer and local name redaction and is saved exactly as entered. Only successfully anonymized notes are included alongside the original diary text in `save_web_workspace`. Unchanged notes reuse their in-memory anonymized result; retries resend the exact snapshot. The original stays visible until the tab closes; reopening loads the last server snapshot, including original diary wording. Previously anonymized diaries cannot be reconstructed. A failed anonymization prevents the save. This is an AI-based anonymization workflow, not a guarantee that every identifier is removed; review its live privacy behavior before release.

The workspace feature keeps no clinical content in browser storage. It retains only an editor ID, account/workspace-scoped reminder timing, and a nonclinical marker for an uncertain finish; legacy workspace recovery entries are removed. Unsaved original text is lost on tab close. The app warns before navigation where the browser allows it. A same-tab lost save response retries the exact anonymized payload; after tab close, recovery comes from the server snapshot. An uncertain finish can be checked after reopening without persisting a lease token or reference label.

Diary 2 and 3 start with an unaddressed thinking-error field (`null`). The therapist may explicitly confirm “לא זוהתה טעות חשיבה”, which saves `thinking_errors: []`, or select existing supported codes. The currently deployed SQL still rejects an empty array at finish. The corresponding backend patch must be applied and verified before this path can complete live.

See [CONTRACTS.md](CONTRACTS.md) for older integration evidence and [DEPLOYMENT.md](DEPLOYMENT.md) for the Cloudflare release checklist. Neither document proves the new workspace RPCs are deployed; validate them against a configured Supabase environment before release.

Brand tokens reuse the mobile light palette from `ios/Theme.swift` and `android/app/src/main/java/com/cbtipul/app/ui/theme/Color.kt`, with their gold accent and existing `public/brand.png` asset. Questionnaire thresholds and Hebrew severity labels follow `ios/Models.swift` and `ios/Localization.swift`. No backend score fields are added.

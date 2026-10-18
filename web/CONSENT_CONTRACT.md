# Server consent dependency — proposal, not deployed

## Investigated cause

Before this change, terms acceptance was `localStorage[cbtipul.terms.<user-id>] === "2026-08-29"`; the clinical/AI flag was `localStorage[cbtipul.ai.<user-id>] === "yes"`. Neither had a server lookup or receipt. Mobile stores are likewise explicitly local. These flags are scoped to one browser profile, origin and account. They cannot establish durable acceptance across devices, origins or cleared storage. They should survive a reload on the same origin if storage is retained: the exact trigger of the reported repetition has not been reproduced with the real account. No server consent contract was found in the inspected code/contract documentation. A read-only live API metadata request was unavailable; absence on the deployed backend is not proven.

The updated web ignores and removes legacy acceptance flags rather than migrating them. Login does not imply consent. There is no browser-only fallback.

## Release gate

`VITE_SERVER_CONSENT_ENABLED` defaults to false. With it disabled, public pages, authentication and legal pages remain accessible; the authenticated workspace shows an explicit consent lookup/retry error instead of a fresh acceptance dialog. Do not deploy this client until the backend team supplies/confirms the contract below (or adapts the client to its real existing equivalent), approves required versions, and live validation succeeds. Enabling the variable does not deploy backend infrastructure.

No SQL, RLS, RPC implementation, Edge Function, auth provider or mobile code was changed in this web task.

## Proposed RPC interface

JWT-authenticated therapist only. Determine therapist identity from `auth.uid()`, never a caller-supplied account ID. Authorize ownership and therapist access on the server. Keep independent records per therapist, consent type and required version. Required versions must come from a server allowlist; reject unsupported versions.

`get_my_consent(p_consent_type text, p_required_version text)`

`record_my_consent(p_consent_type text, p_required_version text, p_decision text)`

Decisions: `accepted`, `declined`, `revoked`. Recording should be idempotent for identical decisions so an uncertain response can be retried safely. Use server timestamps. Return the same receipt shape from both RPCs:

```json
{
  "therapist_id": "authenticated-therapist-uuid",
  "consent_type": "terms_privacy",
  "required_version": "2026-08-29",
  "accepted_version": "2026-08-29",
  "accepted_at": "server ISO timestamp or null",
  "revoked_at": null,
  "status": "accepted"
}
```

Status is `accepted`, `required`, `declined` or `revoked`. A valid acceptance requires matching type/version/account, an acceptance timestamp and no revocation timestamp. Missing/new-version acceptance returns `required`; lookup failures must be errors, never `required`. Preserve prior versions/decisions as required by the application's legal policy. Do not resurrect a revoked acceptance by replaying an older decision; serialize decisions or provide equivalent concurrency protection. The server should enforce current consent at clinical/AI processing boundaries as well as client checks.

## Separate consent types and proposed versions

- `terms_privacy`, `2026-08-29`: existing web terms/privacy gate, wording unchanged.
- `clinical_text_processing`, `2026-10-14`: existing workspace-specific anonymization disclosure, wording unchanged. This grants no broader AI use.
- `ai_data_sharing`, `2026-08-29`: separate guard for dormant legacy AI features. No workspace action grants this type. Its required version needs backend/legal approval before those features are exposed.

The dates for newly versioned types are proposals identifying the current checked-in wording, not evidence of an existing server version. The backend owner must approve or replace them before enablement. Public legal content and existing mobile consent behavior are unchanged.

## Client behavior and verification

No accepted decisions or clinical text are stored in recovery storage, analytics or logs. The client deduplicates concurrent lookups but retains no accepted-result cache: each new consent check uses the server. Account changes/logout invalidate pending checks. A late lookup from before a revocation is rejected. Terms consent is checked on workspace entry; clinical consent is checked before changed notes enter anonymization. Existing per-snapshot anonymized-note caching/retry behavior remains intact.

Missing/failed lookup shows explicit retry, not a repeated consent dialog. Failed acceptance does not unlock the workspace or clinical processing. Decline is recorded separately; terms decline signs out, clinical decline leaves content in the current tab. Clinical revocation is available behind active-workspace “איך זה עובד?”. Acceptance waits for an authoritative receipt.

Browser and unit tests simulate this proposed contract. They are not live Supabase verification. Required live checks: authenticated therapist ownership, supported versions, accept/reload/new workspace/login, cross-account isolation, decline/revoke/reaccept, uncertain persistence responses, concurrent revocation, and processing-boundary enforcement.

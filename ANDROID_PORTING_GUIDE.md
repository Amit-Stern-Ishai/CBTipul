# CBTipul Android porting guide

Port the existing iOS app (`ios/`) to Android as a **feature-and-contract replica**, not a rewrite of the product. Keep the same Supabase project, tables, Edge Functions, JSON shapes, privacy rules, and Hebrew RTL UX.

Do **not** share OpenAI keys with the client. All AI traffic stays on the existing Edge Functions.

---

## 1. Product to replicate

CBTipul is a Hebrew, right-to-left CBT therapy companion for clinicians.

Signed-in therapists can:

- Manage patients (local-only names) and session notes
- Record voice notes, transcribe via Whisper, then anonymize before display/save
- Score GAD-7 + PHQ-9 questionnaires
- Run AI session analysis, next-session prep, formulation challenge, “what am I missing”, longitudinal review, and a patient-scoped chat
- Accept terms, AI data-sharing consent, and delete the account via an Edge Function

Root navigation (iOS `ContentView`):

1. Splash (~1.5s while session restores)
2. `AuthView` if unsigned in
3. Blocking `TermsView` if this account has not accepted terms
4. `PatientListView` when authenticated + terms accepted
5. Password-recovery sheet when a `cbtipul://password-reset` link signs the user in

Force **RTL at the platform layer**, not only in Compose. iOS sets `UIView.appearance().semanticContentAttribute = .forceRightToLeft` because UIKit-backed fields otherwise flip to LTR on focus.

---

## 2. Recommended Android stack

| Concern | iOS | Android |
|---|---|---|
| UI | SwiftUI | Kotlin + Jetpack Compose + Material 3 |
| Navigation | `NavigationStack` + sheets | Navigation Compose |
| App state | `@Observable` `AuthManager` / `PatientStore` | Hilt + `ViewModel` + `StateFlow` |
| Backend SDK | [supabase-swift 2.54.1](https://github.com/supabase/supabase-swift) | [supabase-kt](https://github.com/supabase-community/supabase-kt) on the same API version family |
| Secure names | iCloud Keychain (`CBTipul.patient-names`) | Android Keystore + EncryptedSharedPreferences (or SQLCipher). **No iCloud equivalent** — names will not roam across Android devices unless you add a later sync design |
| Disk cache | `URL.cachesDirectory` + `.completeFileProtection` | Encrypted files under app cache/files (`EncryptedFile` / Tink) |
| Preferences | `UserDefaults` / `@AppStorage` | DataStore |
| Audio | AVAudioRecorder `.m4a` AAC 44.1 kHz mono | `MediaRecorder` / `AudioRecord` writing **AAC in MPEG-4 (`.m4a`)**. Whisper Edge Function expects `Content-Type: audio/m4a` |
| Deep links | `cbtipul://auth-callback`, `cbtipul://password-reset` | Intent filters for the same custom scheme; also add the URLs to Supabase Auth redirect allowlist |
| Strings | `Localization.swift` (`L10n`) | `res/values-iw/strings.xml` as default copy; keep keys 1:1 with `L10n` |
| Tests | `CBTipulTests/ClinicalTextGateTests.swift` | Port the gate tests first |

Min SDK: 26+ (Keystore + EncryptedSharedPreferences). Target current Play API.

Package suggestion: `com.cbtipul.app` (iOS bundle is `com.CBTipul.app`).

---

## 3. Module map (keep this layering)

Mirror iOS files; do not invent a new domain model.

| iOS source | Android equivalent | Notes |
|---|---|---|
| `ContentView.swift` | `CbTipulApp` + `RootNav` | Splash, auth, terms gate, password-reset sheet |
| `AuthManager.swift` | `AuthRepository` + `AuthViewModel` | Email/password only. OAuth is stubbed on iOS — do not ship Google/Facebook unless iOS does |
| `AuthView.swift` | `AuthScreen` | Sign in / sign up / verify email / resend / forgot password / password rules |
| `PatientStore.swift` | `PatientRepository` | **Single write path to Supabase.** Owns `ClinicalTextGate` |
| `Models.swift` | `model/` | `DatabaseID`, `Patient`, `Session`, `SessionType`, questionnaires, formulation |
| `PatientIdentityStore.swift` | `PatientIdentityStore` | Names never go to the backend |
| `ClinicalTextAnonymizer.swift` | `ClinicalTextAnonymizer` + `ClinicalTextGate` | Abort save on failure; never upload original text |
| `WhisperService.swift` | `AiService` / split by function | Transcription + structured AI JSON |
| `SupabaseChatService.swift` | `ChatGateway` | `openai-gateway`, model `gpt-4o-mini` |
| `PatientContext.swift` | `PatientContext` | Snake_case JSON, **no names / no database IDs** |
| `AIPrompts.swift` | `AiPrompts` | Copy prompts verbatim |
| `AIDataSharingConsent.swift` | `AiConsentStore` | Per-account, local only; every AI call awaits grant |
| `VoiceNoteRecorder.swift` | `VoiceNoteRecorder` | Mic permission; local temp file |
| `Theme.swift` | `Theme.kt` + `Color.kt` | Dark navy + gold default; light = Material system |
| `Localization.swift` | `strings.xml` | Hebrew values unchanged |
| `SettingsView.swift` | `SettingsScreen` | Appearance, text size, AI typing style, legal, sign-out, delete account |
| Tests | `ClinicalTextGateTest` | Same skip/anonymize/fail semantics |

### Screens to port 1:1

`SplashView` → `PatientListView` → `AddPatientView` → `PatientDetailView` → `PatientSessionsView` → `SessionEditorView` → `SessionAnalysisView` → `PatientQuestionnairesView` → `QuestionnaireView` → `NextSessionPreparationView` → `PatientAIView` → `SettingsView` / `TermsView` / `PrivacyPolicyView`.

Also port shared chrome: `BusyOverlay`, `NotesField`, `ScoreCapsule`, `InitialsAvatar` / `PatientAvatarColor`, `GroupBorder`, `DeleteCodeChallenge`, `PressableButtonStyle`.

---

## 4. Auth and deep links

Supabase Auth (email + password):

| Action | iOS API | Redirect |
|---|---|---|
| Sign in | `signIn(email, password)` | — |
| Sign up | `signUp(..., redirectTo: cbtipul://auth-callback)` | Returns whether email confirmation is required (`session == nil`) |
| Resend | `resend(type: signup, emailRedirectTo: auth-callback)` | Map rate limit to the Hebrew “too many requests” string |
| Reset | `resetPasswordForEmail(..., redirectTo: cbtipul://password-reset)` | Opening the link creates a session; show new-password UI |
| Callback | `client.auth.session(from: url)` | Host `auth-callback` vs `password-reset` |
| Update password | `update(user: UserAttributes(password:))` | Clears recovery flag |
| Sign out | `signOut()` + clear local caches | |
| Delete account | `functions.invoke("delete-account")` then sign out + `wipeLocalData()` | |

Normalize emails: trim + lowercase before Auth calls.

Map `email_not_confirmed` to `L10n.emailNotConfirmedError`, never the raw server string.

Add Android intent filters:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="cbtipul" android:host="auth-callback" />
</intent-filter>
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="cbtipul" android:host="password-reset" />
</intent-filter>
```

Register the same URLs in the Supabase dashboard redirect allowlist.

---

## 5. Database contract (do not invent columns)

All IDs are `DatabaseID`: JSON may be **integer or UUID/text**. Filter with `id.queryValue` (string form).

### `Patients`

Select: `id, active, notes, formulation`.

Insert: `{ "active": Bool }` — **no name**.

Update notes / formulation separately. After update/delete, **select the affected rows back**. RLS can “succeed” with zero rows; treat that as `updateRejected` (`L10n.updateRejectedError`).

Null `formulation` on fetch must **not** clear a local formulation (legacy rows).

### `Sessions`

Select: `id, patient_id, session_date, notes, type, structured_notes`.

`type` raw values:

`first_phone_call`, `intake`, `psycho_education`, `diary_one`, `diary_two`, `diary_three`, `case_formulation`, `behavioral_interventions`, `relapse_prevention_and_termination`.

Dates: write `yyyy-MM-dd` (`en_US_POSIX`). Parse date-only first, then ISO-8601 with/without fractional seconds.

`structured_notes`: fail-soft — if old JSON does not decode, drop that field and still load the session.

Encode `type: null` explicitly on update so clearing the stage writes SQL NULL (do not omit the key).

### `CombinedMood`

Table name constant: `CombinedMood`.

Upsert on conflict `session_id`.

Columns used: `patient_id`, `session_id`, `answered_date`, `gad7_answers`, `phq9_answers`, `interference_level`, `combined_notes`.

`combined_notes` JSON: `{ "gad7": [String], "phq9": [String], "interference": String? }`.

Pad/truncate answer and note arrays to the GAD-7 / PHQ-9 question counts from `L10n`.

---

## 6. Local storage and privacy (highest-risk port)

These rules are product requirements, not iOS accidents.

### Patient names

- Live **only** in `PatientIdentityStore`.
- Service key: `CBTipul.patient-names`, account = patient ID string, value = UTF-8 name.
- `displayName` uses **local name only**. If Keychain/EncryptedPrefs read fails, show `L10n.unnamedPatient` — **no backend name fallback**.
- Save the backend name into the identity store on create (`upsertIdentities`) so a later backend that drops names does not wipe local ones. Never save an empty name.
- Delete the mapping only on real patient delete or account wipe — never when pruning a list after load.

**Android gap:** iOS marks items `kSecAttrSynchronizable` (iCloud Keychain). Play has no equivalent. Document this in settings/privacy copy if therapists use both platforms. Do not send names to Supabase to “fix” sync.

### Clinical text gate

Every free-text field that leaves the device must pass `ClinicalTextGate` inside `PatientRepository`:

1. Empty → persist `null` / omit
2. Text already `markSafe` (loaded from server, or returned by anonymizer, or fresh AI output registered via `registerAIAnalysis`) → persist unchanged
3. Else call `anonymize-clinical-text`
4. On any failure: **abort the whole save**. Never upload the original.

Gate session notes, patient notes, formulation fields, CBT cycle strings, questionnaire notes, and editable analysis fields.

Fresh Whisper transcripts are anonymized **before** they appear in the notes field (`anonymizedText`), so a later save does not call the function twice.

### Caches

| File | Contents | Protection | Cleared |
|---|---|---|---|
| `patients-cache.json` | Patients + sessions + formulation | encrypted at rest | sign-out, account delete |
| `preparation-<patientId>.json` | Last next-session prep | encrypted at rest | patient/account delete |
| In-memory questionnaires | keyed by patient ID | — | sign-out |
| AI chat transcript | memory only while `PatientAIView` is open | — | leaving the screen |

Terms: `hasAcceptedTerms-<email>` (DataStore).

AI consent: `aiDataSharingConsentAccepted-<email>` and `...Declined-<email>`. Decline is remembered but a later AI action **asks again**. Switching accounts swaps the stored decision. Declining mid-request is a silent cancel (`userFacingMessage == nil`), not an error alert.

Settings DataStore keys: `appTextSize`, `appAppearance` (default **dark**), `aiResponseStyle` (`typing` | `regular`).

---

## 7. Edge Functions

Auth header: user’s access token. Anon key is the publishable client key (same as iOS `SupabaseConfig`).

Call `AIDataSharingConsentStore.ensureGranted()` **before** every function below.

| Function | How iOS calls it | Body / headers | Response |
|---|---|---|---|
| `whisper-transcribe` | `functions.invoke` | Raw audio bytes; `Content-Type: audio/m4a`; `x-language: he` | `{ "text": String }` |
| `anonymize-clinical-text` | invoke | `{ text, therapistIdentifiers }` (`therapistIdentifiers` currently `[]`) | `{ anonymizedText, usage? }` — empty result is failure |
| `analyze-session` | **raw HTTP POST** to `/functions/v1/analyze-session` | JSON `{ "sessionNotes": String }`; `Authorization: Bearer <accessToken>` | Session analysis envelope — match iOS decoder (`session_summary`, `key_situations`, …). Missing `assignments_for_next_week` → `[]` |
| `prepare-session` | invoke | `{ patientContext, lastSessionAssignments? }` | `{ preparation, usage: { totalTokens } }` |
| `challenge-formulation` | invoke | `{ patientContext, formulation }` | supervision object **directly** (no envelope) |
| `what-am-i-missing` | invoke | `{ patientContext }` | findings list may be empty |
| `longitudinal-case-review` | invoke | `{ "patientContext": PatientContext }` | longitudinal review |
| `openai-gateway` | invoke | `{ model: "gpt-4o-mini", messages, temperature }` | OpenAI chat completions shape; take `choices[0].message.content` |
| `delete-account` | invoke | empty | then local wipe |

HTTP errors from functions: decode `{ "error": String }` when present (iOS `APIError.server`).

`PatientContext` must stay de-identified. Open follow-ups are sent only in `openFollowUps`, not duplicated inside reviews.

---

## 8. Feature behavior to preserve

### Patients list

Load disk cache first if memory is empty, then network. Update **existing objects in place** so editors do not fork the graph.

Sort: active first, then `displayName` localized case-insensitive.

Pull-to-refresh.

### Patient detail

Voice note → transcribe (he) → anonymize → append to notes.

Unsaved-changes back warning if notes dirty or a recording is not transcribed.

Treatment goal edits save immediately via formulation.

Prepare-next-session: include last session’s assignments only (not aggregated). Cache locally. Mark outdated if a session exists with `date > generatedAt` and `date < startOfToday`.

Delete patient: confirmation + 8-char type-back code (`ABCDEFGHJKLMNPQRSTUVWXYZ23456789`, skip 0/O/1/I).

### Sessions

Questionnaire scores on rows; editor with type picker, notes + voice, analysis, follow-up triage (`discussed` / `follow_up` / `not_relevant`).

Register AI analysis as safe before save.

### Questionnaires

GAD-7 then PHQ-9, answers `0...3` optional (nil ≠ 0), interference question, per-question notes.

Severity colors: GAD-7 / PHQ-9 thresholds in `Models.swift` (`Theme.success` / `warning` / `error`).

History + chart of scores over time.

### AI chat

WhatsApp-style bubbles. Each turn sends **full patient context + conversation**. History is not persisted. Optional typing reveal vs full answer (`aiResponseStyle`).

### Settings / legal

Port `L10n.termsBody` and privacy body as structured sections (see `LegalDocumentView`). Blocking agree after sign-in.

Account deletion uses the same code challenge, then `delete-account` + wipe names, preps, and caches.

---

## 9. UI / a11y

- Default appearance: dark navy (`Theme.base` `#07080F` family) + gold accent `#CFA038`. Light mode uses platform grouped backgrounds, not a custom light navy.
- Portrait phone; tablet can allow landscape (iOS already does on iPad).
- App text size overlay on system font scale (`small` … `huge`).
- Mic permission copy: match `NSMicrophoneUsageDescription` (“CBTipul uses the microphone to record voice notes for therapy sessions.”) in Hebrew in Play listing + runtime prompt.
- Healthcare category; no encryption-export issues beyond HTTPS.

---

## 10. Implementation phases

Ship in this order so privacy invariants exist before AI.

1. **Shell** — Gradle app, Compose, RTL, theme, `L10n` strings, splash, DataStore settings keys.
2. **Auth** — supabase-kt, email flows, deep links, terms gate, session restore.
3. **Patients** — identity store, list/add/rename/delete, cache, RLS empty-row checks.
4. **Sessions + notes** — CRUD, date parsing, fail-soft structured notes.
5. **Voice** — record `.m4a`, playback, Whisper, then gate-anonymize before UI.
6. **Questionnaires** — CombinedMood upsert, padding, scores, chart.
7. **Text gate** — wire **all** writes; port `ClinicalTextGateTests`.
8. **AI** — analyze-session (raw HTTP), prepare-session, formulation tools, chat gateway, consent sheet.
9. **Account** — settings, legal docs, delete-account + wipe.
10. **Parity pass** — same JSON fixtures against iOS decoders; Hebrew copy; RTL fields; offline cache; consent switching users.

Do not add OAuth, name sync, or new tables in the first Android release.

---

## 11. Parity checklist

- [ ] Email confirm + password reset round-trip on a physical device
- [ ] Patient names survive process death and are absent from Charles/Proxyman payloads
- [ ] Failed anonymization leaves Supabase row unchanged
- [ ] Unchanged server text does not call `anonymize-clinical-text` again
- [ ] AI blocked until this account accepts consent; other account on same device does not inherit it
- [ ] Whisper body is `audio/m4a`, language `he`
- [ ] `analyze-session` uses user JWT, not only anon key
- [ ] Update/delete with no returned row surfaces `updateRejected`
- [ ] Old `structured_notes` / cache / preparation JSON does not crash the fetch
- [ ] Chat is gone after leaving the screen
- [ ] Account delete removes Keystore names and encrypted caches

---

## 12. What not to copy blindly

| iOS detail | Android approach |
|---|---|
| `@Observable` class identity for `Patient`/`Session` | Stable IDs + single source of truth in the repository; avoid Compose remembering stale copies |
| iCloud Keychain sync | Local-only names; call this out |
| `UIView.appearance` RTL | `android:supportsRtl="true"` **and** `LocalLayoutDirection` / activity `layoutDirection` forced RTL |
| `completeFileProtection` | EncryptedFile; files in cache are still wiped on uninstall (iCloud names are not) |
| `functions.invoke` for analyze-session | Match iOS: **raw POST** |
| Comments that formulation is “cache only” | Persistence follows `PatientStore.saveFormulation` (column `formulation`) |

Config lives in iOS `SupabaseConfig.swift`. Put Android URL + publishable key in `local.properties` / BuildConfig; do not commit a second copy if you can avoid it.

Source of truth for wording: `ios/Localization.swift`. Translate keys to `strings.xml`; do not rewrite Hebrew clinical copy.

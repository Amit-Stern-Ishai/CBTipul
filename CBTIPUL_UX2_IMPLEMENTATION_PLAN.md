# CBTipul UX 2.0 — Implementation Plan (iOS)

**Status:** PLANNING ONLY. No application, navigation, or backend code has been changed.  
**Scope:** Map the proposed therapist TabView / Patient workspace onto the current SwiftUI iOS app.  
**Companion inventory:** `CBTIPUL_CURRENT_UX.md` (current product snapshot).  
**Non-goals for this pass:** implement TabView, move views, SQL/RLS/RPC/Edge Functions, schema or contract changes, opportunistic fixes.

---

## A. CURRENT ARCHITECTURE MAPPING

### App / root routing

| Piece | File / type |
|---|---|
| App entry | `ios/ContentView.swift` — `MyApp`, `ContentView` |
| URL / Universal Links | `MyApp.handleIncomingURL`, `onContinueUserActivity` |
| Invitation parse | `ios/InvitationLink.swift` |
| Root destination enum | `ios/AppRootRouting.swift` — `AppRootDestination`, `AnonymousPatientDestination` |
| Invitation overlay | `ios/PatientInvitationFlow.swift` + `PatientInvitationFlowView.swift` |
| Auth | `ios/AuthView.swift`, `ios/AuthManager.swift` |
| Splash | `ios/SplashView.swift` |
| Terms | `ios/TermsView.swift`, `TermsAcceptance` |
| Welcome | `ios/WelcomeOnboardingView.swift` |
| Onboarding flags | `ios/OnboardingStore.swift` |
| Display-name gate | `ios/TherapistDisplayNameEditorView.swift`, `ios/TherapistProfile.swift` |
| Patient Mode root | `ios/PatientModeView.swift`, `ios/PatientModePlaceholderView.swift` |
| App context | `ios/AppContext.swift` — `get-app-context` Edge Function |
| Environments | `PatientStore`, `TherapistProfileService`, `AppContextService`, `PatientInvitationFlow`, `DiaryOneStore` |

**Therapist home today:** after gates, `ContentView.therapistSessionRoot` returns **`PatientListView()` only**. There is no TabView. Settings is a **sheet** on the patient list. Patient Mode is a **separate** `NavigationStack`, never nested in therapist navigation.

**Push registration gate:** `ContentView.pushRegistrationContext` — therapist after Terms + Welcome + display-name resolved; patient after active Patient Mode.

### Therapist root navigation

- `PatientListView`: owns `NavigationStack(path:)` with `navigationDestination(for: Patient.self)` → `PatientDetailView`.
- `GettingStartedRouter` is `@State` + `.environment` on `PatientListView` only.
- Demo consent fullScreenCover, Settings sheet, Add Patient sheet, showcase intro host (`showcaseIntroHost()`) all live on `PatientListView`.
- `demoModeChrome()` (`ios/DemoModeBanner.swift`) applied on many therapist screens; coach card is a bottom inset **on those screens**.

### Patients list

- `ios/PatientListView.swift` — `PatientListView`, private `PatientRow`.
- Rows today show: local `displayName`, last session type/date + count, **GAD-7/PHQ-9 capsules**, status **dot** on avatar.
- Search when `patients.count > 7`.
- Sort: Active first, then alphabetical (`PatientStatus.active` / `.inactive` in `ios/Models.swift`).
- Add: toolbar `+` and gold bottom CTA (`AddPatientView` sheet).
- Names: `Patient.displayName` ← Keychain `PatientIdentityStore` + App Group `PatientNameResolver`. **No backend name fallback.**

### Patient Detail

- `ios/PatientDetailView.swift` — single `List` hub.
- Header: name + edit sheet, treatment goal (`patient.formulation?.treatmentGoal`) + edit sheet, `StatusBadge`.
- Status picker (immediate persist).
- Nav rows: Sessions, Questionnaires, Diary 1, AI, Invite, Prepare next session, Last preparation.
- Large patient-level notes + voice (`VoiceNoteRecorder`).
- Overflow: delete patient + save notes toolbar.
- Invitation: `PatientInvitationService.create-patient-invitation` + `ActivityShareSheet`.
- Preparation: `SavedPreparation` / `NextSessionPreparationView` / `WhisperService.prepareNextSession`.

### Patient Sessions / Session editor

- `ios/PatientSessionsView.swift` — month-grouped list; sheets for `SessionEditorView`; optional questionnaire sheet via `SessionsInitialAction`.
- `ios/SessionEditorView.swift` — create/edit; notes/voice; AI analysis sheet; therapist questionnaire; **send questionnaire** via `request-patient-questionnaire`.
- `ios/Models.swift` — `Session` (`date`, optional `type`, `notes`, `structuredNotes`, `databaseID`).
- Dates are **date-only** in UX (graphical DatePicker, Hebrew locale). Future dates exist and are already excluded from `sessionsUpToTodayCount`.

### Questionnaires / graphs

- Therapist fill: `ios/QuestionnaireView.swift` — `CombinedMoodQuestionnaireView`, `CompletedQuestionnaireView`.
- History + graphs: `ios/PatientQuestionnairesView.swift` — segmented List | Graphs.
- Charts: **private** `QuestionnaireChart` in the same file (`Swift Charts`).
- Score chips: `ios/ScoreCapsule.swift` (already used on Detail header and list rows).
- Data: `PatientStore.questionnairesByPatient` / `loadQuestionnaires` / `saveQuestionnaire`.
- Patient submit: `PatientQuestionnaireView` + `PatientAssignmentService.submitPatientQuestionnaire`.

### Diaries

- Diary 1 therapist: `ios/DiaryOneViews.swift` (`PatientDiaryOneView`, `DiaryOneEntryFormView`), `ios/DiaryOne.swift`, `ios/DiaryFeeling.swift`, `ios/DiaryFeelingViews.swift`.
- Diary 1 patient: `ios/PatientDiaryOneEntryView.swift`, `ios/PatientDiaryOne.swift`.
- Assignment: `PatientAssignmentService.activeOngoingAssignment` / `activateOngoingAssignment` / `cancelOngoingAssignment` for types `.diaryOne` and **`.diaryTwo`** (service-level). Connection: `is_patient_connected` RPC.
- Diary 2: **Patient Mode placeholder card only** (`PatientModeView` `case .diaryTwo, nil`). **No therapist Diary 2 screen.** Session **type** `.diaryTwo` exists as a protocol label.
- Diary 3: **Session type only** (`SessionType.diaryThree`). **Not** a `PatientAssignmentType`. No views, no entries table client.

### AI / preparation

- Chat: `ios/PatientAIView.swift`, `ios/SupabaseChatService.swift`.
- Session analysis: `ios/SessionAnalysisView.swift`, `WhisperService.analyzeSession`.
- Preparation: `ios/NextSessionPreparationView.swift`, `SavedPreparation` (local file / `DemoClinicStore`).
- Consent: `ios/AIDataSharingConsent.swift`.
- `challengeFormulation` / `whatAmIMissing` / `longitudinalCaseReview`: **NO_UI**.

### Invitation / connection

- Create: `ios/PatientInvitation.swift`.
- Flow: `PatientInvitationFlow` + views.
- Connection check: `PatientAssignmentService.isPatientConnected` → RPC `is_patient_connected` (boolean; **not** stored on `Patient`).
- Demo patients treated as not connected in Diary 1 UI.

### Settings

- Therapist: `ios/SettingsView.swift` — **wraps its own `NavigationStack`**, leading Back uses `dismiss()` (sheet assumption).
- Presented from `PatientListView` `.sheet`.
- Demo guide: `onboarding.requestDemoConsent()` — **intentionally does not dismiss itself**; list observes `wantsDemoConsent` and presents Welcome **outside** the Settings sheet.
- Patient: `ios/PatientSettingsView.swift` (still a sheet; out of therapist TabView scope).

### Patient Mode

- `PatientModeView`: open `patient_assignments` cards.
- Types: questionnaire (one-shot), diary_one (ongoing), diary_two/unknown → upcoming placeholder.
- Activation: `PatientActivationIncompleteView`, `PatientContextRetryView`.

### Push / NSE / deep links

- `ios/PushNotificationManager.swift` — permission, APNs, `register_push_device` / `unregister_push_device` RPCs, token in UserDefaults.
- `AppDelegate` in `PushNotificationManager.swift` — `willPresent` only; **no tap handler**.
- `ios/PatientPushPersonalizer.swift` — types `patient_connected`, `questionnaire_completed`; IDs `patientId`/`patient_id`, `assignmentId`, `sessionId`.
- `NotificationService/NotificationService.swift` — NSE personalization.
- Names: `PatientNameResolver` App Group.
- Universal Links: `https://cbtipul.com/invite/<TOKEN>` only.
- Custom scheme: `cbtipul://auth-callback`, `cbtipul://password-reset`.

---

## B. PROPOSED FIVE-TAB ARCHITECTURE

### Recommended owner

Introduce **`TherapistRootView`** as the **only** replacement for today’s `PatientListView()` in `ContentView.therapistSessionRoot` **after** the existing gates:

```
ContentView
  invitation → PatientInvitationFlowView
  anonymous → Patient Mode / incomplete / retry / loading
  unauthenticated → AuthView
  therapist gates → display name / Terms / Welcome
  else → TherapistRootView   // NEW — TabView lives here only
```

Do **not** put TabView above invitation, Auth, Terms, Welcome, or Patient Mode.

### TabView + NavigationStack

**Safest pattern for this codebase:** `TabView` with **five tabs**, each owning **its own** `NavigationStack`. Do not share one stack across tabs (that fights SwiftUI tab state and would break `PatientListView`’s existing `NavigationPath`).

| Tab | Title | Root view | Stack |
|---|---|---|---|
| 1 | מטופלים | Existing `PatientListView` (gear removed) | Keep current `NavigationStack(path:)` |
| 2 | פגישות | New `GlobalSessionsView` | New stack |
| 3 | התראות | New `NotificationsInboxView` (phase-empty then client routing) | New stack |
| 4 | ספרייה | New `LibraryPlaceholderView` | New stack (or no stack if no pushes) |
| 5 | הגדרות | `SettingsView` adapted for tab (see §J) | Prefer **one** stack: either strip inner stack from Settings **or** don’t wrap again |

**Selection:** `@State` tab enum on `TherapistRootView`. Preserve each tab’s stack independently (standard SwiftUI: each tab’s view identity stays alive if tabs are always in the tree — use `TabView { ... }` with persistent children, not `switch tab` that destroys stacks).

**RTL:** existing `AppTextSizeModifier` + `semanticContentAttribute = .forceRightToLeft` remain at `ContentView` / UIKit appearance. Tab bar will be RTL automatically. Use `Label` + SF Symbols; add localized tab titles in `Localization.swift` (existing practice).

### Views reused vs new

**Reuse directly:** `PatientListView` (minus Settings sheet/gear), `PatientDetailView` (restructured later), `AddPatientView`, `PatientSessionsView` / `SessionEditorView`, questionnaire/diary/AI/prep/invitation views, `SettingsView` content, `WelcomeOnboardingView`, demo chrome.

**New containers (proposed names, not implemented):**

- `TherapistRootView`
- `GlobalSessionsView` (+ small patient picker sheet/list using `Patient.displayName`)
- `NotificationsInboxView`
- `ActivityHistoryView` (later; push from Notifications — **not** a tab)
- `LibraryPlaceholderView`
- Patient workspace helpers: e.g. `PatientDiariesHubView`, `PatientNotesView`, `SendToPatientSheet` (UI only; options gated by implementation status)
- Graph reuse: extract `QuestionnaireChart` / `PatientQuestionnaireGraphsView` from `PatientQuestionnairesView`

### Gates / Patient Mode / invitation

Unchanged in `ContentView` + `AppRootRouting`. Invitation `isActive` still **replaces the entire root**, including TabView. Anonymous session never instantiates `TherapistRootView`.

### Navigation state

- Patients tab: keep `NavigationPath` as today (Patient → Detail → Sessions/etc.).
- Switching tabs should **not** pop Patients (do not recreate `PatientListView` on every tab change).
- Demo `GettingStartedRouter.wantsPatientListReset` currently resets **list** path/sheets. After TabView, reset must still target the **Patients** stack, not other tabs. Host demo Welcome **on `TherapistRootView`**, not inside Settings tab (same reason as today: cover must not sit under a sheet).
- **No second TabView** inside Patient Detail.
- Deep links later: select Patients (or Sessions) tab then push destination — requires a small **coordinator** on `TherapistRootView` (tab + optional `Patient` / session IDs). Prefer that over a custom global router unless tap-routing ships. Until tap-routing exists, coordinator can wait.

### Demo / Getting Started coupling (architecture warning)

Today coach + demo consent + path reset are **owned by `PatientListView`**. Tabs mean:

- Move `wantsDemoConsent` observer + Welcome `fullScreenCover` + `showcaseIntroHost` to `TherapistRootView`.
- Keep `GettingStartedRouter` in environment from `TherapistRootView` so Sessions/Detail still pulse.
- Settings “Getting Started” must **not** assume it is presented as a sheet over the list (see §J).

---

## C. PATIENT DETAIL MAPPING

Proposed scroll order vs code:

| Proposed element | Current source | Classification | Why |
|---|---|---|---|
| Header — display name | `PatientDetailView` name + `startEditingName` sheet | EXISTING — NEEDS RELOCATION/REFACTOR | Same editor; restyle/reorder only |
| Header — treatment goal | `treatmentGoal` binding / `isEditingGoal` | EXISTING — REUSE DIRECTLY | Already header; keep edit |
| Header — treatment status | `StatusBadge` + status `Picker` | EXISTING — NEEDS RELOCATION/REFACTOR | Picker is a full row today; may keep picker in header or secondary; status model is only Active/Inactive |
| Header — connection | `PatientAssignmentService.isPatientConnected` used on Diary 1 / Session send row | PARTIALLY IMPLEMENTED | Boolean RPC exists; **not** on Detail; **not** cached on `Patient`; list N+1 risk if used naively |
| Disconnected → invite | `startPatientInvitation()` + share sheet | EXISTING — NEEDS RELOCATION/REFACTOR | Move off permanent Invite row into header affordance when disconnected |
| פגישה חדשה | `PatientSessionsView` add session / `SessionsInitialAction.addSession` | EXISTING — NEEDS RELOCATION/REFACTOR | Present same `SessionEditorView` sheet with `patient` already known |
| שליחה למטופל/ת | Questionnaire send on `SessionEditorView`; diary start on `PatientDiaryOneView` | PARTIALLY IMPLEMENTED | UX wants one sheet; **questionnaire is session-linked**; diary is patient-linked ongoing; message/file **NOT IMPLEMENTED** |
| Send: שאלון | `sendQuestionnaireAssignment(patientId, sessionId)` | EXISTING — NEEDS RELOCATION/REFACTOR | Requires a **session** `databaseID`; cannot send without choosing/creating a session unless product changes |
| Send: יומן | `activateOngoingAssignment(..., .diaryOne)` | EXISTING — NEEDS RELOCATION/REFACTOR | Diary 1 only in UI; `.diaryTwo` API exists without therapist/patient product UI |
| Send: הודעה | — | NOT IMPLEMENTED + REQUIRES BACKEND WORK | No models/screens |
| Send: קובץ | — | NOT IMPLEMENTED + REQUIRES BACKEND WORK | No models/screens |
| מעקב והתקדמות preview chips | Detail `ScoreCapsule` + cache | EXISTING — REUSE DIRECTLY | Already on Detail; list rows also have chips (proposal wants them **off** list) |
| גרפים ומגמות destination | `PatientQuestionnairesView` graphs mode | EXISTING — NEEDS RELOCATION/REFACTOR | Graphs are a **segment** inside questionnaires, not a first-class push; `QuestionnaireChart` is `private` |
| שאלונים | List mode of `PatientQuestionnairesView` | EXISTING — NEEDS RELOCATION/REFACTOR | Split modes into two destinations or `initialMode:` |
| מהלך הטיפול → פגישות | `PatientSessionsView` | EXISTING — NEEDS RELOCATION/REFACTOR | Add upcoming / prep / history sections inside this screen (or a thin wrapper) |
| מהלך הטיפול → יומנים | Only Diary 1 nav row | EXISTING — NEEDS RELOCATION/REFACTOR | Hub of 1/2/3; 2/3 not real features yet |
| קשר → הודעות | — | NOT IMPLEMENTED + REQUIRES BACKEND WORK | Client integration point: Patient Detail section + Patient Mode home; no persistence |
| קשר → קבצים | — | NOT IMPLEMENTED + REQUIRES BACKEND WORK | Same |
| כלים → עוזר AI | `PatientAIView` | EXISTING — NEEDS RELOCATION/REFACTOR | Move row into Clinical tools; do not duplicate prep |
| הכנה לפגישה הבאה | Detail buttons | EXISTING — NEEDS RELOCATION/REFACTOR | Move to Patient → Sessions |
| הערות כלליות | Notes + voice on Detail | EXISTING — NEEDS RELOCATION/REFACTOR | Demote to overflow push/`PatientNotesView`; **do not delete data or voice** |
| Delete patient / save notes | Toolbar overflow | EXISTING — REUSE DIRECTLY | Stay in secondary/overflow |
| Formulation (non-goal fields) | `PatientFormulation` | PARTIALLY IMPLEMENTED | Model exists; UI is goal-only; out of this UX proposal |

**Connection on header:** cleanest reuse is **fetch on Detail `.task` / `.refreshable`**, cache in `@State` (or a tiny in-memory cache keyed by patient UUID) — **do not** add a Patient column or new RPC in this UX work. Demo: keep current “not connected” behavior.

**Send sheet (client-only):** present options; enable שאלון/יומן with existing flows; show הודעה/קובץ as disabled “בקרוב” **only if product agrees** — otherwise omit until backend exists (see Questions).

---

## D. GRAPHS

### Current implementation

- File: `ios/PatientQuestionnairesView.swift`.
- Data: same `[CompletedQuestionnaire]` as the list (`store.loadQuestionnaires` / cache).
- Transform: `chartEntries(for:)` — oldest-first `QuestionnaireChart.Entry(date:answers:)` from GAD-7 or PHQ-9 answer arrays.
- UI: private `QuestionnaireChart` — Swift Charts line + metric picker (total vs per-question), severity colors via `GAD7Severity` / `PHQ9Severity`.
- Preview chips on Detail already use `ScoreCapsule` + previous questionnaire — **not** a second chart.

### Safest exposure of גרפים ומגמות

1. **Extract** `QuestionnaireChart` (+ `Entry`) to a dedicated file (e.g. `QuestionnaireChart.swift`) **without changing chart behavior**.
2. Extract a **`PatientQuestionnaireGraphsView(patient:)`** (or add `PatientQuestionnairesView(initialMode: .graphs, showsModePicker: false)`).
3. Patient Detail **prominent** `NavigationLink` → graphs-only screen using **the same** `loadQuestionnaires` / cache.
4. `שאלונים` → list-only (`showsModePicker: false`, mode `.list`) → `CompletedQuestionnaireView` as today.
5. Detail header may keep **ScoreCapsule** preview (existing, not a new charting system). Optional tiny sparkline would be a **second** visualization — **do not** add unless explicitly approved; chips + destination are enough.

**Do not** copy `Chart { }` into `PatientDetailView`.

**Empty/error:** reuse `ContentUnavailableView` / retry from questionnaires view.

---

## E. SESSIONS

### What `Session` actually supports

- `date: Date` (UI treats as calendar day).
- Optional `SessionType` (protocol stage, **not** an appointment type).
- Notes, structured AI notes, optional `databaseID` after save.
- Loaded as children of `Patient` in `PatientStore` (sessions are in memory once patients load).
- **No** start time, duration, calendar, reminders, location, or recurrence.

Upcoming vs history can be derived: `session.date >= startOfToday` vs `< startOfToday` (align with existing `sessionsUpToTodayCount` / preparation “outdated” logic). **Same-day sessions are “up to today” / not future** in current counting. Product should confirm whether “קרובות” includes **today** (recommended: **today + future**, labeled קרובות, matching “what’s next” not “strictly after midnight”).

### Patient → Sessions (`PatientSessionsView`)

| Proposed | Support |
|---|---|
| פגישה חדשה | **Exists** — CTA + toolbar + `SheetRoute.new` |
| פגישות קרובות | **Derivable** — filter `patient.sessions`; compact empty |
| הכנה לפגישה הבאה | **Exists on Detail** — move `prepareNextSession`, `SavedPreparation`, sheets/tips into this screen (pass `patient`) |
| היסטוריית פגישות | **Exists** as the whole list today — split remaining sessions, newest first (already `date >`) |

Keep **SessionEditorView as a sheet** (current pattern). Do not invent a calendar.

Getting Started `SessionsInitialAction` still valid if this view remains the sessions workspace.

### Global Sessions tab

| Proposed | Support |
|---|---|
| Flatten all `store.patients.flatMap(\.sessions)` | **Exists** in memory after `loadPatients` |
| Display names | **Must** use `patient.displayName` / identity store — never invent a second name source |
| פגישה חדשה → pick patient → `SessionEditorView` | New UI; reuse editor with chosen `Patient` |
| מטופל/ת חדש/ה | Reuse `AddPatientView`; on save, continue to new session **if** AddPatient exposes a completion with the created `Patient` (today it only `dismiss()` after save — **small API addition**, not duplicated insert logic) |
| קרובות / אחרונות | Date filters only; cap “recent” in UI if lists are long (client filter, not new backend) |

**Not supported / do not invent:** appointment book, conflicts, week grid, search/filter chrome.

**Gap:** sessions without `databaseID` (unsaved) should not appear in global list (editor only after save). New session from global tab should use the same save path as today.

**Patient picker:** simple list of `store.patients` sorted like Patients tab; local names only.

---

## F. DIARIES

| Type | Therapist UI | Patient UI | Persistence | Assignment API | Classification |
|---|---|---|---|---|---|
| יומן 1 | `PatientDiaryOneView` full CRUD + start/stop Patient Mode | `PatientDiaryOneEntryView` create-only | `diary_one_entries` + `DiaryOneStore` | `activateOngoingAssignment` / `cancel` type `.diaryOne` | **IMPLEMENTED** |
| יומן 2 | None | Placeholder “upcoming” card if assignment type `diary_two` | No diary_two entries client | `PatientAssignmentType.diaryTwo` + `requireOngoingType` allows activate/cancel | **PARTIAL / PLACEHOLDER** — assignment type exists; **no diary product** |
| יומן 3 | None | None | None | **Not** in `PatientAssignmentType` | **MISSING** (session **type** label only) |
| יומן 4 | — | — | — | — | **Must not exist** |

**Hub `PatientDiariesHubView`:** three rows. Diary 1 → existing `PatientDiaryOneView`. Diary 2/3 → **empty/placeholder screens** using existing Patient Mode “upcoming” copy pattern — **do not** implement diary 2/3 features, tables, or Edge Functions in UX 2.0.

Send-to-patient “יומן”: until product specifies which diary, **only Diary 1** should be actionable.

---

## G. NOTIFICATIONS

### CLIENT SUPPORT TODAY

| Concern | Status |
|---|---|
| Permission | `UNUserNotificationCenter.requestAuthorization([.alert, .badge, .sound])` after therapist home or active Patient Mode |
| APNs | `UIApplication.registerForRemoteNotifications` |
| Device token | Hex string in UserDefaults `cbtipul.apnsDeviceToken`; RPC `register_push_device` with environment debug/production |
| Unregister | `unregister_push_device` on sign-out (best-effort) |
| NSE | `NotificationService` + `PatientPushPersonalizer` |
| Foreground | `willPresent`: personalize; if body changed, re-add request and suppress duplicate; else banner/list/sound/badge |
| Types handled for copy | `patient_connected`, `questionnaire_completed` only |
| Payload IDs parsed | `patientId`/`patient_id`, `assignmentId`/`assignment_id`, `sessionId`/`session_id` |
| Notification tap | **None** — no `didReceive response` |
| In-app inbox | **None** |
| Persistent notification store | **None** |
| Read/unread | **None** |
| App icon / tab badge from unread | Authorization includes `.badge` but **app never sets** a managed unread count |
| Diary submitted / group request | **No** personalizer cases, no UI |

### BACKEND/DATA WORK REQUIRED (do not invent in this task)

- Durable inbox of events per therapist.
- Read/unread sync (multi-device).
- Push types beyond the two existing (diary submitted, group request, etc.).
- Guaranteed payload shape for navigation (confirm production payloads always include the IDs the client already knows how to parse).
- Tab badge that survives process death **without** a local-only fake inbox.

### What UX 2.0 can do **without** new backend

1. Empty Notifications tab (reserves IA).
2. Optional: implement **`userNotificationCenter(_:didReceive:)`** to switch tab + push Patient / session / questionnaire using **existing IDs** (cold start via `launchOptions` is extra care).
3. Optional **ephemeral** in-memory list of notifications seen while the process lives — **not** true Activity, **not** unread across launches. Product must accept this limitation or wait for backend.

**Do not** write a local Core Data/SQLite “inbox” that will conflict with a future server inbox unless product explicitly wants a throwaway prototype.

---

## H. ACTIVITY

Activity is **not** a tab; eventual push from Notifications: כל הפעילות.

### What exists that could *partially* reconstruct history

| Event | Incoming / outgoing | Current persistence | Usable for Activity? |
|---|---|---|---|
| Questionnaire sent | Out | `patient_assignments` row (`type=questionnaire`, `created_at`, `session_id`) via `patientAssignments()` | **Partial** — can list assignments if therapist is allowed to select them (already used per-session). No “message body”. |
| Questionnaire completed | In | `completed_at` on assignment + `CompletedQuestionnaire` / combined mood rows | **Partial** |
| Diary 1 enabled | Out | ongoing assignment `diary_one` `created_at` | **Partial** (start, not each send) |
| Diary 1 entry | In (or therapist-created) | `diary_one_entries.created_at` | **Partial** — **cannot distinguish** therapist-added vs patient-submitted from client model alone without extra fields |
| Patient connected | In | Push only; **no client table**. Invite create is Edge Function; token not stored | **Weak** — unless inferred from `is_patient_connected` (boolean, no timestamp) |
| Message sent | Out | **None** | No |
| File sent | Out | **None** | No |
| Session AI / prep | — | Session fields / local prep file | Not “Activity” in the proposed sense |

**Outgoing Activity today is not a first-class log.** Reconstructing a mixed feed would be a **client-side join** of assignments + questionnaires + diary entries — incomplete, unordered vs actual “sent”, and misleading for connection/messages/files.

**Do not** invent Activity persistence in UX 2.0. Notifications tab can omit “כל הפעילות” until data exists, or show a disabled/empty screen.

---

## I. LIBRARY

Library tab can be a **static empty state** (`ContentUnavailableView` + Hebrew copy) with **no** models, folders, or navigation.

**Safe:** does not collide with future groups/content if it remains a placeholder container with a stable tab identity.

**Do not** add mock documents, local files, or group stubs.

---

## J. SETTINGS

| Item | Today |
|---|---|
| View | `SettingsView` |
| Presentation | `PatientListView` sheet; toolbar gear |
| Chrome | Own `NavigationStack`; leading Back `dismiss()` |
| Demo | `requestDemoConsent()`; list presents Welcome and **closes Settings sheet** |
| Display name | `NavigationLink` with `embedsInNavigationStack: false` |
| Legal | in-app `OfficialLinkWebView` sheets |
| Account | sign out, delete account + code challenge |
| DEBUG | test push |
| Missing vs Patient Settings | **No appearance picker** on therapist Settings |

**To become tab 5:**

1. Present `SettingsView` as tab root (not sheet).
2. **Remove** Patients gear + `isShowingSettings` (and all the demo/exit paths that force `isShowingSettings = false`).
3. Change Back button: hide cancellation `dismiss` when used as tab (or use `embedsInNavigationStack` / `presentationStyle` flag). Nested NavigationLinks (text size, terms, display name) must keep working.
4. **Relocate** `wantsDemoConsent` handling to `TherapistRootView` so Getting Started still presents Welcome **over the TabView**, then optionally `selectedTab = .patients`.
5. Patient Mode Settings **stay a sheet** (no therapist tabs).

**Redundant after change:** sheet wrapper, gear toolbar item, list observers that only exist to dismiss the Settings sheet.

**Do not** remove Getting Started, display name, legal, sign out, delete account.

**Optional later (not required for tab):** add Appearance to therapist Settings for parity with Patient Settings — product decision, not required by five-tab IA.

---

## K. PATIENT MODE

**Do not** add the five-tab bar.

| Proposed home block | Current | Classification |
|---|---|---|
| לביצוע — questionnaire | Card + `PatientQuestionnaireView` | EXISTING — REUSE; optional section header copy |
| לביצוע — diary 1 | Card + `PatientDiaryOneEntryView` | EXISTING — REUSE |
| לביצוע — diary 2 | Upcoming placeholder | PLACEHOLDER — keep; do not add Diary 1/2/3 top nav |
| הודעות | — | NOT IMPLEMENTED + REQUIRES BACKEND |
| קבצים | — | NOT IMPLEMENTED + REQUIRES BACKEND |

Preserve: assignment load/refresh, submit semantics, incomplete/retry activation, invitation overlay, `PatientSettingsView` sheet, leave-mode sign-out.

If messages/files are absent, **do not** add empty sections that look broken unless product wants labeled “בקרוב” placeholders. Safer first Patient Mode change: **only** a לביצוע heading around the existing task list.

---

## L. RISK ANALYSIS

**Highest risk (this codebase specifically):**

1. **`ContentView` gates vs TabView** — putting TabView in the wrong branch would show therapist chrome on invitation or Patient Mode. Must replace **only** the current `PatientListView()` leaf.

2. **Demo consent architecture** — Settings currently **must not** present Welcome inside its sheet (`OnboardingStore.wantsDemoConsent` + list cover). A Settings **tab** will flash/wrong-stack if that contract is not moved to `TherapistRootView`.

3. **`GettingStartedRouter` + `NavigationPath` reset** — demo exit / restart currently nukes list path and sheets on `PatientListView`. With tabs, failing to keep router at root will break coach pulses on Detail/Sessions or reset the wrong tab.

4. **`SettingsView` + `dismiss()`** — Back on a tab pops the **entire therapist root** if it still calls `dismiss()`. High chance of “tap Back in Settings → Auth/blank”.

5. **Double `NavigationStack`** — Settings already has a stack; Tab wrapping another stack breaks titles/back.

6. **Session editor sheets + TabView** — sheets from Patients tab should remain attached to the presenting stack. Global Sessions tab will present the same `SessionEditorView`; two tabs must not share one `@State route` accidentally.

7. **Questionnaire send vs “Send to patient” on Detail** — `request-patient-questionnaire` **requires `sessionId`**. A Detail-level send without a session picker will call the Edge Function incorrectly or invent sessions. Workflow break risk.

8. **`is_patient_connected` on every patient row** — N RPC calls, no cache, demo false-negatives. Can stall list / hit rate limits. Prefer Detail-only in first stages.

9. **Local names** — picker/global sessions/notifications must use `displayName` / Keychain / App Group only. Easy to accidentally show `unnamedPatient` or backend fields.

10. **Invitation Universal Link** — still must **preempt** TabView (`invitationActive`). Regression: therapist tabs visible under invite.

11. **Push tap routing into TabView** — without a coordinator, `NavigationLink` from a non-Patients tab cannot push Patient Detail. Cold start has no tap handler today; adding one interacts with splash (1.5s) and gates (Terms/Welcome).

12. **Patient notes demotion** — losing the notes `List` section without a destination **drops voice UX**. Must extract, not delete.

13. **Graphs extraction** — `QuestionnaireChart` is private; sloppy copy-paste creates two implementations (explicitly forbidden).

14. **UI testing** — `ContentView` skips splash and injects demo expecting **patient list IDs** (`patients.root`, `welcome.continueDemo`). Tab bar may break smoke tests.

15. **TabView + `demoModeChrome` bottom coach** — coach is `safeAreaInset(edge: .bottom)` **and** TabView already occupies the bottom. **Overlap / unusable coach / clipped CTA.** Needs a dedicated layout pass (coach above tab bar, or demo-only hide tabs — product/architecture choice).

16. **Anonymous vs therapist on one device** — invitation claim creates anonymous session; TabView must not remain.

---

## M. RECOMMENDED IMPLEMENTATION STAGES

Safer than “build all five tabs with full IA in one PR”: **install the tab shell first with three stubs**, keep Patients behavior identical except Settings location, then refactor Detail, then Global Sessions, then notification tap. Demo/tab-bar collision is staged explicitly.

---

### Stage 0 — Compile/test baseline

- **Goal:** Confirm current app builds; freeze this plan.
- **Files:** none (planning done).
- **Checkpoint:** existing iOS target build; no UX 2.0 code.

---

### Stage 1 — `TherapistRootView` TabView shell (Patients + Settings real; three placeholders)

- **Goal:** Five tabs exist; gates unchanged; Patients + Settings work; Library/Notifications/Global Sessions are empty states.
- **Likely files:** `ContentView.swift` (swap leaf), new `TherapistRootView.swift`, new placeholder views, `Localization.swift`, `PatientListView.swift` (remove gear/sheet; **move** demo consent + showcase host to root), `SettingsView.swift` (tab vs sheet chrome).
- **New files:** `TherapistRootView.swift`, `LibraryPlaceholderView.swift`, `NotificationsInboxView.swift` (empty), `GlobalSessionsView.swift` (empty state “soon” **or** skip content until Stage 5 — still a tab).
- **Reuse:** `PatientListView`, `SettingsView`, Welcome, demo banner.
- **Untouched:** Patient Detail internals, session editor, questionnaires, diaries, Patient Mode, push, backend.
- **Risks:** Settings `dismiss`; demo Welcome host; UI tests; tab + coach overlap (mitigate: keep coach as today on list and **verify** against tab bar immediately).
- **Manual tests:** Auth → Terms → Welcome → **see 5 tabs**; Patients list/add/open detail/back; Settings text size/legal/sign out; Getting Started from Settings presents Welcome **over tabs**; invitation URL still covers tabs; Patient Mode still **no** tabs; demo enter/exit.
- **Build checkpoint:** iOS app compiles; run on device/simulator through gates.

---

### Stage 2 — Patients tab list IA (no Detail rewrite yet)

- **Goal:** Rows scannable: name, last session date/type, optional status; Active vs `טיפולים שהסתיימו` (`PatientStatus.inactive`); **remove score capsules from rows**; keep `+`.
- **Files:** `PatientListView.swift` (`PatientRow`), `Localization.swift`.
- **New files:** none required.
- **Reuse:** sort already Active-first; search >7.
- **Untouched:** connection on rows (defer RPC); Detail; backend.
- **Risks:** therapists who used row scores as glanceable progress — chips remain on Detail.
- **Manual tests:** active vs inactive sections; search; add patient; demo tutorial pulse still finds add/patient.
- **Build checkpoint:** compile + list visual pass.

---

### Stage 3 — Patient Detail IA (workspace scroll, no new backends)

- **Goal:** Header (incl. connection fetch + invite when disconnected); two primary actions; prominent Graphs link; Questionnaires list link; Treatment (Sessions, Diaries hub); Clinical AI; overflow notes; **remove** Invite/Prep/notes blob from primary list; **no** messages/files rows **or** explicit placeholders per product (see Questions).
- **Files:** `PatientDetailView.swift`, extract `PatientNotesView.swift`, `PatientDiariesHubView.swift`, questionnaire view split/extract, `Localization.swift`.
- **New files:** notes view, diaries hub, send sheet (questionnaire/diary 1 only), graph destination wrapper.
- **Reuse:** invitation, `SessionEditorView` sheet, `PatientSessionsView`, `PatientAIView`, `PatientDiaryOneView`, `ScoreCapsule`, `CombinedMoodQuestionnaireView`.
- **Untouched:** Edge Functions, Diary 2/3 features, AI prompts, preparation **move can be Stage 3b** if Detail PR is too large — **preferred split:** 3a layout+graphs+notes demotion; 3b move preparation into Sessions.
- **Risks:** send-questionnaire without session; notes/voice regression; demo coach placements (`.patientDetail`, `.sessionsEntry`).
- **Manual tests:** edit name/goal/status; new session; graphs == old graphs mode; questionnaires list; diary 1; AI; invite from disconnected header; notes via overflow + record/transcribe/save; delete patient; connected header (real connected patient).
- **Build checkpoint:** compile after 3a and 3b separately.

---

### Stage 4 — Patient → Sessions structure

- **Goal:** New Session, Upcoming, Preparation (moved), History on `PatientSessionsView`.
- **Files:** `PatientSessionsView.swift`, `PatientDetailView.swift` (remove prep), possibly share prep helpers.
- **Reuse:** `SavedPreparation`, `NextSessionPreparationView`, tips, `SessionEditorView`.
- **Untouched:** `WhisperService.prepareNextSession` contract; session editor internals.
- **Risks:** Getting Started `initialAction`; outdated badge logic.
- **Manual tests:** future-dated session appears under קרובות; past under history; prepare generate/view/insufficient; open session editor.
- **Build checkpoint:** compile.

---

### Stage 5 — Global Sessions tab (real content)

- **Goal:** Cross-patient upcoming + recent; new session with patient picker; optional add-patient then session.
- **Files:** `GlobalSessionsView.swift`, `AddPatientView.swift` (optional `onCreated: (Patient) -> Void`), `Localization.swift`.
- **Reuse:** `SessionEditorView`, `Patient.displayName`, `PatientStore`.
- **Untouched:** calendar; Patient Mode; push.
- **Risks:** name privacy; unsaved sessions; large lists.
- **Manual tests:** picker shows local names; create session; open existing; add new patient then session; demo patients.
- **Build checkpoint:** compile.

---

### Stage 6 — Notification tap routing (client only, no inbox persistence)

- **Goal:** Implement `didReceive` + cold-start handling: select tab + navigate using existing payload IDs **if** gates already passed. Empty inbox remains unless product wants ephemeral rows.
- **Files:** `PushNotificationManager.swift` / `AppDelegate`, `TherapistRootView` coordinator, maybe `PatientListView` programmatic push.
- **Reuse:** `PatientPushPersonalizer` ID helpers, `PatientStore` lookup by UUID.
- **Untouched:** RPCs, NSE copy, new push types, read state.
- **Risks:** splash/gates; missing IDs; patient not in memory yet; invitation overlay.
- **Manual tests:** tap `questionnaire_completed` → questionnaire or session; `patient_connected` → Patient Detail; tap while on Auth/Welcome does not crash; Patient Mode ignores therapist destinations.
- **Build checkpoint:** compile. **Skip this stage** if coordinator is not ready — empty tab is acceptable.

---

### Stage 7 — Patient Mode copy-only (optional)

- **Goal:** Wrap existing cards in לביצוע. No tabs, no fake messages/files.
- **Files:** `PatientModeView.swift`, `Localization.swift`.
- **Untouched:** assignments, activation.
- **Build checkpoint:** compile.

---

### Explicitly later / not in these stages

- Messages, files, Activity persistence, notification unread sync, Diary 2/3 product, Library content, group requests, formulation tools, appearance on therapist Settings (unless requested).

---

## N. PRESERVATION CHECKLIST

Use this as the regression script after each stage (especially 1, 3, 4, 6).

| Capability | How to preserve / test |
|---|---|
| Therapist auth | Sign in/up/verify still `AuthView`; TabView only after session + gates |
| Terms gate | New account still blocking `TermsView` **before** tabs |
| Welcome | First launch Welcome **before** tabs; Skip vs Continue demo |
| Demo mode | Enter from Welcome/empty list/Settings; banner; exit resets **Patients** path; coach vs tab bar |
| Patient creation | `AddPatientView` from list `+` and (later) global sessions |
| Patient editing | Name sheet on Detail |
| Local names | List, Detail, pickers, push personalization still Keychain/App Group |
| Treatment goal | Header edit; formulation other fields unchanged |
| Treatment status | Active/Inactive persist; completed section on list |
| Session create/edit/delete | Sheets + editor + code challenge |
| Therapist questionnaire | From session; graphs/list split still same data |
| Questionnaire assignment | Still Edge Function + session id; Patient Mode submit |
| Therapist sees results | List + session row + graphs |
| Diary 1 | Therapist CRUD + start/stop; patient create-only |
| Diary 2/3 | No fake features; placeholders only |
| Invitation + share | Header when disconnected |
| Universal Link | Invite URL still root overlay |
| Consent/activation | Invitation phases unchanged |
| Anonymous Patient Mode | No therapist tabs |
| Connection | RPC on Detail; send questionnaire still respects not-connected |
| Voice transcription | Notes destination + session notes |
| Session AI + chat + prep | Same services; prep from Sessions |
| Push registration | Still after tabs visible / Patient Mode active — **re-test `pushRegistrationContext`** so TabView doesn’t delay or double-fire |
| Foreground push | `willPresent` unchanged |
| Settings | All rows; Getting Started cover |
| Sign out / delete account | Settings tab |
| Deep links | Auth callback + password-reset sheets still on `ContentView` |

---

## O. QUESTIONS BEFORE IMPLEMENTATION

# QUESTIONS BEFORE IMPLEMENTATION

1. **Demo coach vs bottom TabView**  
   `demoModeChrome` pins `TutorialCoachCard` to the bottom safe area. A 5-tab bar will collide. Options: (a) shrink/move coach above tabs, (b) hide TabView during Getting Started, (c) drop coach UI later. **Needs a product/layout decision before Stage 1 lands on device.**

2. **“קרובות” includes today?**  
   Current model treats today as “already taken place” for session **counts**. For upcoming lists, including today is usually right. Confirm.

3. **שליחה למטופל/ת → שאלון without a session**  
   Backend **requires `sessionId`**. Options: (a) force session picker/create first, (b) only enable Send from session editor (weaker IA), (c) **backend change** to allow patient-level questionnaire (out of scope unless you approve). **Do not silently create empty sessions.**

4. **Send sheet: show הודעה/קובץ now?**  
   Showing disabled rows implies a promise. Omit vs “בקרוב”?

5. **Patient Detail: show הודעות/קבצים rows now?**  
   Same issue. Recommendation: **omit** until backend exists, unless you want visible placeholders.

6. **Connection on Patients list**  
   RPC-per-row is expensive and uncached. Stage 2 recommendation: **status only, no connection on rows**; connection on Detail only. Confirm.

7. **Inactive section copy**  
   Status is `Inactive`, not “completed treatment”. Is `טיפולים שהסתיימו` the right label for `.inactive`?

8. **Notifications tab v1**  
   Empty forever until backend inbox, vs tap-to-navigate without a list, vs process-only ephemeral list? Unread badge **cannot** be honest without storage.

9. **כל הפעילות**  
   Ship a dead-end empty screen, hide it, or wait for backend? Client-side reconstruction would **misrepresent** therapist vs patient diary entries and omit connection timestamps.

10. **Diary 2 assignment API vs placeholder**  
    Service can `activateOngoingAssignment(.diaryTwo)` but Patient Mode shows a non-actionable card. Send-to-patient must **not** enable Diary 2 accidentally.

11. **Settings appearance**  
    Light/dark exists in Patient Settings only. Add to therapist Settings tab for parity?

12. **Add Patient from Global Sessions**  
    Should Stage 5 include “new patient → new session” or list-only `+` remains the sole create-patient path?

13. **Programmatic navigation coordinator**  
    Stage 1 without it is simpler; Stage 6 needs it. Approve delayed coordinator?

14. **UI tests / `patients.root`**  
    May need tab-bar-aware identifiers. Who owns updating UI tests?

15. **Android**  
    This plan is iOS-only. Keep Android on old IA until a separate plan?

16. **Questionnaire graphs initial route**  
    Confirm graphs screen should **hide** the List/Graphs segmented control (recommended) so therapists don’t need the old two-step path.

17. **Primary action “פגישה חדשה” on both Detail and Patient→Sessions**  
    Duplicate by design (proposal). Confirm acceptable.

18. **Risk of data loss**  
    Notes demotion is safe if extracted. **Unsafe** if the notes section is removed without a destination. Preparation files stay local — moving UI must keep `SavedPreparation.load(for:)`.

19. **Multiple implementation approaches for TabView**  
    (A) Five persistent tab children (recommended). (B) `switch selectedTab` single stack (will destroy Patient path — **rejected** unless you insist). (C) Custom router — unnecessary for Stage 1.

20. **Push payload contract**  
    Client **parses** IDs but production payloads were not verified in this pass. Confirm Edge/push senders always include `type` + `patientId` and completion events include `sessionId`/`assignmentId` before relying on Stage 6 navigation.

---

**End of planning document. No application code was modified.**

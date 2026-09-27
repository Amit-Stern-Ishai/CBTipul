# CBTipul — Current UX & Navigation Map

**Scope:** iOS SwiftUI app as implemented in this repository.  
**Not included:** Android, planned features, suggestions, redesigns.  
**Locale/layout (user-visible):** Hebrew copy (`L10n`); app-wide RTL via `AppTextSizeModifier`. Default appearance is dark navy; light mode exists as a setting in Patient Mode Settings only.  
**Status markers used below:** `IMPLEMENTED` | `PARTIAL` | `PLACEHOLDER` | `COMMENTED_OUT` | `UNCERTAIN` | `NO_UI` (code exists, no user-facing screen).

---

## 1. App Entry & Global Routing

App Launch (`MyApp` → `ContentView`)
→ Overlay `SplashView` for ~1.5s (skipped entirely when `AuthManager.isUITesting`)
→ Incoming URL / Universal Link may activate invitation flow (see §8, §12)
→ Root destination from `AppRootRouting.destination(invitationActive, hasSession, isAnonymous)`:

```
invitationActive == true
  → PatientInvitationFlowView   [highest priority; overrides signed-in therapist]

else no Auth session
  → AuthView                    [unauthenticated]

else anonymous Auth session
  → AppRootRouting.anonymousDestination(appContext, isLoading)
      context.isActivePatient     → PatientModeView
      context.role == .patient    → PatientActivationIncompleteView
      context present, other role → PatientContextRetryView
      isLoading, no context       → loading spinner + “connecting” copy
      else                        → PatientContextRetryView

else non-anonymous Auth session (Therapist)
  → [gate] optional display-name prompt (full-screen TherapistDisplayNameEditorView, requirement .optional)
       shown once per account until dismissed/saved; skipped while resolving profile
  → [gate] if display-name gate is still resolving → blank Theme.base (no chrome)
  → [gate] TermsView with Agree (blocking) if TermsAcceptance.hasAccepted(email) is false
  → [gate] WelcomeOnboardingView if OnboardingStore.welcomeDismissed is false
  → else PatientListView (Therapist Mode home)
```

**Additional root overlays (not destinations):**
- Password-recovery sheet: `NewPasswordView` when `auth.isRecoveringPassword` (can appear over therapist/auth after `cbtipul://password-reset`).
- UI testing: after Auth IDs, injects therapist demo session, forces terms accepted, skips welcome, enters demo mode.

**Push permission / FCM registration:** requested only after therapist is past Terms + Welcome + display-name gate (patient list), or after Patient Mode is fully active. Not requested on Auth, Terms, Welcome, invitation, or incomplete activation.

**Anonymous Auth = Patient Mode identity.** Therapist Mode is never shown for anonymous sessions.

---

## 2. Global Navigation Structure

- **No TabView. No sidebar.** Single `WindowGroup`.
- **Therapist Mode:** one `NavigationStack` owned by `PatientListView`, path typed with `Patient` → `PatientDetailView`. Nested screens use further `NavigationLink`s / sheets.
- **Patient Mode:** separate `NavigationStack` in `PatientModeView` (not nested in therapist stack).
- **Invitation:** replaces entire root; not pushed on a stack.
- **Persistent navigation:**
  - Therapist: gear (Settings sheet) top-leading; plus (add patient) top-trailing; gold add-patient CTA in bottom safe-area inset.
  - Patient Mode: gear (Patient Settings sheet) top-leading; refresh assignments top-trailing.
- **Demo chrome** (`demoModeChrome`): warning banner “demo mode” + exit; bottom `TutorialCoachCard` while checklist is not dismissed; showcase intro `fullScreenCover` hosted only on patient list.
- **Global toolbar (app-wide):** none besides per-screen toolbars. Tint is gold.
- **Settings access:** therapist gear on patient list; patient gear on Patient Mode home. Not on Auth/Welcome/Terms/invitation.
- **Notification-related navigation:** **PLACEHOLDER / not implemented.** Foreground notifications are presented (banner/list/sound/badge) and copy is personalized; there is no `userNotificationCenter(_:didReceive:)` handler and no in-app destination routing.
- **Deep-link routing:** see §8 and §12. Invitation Universal Links take over the root. Auth callbacks stay on `cbtipul://`.

### Compact tree

```
App (ContentView + Splash overlay)
├── AuthView
│   ├── Sign In / Sign Up
│   ├── Verify email (post sign-up)
│   └── NewPasswordView (sheet; recovery)
├── PatientInvitationFlowView
│   ├── Loading / Activating
│   ├── Preview
│   ├── Consent
│   └── Unavailable / Failed / Activation failed
├── Therapist gates
│   ├── TherapistDisplayNameEditorView (optional, full-screen)
│   ├── TermsView (Agree)
│   └── WelcomeOnboardingView
└── Mode roots
    ├── Therapist: PatientListView (NavigationStack)
    │   ├── SettingsView (sheet)
    │   ├── AddPatientView (sheet)
    │   ├── WelcomeOnboardingView (fullScreenCover when starting demo from Settings)
    │   └── PatientDetailView (push)
    │       └── … (see §3–§5)
    └── Patient: PatientModeView (NavigationStack)
        ├── PatientSettingsView (sheet)
        ├── PatientQuestionnaireView (push)
        └── PatientDiaryOneEntryView (push)
        [or] PatientActivationIncompleteView / PatientContextRetryView / loading
```

---

## 3. Therapist Mode — Screen Inventory

### Screen: Splash

**SwiftUI view(s):**
- SplashView

**Purpose:** Branded launch screen (app icon + title) while session restore can complete.

**Entry points:**
- App launch overlay (~1.5s)

**Primary actions:**
- None (auto-dismiss)

**Secondary actions:**
- None

**Displays:**
- Splash icon, app title

**Conditional states:**
- Skipped in UI testing

**Presented UI:**
- None

**Exit/navigation:**
- Reveals whatever root destination is already chosen underneath

---

### Screen: Sign In / Sign Up

**SwiftUI view(s):**
- AuthView

**Purpose:** Email/password authentication for therapists.

**Entry points:**
- Root when no session and invitation flow is idle
- After invitation Close (if still unauthenticated)
- After Patient Mode “leave” (signs out)

**Primary actions:**
- Sign In → therapist gates or (on failure) error on card
- Sign Up → sends verification email → in-place “check your email” card
- Forgot password → `resetPasswordForEmail` → info/error message on card (no dedicated screen)

**Secondary actions:**
- Toggle Sign In / Sign Up mode
- Resend verification (cooldown)
- Back to Sign In from verification card

**Displays:**
- App icon, title, welcome copy, email, password; sign-up also confirm password + live password-rules checklist

**Conditional states:**
- Working/busy on buttons
- Error / info messages on card
- Verification-email state replaces the form

**Presented UI:**
- None (NewPasswordView is a ContentView sheet, not presented by AuthView)

**Exit/navigation:**
- Successful sign-in → therapist root gates
- Email verification link (`cbtipul://auth-callback`) completes sign-up outside this screen

---

### Screen: Check your email (verification)

**SwiftUI view(s):**
- AuthView (`verificationCard`)

**Purpose:** Tell the user a verification email was sent after sign-up.

**Entry points:**
- Successful Sign Up

**Primary actions:**
- Resend verification
- Back to Sign In

**Secondary actions:**
- None

**Displays:**
- Destination email, error/info lines

**Conditional states:**
- Resend blocked during cooldown; busy spinner

**Presented UI:**
- None

**Exit/navigation:**
- Back to Sign In form; actual verification happens via email link

---

### Screen: New password (recovery)

**SwiftUI view(s):**
- NewPasswordView

**Purpose:** Complete password reset after recovery link signed the user in.

**Entry points:**
- `cbtipul://password-reset` sets `auth.isRecoveringPassword` → root sheet

**Primary actions:**
- Save new password → dismiss sheet, remain signed in
- Cancel → signs the user out (recovery session must not become a login)

**Secondary actions:**
- None

**Displays:**
- Password, confirm, rules checklist, mismatch/error

**Conditional states:**
- Save disabled until rules satisfied and passwords match; busy overlay

**Presented UI:**
- Sheet from ContentView

**Exit/navigation:**
- Save → therapist (or whatever session remains)
- Cancel → AuthView

---

### Screen: Therapist display name (optional gate)

**SwiftUI view(s):**
- TherapistDisplayNameEditorView (`requirement: .optional`)

**Purpose:** One-time post-login prompt for the patient-facing therapist name.

**Entry points:**
- Therapist session after profile resolve if prompt not yet shown and name invalid/missing

**Primary actions:**
- Save name → continue to Terms/Welcome/list
- Skip/finish optional path (`onOptionalFinished`) → continue without requiring a name

**Secondary actions:**
- None

**Displays:**
- Explanation, name field, errors

**Conditional states:**
- Loading existing profile; saving busy

**Presented UI:**
- Full-screen root replacement (not a sheet)

**Exit/navigation:**
- Terms or Welcome or Patient list (next remaining gate)

---

### Screen: Terms (blocking)

**SwiftUI view(s):**
- TermsView + LegalDocumentView

**Purpose:** Require per-account terms acceptance before using Therapist Mode.

**Entry points:**
- After display-name gate when `TermsAcceptance` is false for the signed-in email

**Primary actions:**
- Agree → persist UserDefaults key `hasAcceptedTerms-<email>` → next gate

**Secondary actions:**
- None (no skip)

**Displays:**
- Parsed terms document (title, update date, numbered section cards)

**Conditional states:**
- Agree button only when `onAgree` is set (blocking mode)

**Presented UI:**
- None

**Exit/navigation:**
- Welcome or Patient list

---

### Screen: Welcome / demo consent

**SwiftUI view(s):**
- WelcomeOnboardingView
- WelcomeInfoSheet

**Purpose:** Introduce the app and optionally start the local demo tour.

**Entry points:**
- First therapist use (`welcomeDismissed` false)
- Full-screen cover from PatientListView when Settings requests demo consent (`onboarding.wantsDemoConsent`)

**Primary actions:**
- Primary (continue demo) → mark demo tour completed, dismiss welcome, show checklist, `store.enterDemoMode()`, then PatientListView
- Skip (when `allowsSkip`, default true) → dismiss welcome only; stay in live clinic data

**Secondary actions:**
- Info link → medium sheet explaining local storage of names; Privacy Policy opens `https://cbtipul.com/privacy` in the system browser

**Displays:**
- Welcome title/body; primary/secondary/info buttons

**Conditional states:**
- `allowsSkip` can hide Skip (not used at the two current call sites with false)

**Presented UI:**
- WelcomeInfoSheet (medium detent)

**Exit/navigation:**
- PatientListView (demo or live)

---

### Screen: Patients list (Therapist home)

**SwiftUI view(s):**
- PatientListView
- PatientRow (row chrome)
- Add CTA / empty ContentUnavailableView

**Purpose:** List the therapist’s patients and enter a patient; add patients; open Settings; enter demo from empty live clinic.

**Entry points:**
- After therapist gates
- Back from Patient Detail
- Demo exit resets navigation path to this screen

**Primary actions:**
- Tap patient → push Patient Detail
- Toolbar + or bottom gold CTA → Add Patient sheet
- Empty live clinic: “enter demo” → same demo tour as Welcome primary
- Pull to refresh → reload patients

**Secondary actions:**
- Gear → Settings sheet
- Search field when patient count > 7
- Demo: TutorialCoachCard pulses add-patient / tutorial patient; Restart / Dismiss / Skip to sample data on coach card; DemoModeBanner exit demo

**Displays:**
- Patients grouped active-first then alphabetical; status on rows; search empty copy

**Conditional states:**
- Loading spinner (empty list)
- Load error + Retry (empty list)
- Empty clinic ContentUnavailableView + add CTA (+ demo button if not already demo)
- Demo mode banner + coach
- After showcase countdown: DemoShowcaseIntroView fullScreenCover

**Presented UI:**
- Sheet: AddPatientView
- Sheet: SettingsView
- Full-screen cover: WelcomeOnboardingView (demo consent from Settings)
- Full-screen cover: DemoShowcaseIntroView

**Exit/navigation:**
- Patient Detail; Settings; Add Patient; Welcome cover; remaining in this root

---

### Screen: Add patient

**SwiftUI view(s):**
- AddPatientView

**Purpose:** Create a patient row (first name, last name, status).

**Entry points:**
- Patients list toolbar + / bottom CTA
- Tutorial coach on add-patient

**Primary actions:**
- Add → insert patient, dismiss
- Cancel → dismiss

**Secondary actions:**
- Status picker: Active / Inactive

**Displays:**
- Plus avatar, name fields, status, save errors

**Conditional states:**
- Save disabled if both names empty or saving; busy overlay

**Presented UI:**
- Sheet with its own NavigationStack

**Exit/navigation:**
- Dismiss to Patients list (new patient appears in list; does not auto-open detail)

---

### Screen: Patient detail (hub)

**SwiftUI view(s):**
- PatientDetailView

**Purpose:** Hub for one patient: identity, scores, status, navigation to sessions/questionnaires/diary/AI, invite, prepare next session, patient-level notes + voice.

**Entry points:**
- NavigationLink from Patients list
- Tutorial coach focusing the tour patient

**Primary actions:** see §4

**Secondary actions:**
- Save notes (toolbar, enabled when notes/recording dirty)
- Overflow menu → delete patient (confirm + numeric delete-code challenge)
- Back with unsaved-notes warning (save / discard / keep editing)

**Displays:**
- Display name, treatment-goal pill (or empty placeholder), status badge, latest GAD-7/PHQ-9 capsules with trend vs previous, last-session date **UNCERTAIN:** last session used internally; chips are questionnaire scores
- Placeholder chips while questionnaire cache loading
- Last preparation date + “outdated” badge when a later past session exists

**Conditional states:**
- Saving / transcribing / anonymizing / preparing / creating invitation busy
- Demo coach pulses Sessions row
- Connected vs not-connected is not shown on this hub except via Invite; diary/session screens handle connection

**Presented UI:**
- Sheets: edit name, edit treatment goal, share invitation (`UIActivityViewController`), required display-name editor before invite, NextSessionPreparationView, PreparationInsufficientSheet, first-preparation ContextualTipSheet
- Alerts: delete patient, discard notes, invitation failed
- Delete-code challenge alert
- Programmatic push: PatientSessionsView with optional `SessionsInitialAction` from Getting Started

**Exit/navigation:**
- Back to Patients list; pushes listed in §4

---

### Screen: Sessions list

**SwiftUI view(s):**
- PatientSessionsView
- SessionRow

**Purpose:** Chronological sessions grouped by Hebrew month; add/edit sessions.

**Entry points:**
- Patient Detail → Sessions
- Getting Started may auto-present add/edit/questionnaire sheets via `initialAction`

**Primary actions:**
- Tap session row → Session Editor sheet (edit)
- Toolbar + / bottom CTA → Session Editor sheet (new)
- Empty-state copy + same add CTA

**Secondary actions:**
- None besides demo pulse on latest session / add

**Displays:**
- Session number (oldest = 1), date, type, GAD-7/PHQ-9 preview when cache loaded

**Conditional states:**
- Empty sessions
- Demo coach

**Presented UI:**
- Sheet: SessionEditorView (new/edit)
- Sheet: CombinedMoodQuestionnaireView with Cancel (Getting Started `addQuestionnaire` path)

**Exit/navigation:**
- Back to Patient Detail; sheets dismiss here

---

### Screen: Session editor (new / existing)

**SwiftUI view(s):**
- SessionEditorView

**Purpose:** Create or edit a session: type, date, notes (+ voice transcription), AI structured summary, questionnaire fill or send-to-patient.

**Entry points:**
- Sessions list sheets
- Getting Started initial actions

**Primary actions:**
- New: bottom “Add session” → save and dismiss
- Existing: toolbar Save (dirty only); overflow Delete (confirm + code challenge)
- Analyze / AI summary → generates structured notes, presents SessionAnalysisView
- Show structured summary (if already saved) → SessionAnalysisView (`requiresSaveDecision: false`)
- Add questionnaire → CombinedMoodQuestionnaireView (push inside the session sheet’s stack)
- Send questionnaire to patient → Edge Function; success alert
- Mic → record; stop auto-starts transcription; on failure: play / transcribe retry / discard

**Secondary actions:**
- New: type picker (none + protocol types) and date picker in form
- Existing: pencil menu for type; calendar sheet for date
- Back with unsaved changes: save / discard / keep editing

**Displays:**
- Session number in title when existing; notes; analysis loading; questionnaire scores if completed; assignment status (see §5)

**Conditional states:**
- New vs existing (no questionnaire section until saved; no delete/save toolbar on new)
- Questionnaire: loading, existing answers, therapist fill, send available, pending assignment, not connected, failed
- Analyzing / transcribing / anonymizing / saving busy
- Demo pulse on fill-questionnaire / record / AI summary

**Presented UI:**
- Alerts: delete, discard, questionnaire sent
- Sheets: date picker, SessionAnalysisView
- Sheet for “all follow-ups” exists in code
- COMMENTED_OUT: follow-up questions section in the form is commented out, so the follow-ups sheet is not user-reachable from visible UI

**Exit/navigation:**
- Dismiss to Sessions; push questionnaire

---

### Screen: Combined mood questionnaire (therapist)

**SwiftUI view(s):**
- CombinedMoodQuestionnaireView
- QuestionnaireSections / AnswerScaleView / note editor sheets
- CompletedQuestionnaireView (read-only history)

**Purpose:** GAD-7 then PHQ-9 for a session; upserts one combined row. Existing opens read-only until Edit.

**Entry points:**
- Session Editor NavigationLink (new or existing)
- Sessions list questionnaire sheet (Getting Started)
- Patient Questionnaires list → CompletedQuestionnaireView (read-only, no edit)

**Primary actions:**
- Save (complete answers required; incomplete tap shows alert)
- Edit (toolbar menu on existing)
- Delete existing (confirm + code challenge)
- Back with unsaved: save / discard / keep editing
- Cancel when `showsCancelButton` (sheet)

**Secondary actions:**
- Per-question note icon in therapist edit mode → note editor sheet
- First-questionnaire tip sheet

**Displays:**
- Questions, previous answers when another earlier questionnaire exists, GAD-7/PHQ-9, interference item
- Therapist notes on questions (therapist fill only)

**Conditional states:**
- Read-only vs editing
- Incomplete save blocked
- Demo coach on questionnaire placement
- First-run tip

**Presented UI:**
- Alerts: delete, discard, incomplete
- Sheets: first questionnaire tip, per-question note editor

**Exit/navigation:**
- Back/dismiss to session or questionnaires list

---

### Screen: Patient questionnaires (history / graphs)

**SwiftUI view(s):**
- PatientQuestionnairesView
- CompletedQuestionnaireView (push)

**Purpose:** All saved questionnaires for the patient: list or GAD-7/PHQ-9 score-over-time charts. No add button.

**Entry points:**
- Patient Detail → Questionnaires

**Primary actions:**
- Segmented List / Graphs (hidden until at least one questionnaire)
- Tap list row → read-only CompletedQuestionnaireView
- Pull to refresh

**Secondary actions:**
- Retry on load error

**Displays:**
- Date + score capsules with trend arrows; charts after brief prepare delay

**Conditional states:**
- Loading, error+retry, empty, graphs preparing spinner

**Presented UI:**
- None (push only)

**Exit/navigation:**
- Back to Patient Detail; push completed questionnaire

---

### Screen: Diary 1 (therapist)

**SwiftUI view(s):**
- PatientDiaryOneView
- DiaryOneEntryFormView (create/edit)
- Diary feeling picker sheet (`DiaryFeelingViews`)

**Purpose:** Therapist list of Diary 1 entries; create/edit/delete; start/stop Patient Mode diary assignment.

**Entry points:**
- Patient Detail → Diary 1
- Add CTA / toolbar + → create form
- Row NavigationLink → edit form

**Primary actions:**
- Add entry → form save
- Edit entry → form save
- Delete entry (confirm)
- Start Patient Mode diary (when connected and inactive)
- Stop Patient Mode diary (confirm)
- Retry load / retry assignment check

**Secondary actions:**
- None

**Displays:**
- Entries newest first: date, event, thought, feelings preview
- Patient Mode status: loading / not connected / inactive+start / active (green)+stop / failed+retry

**Conditional states:**
- Entries loading / failed / empty
- Assignment error lines
- Demo chrome

**Presented UI:**
- Alerts: stop Patient Mode, validation, discard, delete
- Feeling picker sheet on form

**Exit/navigation:**
- Back to Patient Detail

---

### Screen: AI assistant (patient chat)

**SwiftUI view(s):**
- PatientAIView

**Purpose:** WhatsApp-style chat about this patient; each turn uses patient notes, sessions, questionnaires as context. History is in-memory for the screen lifetime only.

**Entry points:**
- Patient Detail → AI

**Primary actions:**
- Send typed prompt → streaming or full reply (style from AppStorage, Settings picker COMMENTED_OUT so default `.typing` unless previously stored)
- Tap suggested example question → fills composer

**Secondary actions:**
- None persisted

**Displays:**
- Bubbles; thinking spinner; errors; empty-state suggested questions

**Conditional states:**
- Empty vs in conversation; loading; error
- First AI call may present AIDataSharingConsentView (UIKit host) unless demo (bypass)

**Presented UI:**
- AI consent sheet (global, first real AI call)

**Exit/navigation:**
- Back to Patient Detail (chat discarded)

---

### Screen: Session analysis (AI structured summary)

**SwiftUI view(s):**
- SessionAnalysisView

**Purpose:** Review/edit AI session analysis: summary, key situations, automatic thoughts, CBT cycles, hypotheses, follow-up questions. Empty sections hidden.

**Entry points:**
- Session Editor Analyze (fresh, `requiresSaveDecision: true`)
- Session Editor “show structured summary” (saved)

**Primary actions:**
- Edit fields; dismiss with save prompt if fresh or dirty
- Save via `onSave` writes `session.structuredNotes`

**Secondary actions:**
- Follow-up question triage chips (discussed / etc.) on this screen **IMPLEMENTED** here even though the session editor follow-up list is COMMENTED_OUT

**Displays:**
- Analysis cards outlined in patient color

**Conditional states:**
- Save-ask alert on dismiss when needed

**Presented UI:**
- Sheet from Session Editor
- Alert: save summary prompt

**Exit/navigation:**
- Dismiss to Session Editor

---

### Screen: Prepare next session

**SwiftUI view(s):**
- NextSessionPreparationView
- PreparationInsufficientSheet
- ContextualTipSheet (first-time)

**Purpose:** Show AI pre-session briefing stored locally per patient (not synced). Outdated badge if a later past session exists.

**Entry points:**
- Patient Detail “prepare next session”
- Patient Detail “last preparation” if a saved file exists
- First-time tip then proceeds to generate

**Primary actions:**
- Generate (from detail) → sheet of result, or insufficient-data sheet with CTA to add session / other missing action
- Dismiss analysis sheet

**Secondary actions:**
- Evidence expanders on cards (in-view)

**Displays:**
- Clinical summary, follow-ups, thoughts, cycles, questionnaire insights, recommended focus, questions, possible belief; hypothesis wording

**Conditional states:**
- Preparing spinner on detail row
- Insufficient clinical signal sheet
- Outdated saved prep
- Demo: consent bypassed

**Presented UI:**
- Sheets as above

**Exit/navigation:**
- Dismiss to Patient Detail; insufficient CTA can navigate into Sessions (`handlePreparationMissingAction`)

---

### Screen: Therapist Settings

**SwiftUI view(s):**
- SettingsView
- TextSizePickerView
- TherapistDisplayNameEditorView (required, embedded)
- TermsView (read-only, no Agree)
- OfficialLinkWebView (in-app WKWebView for official URLs)
- DEBUG: test-push button + alerts

**Purpose:** Demo guide, accessibility text size, legal/support links, account, delete account.

**Entry points:**
- Patients list gear

**Primary actions / items:** see §10

**Secondary actions:**
- Back dismisses sheet

**Displays:**
- Version/build footer

**Conditional states:**
- AI consent approved row only if accepted
- Email row if signed-in email present
- DEBUG section compile-time only
- AI response-style picker COMMENTED_OUT
- **Appearance picker is NOT in therapist Settings** (exists as AppearancePickerView; used from Patient Settings)

**Presented UI:**
- Sheet: official link web view
- Alerts: delete account confirm, delete failed, DEBUG push result
- Delete-code challenge

**Exit/navigation:**
- Dismiss to Patients list; requesting demo consent closes this sheet and presents Welcome cover on the list

---

### Screen: Text size picker

**SwiftUI view(s):**
- TextSizePickerView

**Purpose:** App-wide Dynamic Type override (small → huge).

**Entry points:**
- Therapist Settings; Patient Settings

**Primary actions:**
- Select size (persists `appTextSize`)

**Secondary actions:**
- None

**Displays:**
- Size options with preview font

**Conditional states:**
- None

**Presented UI:**
- None

**Exit/navigation:**
- Back to Settings

---

### Screen: Appearance picker

**SwiftUI view(s):**
- AppearancePickerView

**Purpose:** Light vs dark app appearance (`appAppearance`).

**Entry points:**
- Patient Settings only (therapist Settings has no link)

**Primary actions:**
- Select light/dark

**Secondary actions:**
- None

**Displays:**
- Two options

**Conditional states:**
- None

**Presented UI:**
- None

**Exit/navigation:**
- Back to Patient Settings

---

### Screen: Terms (read-only from Settings)

**SwiftUI view(s):**
- TermsView without `onAgree`

**Purpose:** Read terms.

**Entry points:**
- Therapist and Patient Settings NavigationLink

**Primary actions:**
- None (scroll)

**Secondary actions:**
- Back

**Displays:**
- Same LegalDocumentView as blocking terms

**Conditional states:**
- No Agree bar

**Presented UI:**
- None

**Exit/navigation:**
- Back to Settings

---

### Screen: Therapist display name (Settings / invite)

**SwiftUI view(s):**
- TherapistDisplayNameEditorView (`requirement: .required`)

**Purpose:** Set patient-facing name; required before creating an invitation if missing.

**Entry points:**
- Settings NavigationLink
- Patient Detail invite sheet when name invalid

**Primary actions:**
- Save
- Cancel/back (when embedded in stack/sheet)

**Secondary actions:**
- None

**Displays:**
- Explanation, field, errors

**Conditional states:**
- Loading/saving

**Presented UI:**
- Sheet from Patient Detail; push from Settings

**Exit/navigation:**
- Settings back; invite sheet dismiss then continues invitation if pending

---

### Screen: Demo showcase intro

**SwiftUI view(s):**
- DemoShowcaseIntroView

**Purpose:** After demo countdown or “skip to sample data”, invite exploration; remind how to exit demo.

**Entry points:**
- PatientListView `showcaseIntroHost` fullScreenCover when router says intro should show

**Primary actions:**
- Explore → dismiss, checklist may remain or finish per router

**Secondary actions:**
- None

**Displays:**
- Title, body, flask exit hint

**Conditional states:**
- Only in demo after reveal trigger

**Presented UI:**
- Full-screen cover

**Exit/navigation:**
- Back to Patients list (demo data)

---

### Screen: Getting Started coach (not a full screen)

**SwiftUI view(s):**
- TutorialCoachCard (via DemoModeBanner / demoModeChrome)
- GettingStartedCard.swift (step model + coach targeting)

**Purpose:** Bottom dock in demo while checklist not dismissed. Steps in order: create patient, create session, fill questionnaire, record session summary, create AI summary. Pulses the next visible control; Restart, Dismiss checklist, Skip to sample data, countdown to showcase.

**Entry points:**
- Auto in demo until dismissed

**Primary actions:**
- Restart tour; dismiss coach; skip to showcase

**Secondary actions:**
- None

**Displays:**
- Current step title + screen-specific hint

**Conditional states:**
- Hidden if checklist dismissed or not demo
- No pulse on wrong patient

**Presented UI:**
- Bottom inset, not a sheet

**Exit/navigation:**
- Stays on current screen; skip/countdown → showcase intro

---

### Screen: AI data-sharing consent

**SwiftUI view(s):**
- AIDataSharingConsentView (presented via UIKit host from AIDataSharingConsentStore)

**Purpose:** One-time per therapist account before sending clinical content to OpenAI. Decline remembered but next AI action asks again. Demo bypasses.

**Entry points:**
- First AI action (analyze, chat, prepare next session, transcription anonymization path that calls OpenAI)

**Primary actions:**
- Accept → run pending AI
- Decline / not now → cancel pending AI silently (no error toast)

**Secondary actions:**
- None

**Displays:**
- Consent body copy

**Conditional states:**
- Per-account UserDefaults; not shown in demo

**Presented UI:**
- Modal UIKit sheet

**Exit/navigation:**
- Returns to the screen that requested AI

---

### Screen: Privacy policy (in-app LegalDocumentView)

**SwiftUI view(s):**
- PrivacyPolicyView

**Purpose:** Local legal document renderer.

**Entry points:**
- **NO_UI in navigation.** Only used in its SwiftUI preview. Live Settings/Welcome/invite open `https://cbtipul.com/privacy` (web or OfficialLinkWebView).

**Primary actions:**
- N/A

**Secondary actions:**
- N/A

**Displays:**
- N/A in product navigation

**Conditional states:**
- N/A

**Presented UI:**
- N/A

**Exit/navigation:**
- N/A

---

## 4. Patient Detail — Complete Flow

```
Patient Detail
├── Header
│   ├── Display name + edit-name sheet
│   ├── Treatment goal (formulation.treatmentGoal only) + edit-goal sheet
│   └── Status badge
├── Latest GAD-7 / PHQ-9 chips (or loading placeholders / empty)
├── Status picker (Active / Inactive) — saves immediately
├── Sessions → PatientSessionsView
├── Questionnaires → PatientQuestionnairesView
├── Diary 1 → PatientDiaryOneView
├── AI → PatientAIView
├── Invite patient → (optional display-name sheet) → system share sheet
├── Prepare next session → generation / tip / insufficient / NextSessionPreparationView
├── Last preparation (if saved locally) → NextSessionPreparationView (outdated badge possible)
├── Patient-level notes + voice record/transcribe
├── Toolbar Save (notes)
└── Overflow Delete patient
```

**Main patient screen information:**
- Name, treatment goal (empty placeholder if none), status, latest questionnaire scores with trend vs previous.

**How sessions are accessed:** NavigationLink “Sessions”; Getting Started can set `isShowingSessions` and `SessionsInitialAction` (add session / edit latest for summary / add questionnaire).

**How questionnaires are accessed:** NavigationLink to history/graphs; filling is from a session (not from this hub). Patient-sent questionnaires are initiated from Session Editor.

**How session preparation works:** Button generates AI briefing; first use may show tip; if not enough data, insufficient sheet with action (e.g. add session) that can push Sessions. Result cached on device (`preparation-<patientId>.json` or demo store). “Last preparation” reopens saved result.

**How notes are accessed/created:** Patient-level notes field on this screen (not session notes). Mic records; stop transcribes (anonymize then append). Save toolbar persists notes. Session notes live in Session Editor.

**How AI/chat is reached:** NavigationLink sparkles “AI”.

**How patient connection/invitation works:** Invite button calls `create-patient-invitation` with patient id; requires valid therapist display name (sheet if missing); then Hebrew share message + URL via `ActivityShareSheet`. Errors: invalid patient, network → alert. No in-app “connected” badge on this hub.

**Patient assignment actions on this hub:** none directly. Diary assignment is on Diary 1 screen. Questionnaire assignment is on Session Editor.

**Other actions:** change status (immediate persist, revert on failure); delete patient (confirm + code); discard-notes on back.

**Formulation:** model has coreBelief, thoughts, cycles, hypothesis. **UI currently edits treatmentGoal only.** Strings/APIs for “challenge my formulation / what am I missing / longitudinal review” exist in `L10n` + `WhisperService` with **NO_UI**.

---

## 5. Session Flow

```
Patient Detail
→ Sessions
   ├── Empty: add CTA
   └── List by month → tap session
→ Create Session (sheet, isNew)
   ├── Type picker (optional protocol types listed in §13)
   ├── Date picker (default today)
   ├── Notes + voice
   └── Add session (save) → dismiss; questionnaire section not shown until saved
→ Session (existing, sheet)
   ├── Header: type pencil, date calendar sheet
   ├── Notes + voice + AI summary button
   ├── Structured summary section (if saved) → view analysis
   └── Questionnaire
        ├── If completed: NavigationLink to CombinedMoodQuestionnaireView (read-only until Edit)
        └── Else:
             ├── Therapist: Add questionnaire (push CombinedMoodQuestionnaireView)
             └── Patient assignment row:
                  loading | not connected (copy only) | Send to patient | pending | failed+message
→ Analyze
   → AI consent if needed
   → SessionAnalysisView sheet
   → optional save into session.structuredNotes
→ Delete session (existing only): confirm + code → pop
→ Unsaved back: save / discard / keep editing
```

**Questionnaires:** Combined GAD-7 + PHQ-9 + interference; therapist may add per-question notes. Patient fill is a separate Patient Mode assignment tied to session via Edge Function `request-patient-questionnaire`. Success alert “questionnaire sent”. Pending state while assignment open.

**Notes/transcription:** VoiceNoteRecorder; auto-transcribe on stop; failed transcription keeps recording for retry; anonymization status line; AI consent may apply.

**Session preparation:** not inside session editor; on Patient Detail.

**Follow-up questions from prior analysis:** data/model + analysis-screen chips **IMPLEMENTED**; session-editor list **COMMENTED_OUT** (not visible).

**Getting Started auto-sheets:** addSession / editLatestForSummary / addQuestionnaire as in `SessionsInitialAction`.

---

## 6. Therapist → Patient Interaction Flows

### Invite / connect patient

Therapist:
Patient Detail → Invite patient → [if no valid display name] TherapistDisplayNameEditorView sheet → create invitation → system share sheet (SMS/Mail/etc. with URL)

Backend/state result:
`create-patient-invitation` returns `invitationUrl` (used as returned). Token not parsed on therapist device.

Patient:
Opens `https://cbtipul.com/invite/<TOKEN>` → invitation root (preview/consent/activate). After success, Patient Mode tasks. Therapist later may receive push `patient_connected` (personalized body if local name known). **Tap does not open Patient Detail.**

---

### Send questionnaire to patient

Therapist:
Session Editor (existing, no questionnaire yet, patient connected) → Send questionnaire to patient → alert on success; row becomes pending

Backend/state result:
Edge Function creates `patient_assignments` type `questionnaire` for that session.

Patient:
Patient Mode home shows open questionnaire card → PatientQuestionnaireView → submit via `submit-patient-questionnaire` → assignment closes; therapist may get `questionnaire_completed` push (personalized). Therapist sees completed questionnaire on session / questionnaires list after refresh.

PARTIAL: therapist cannot start this if not connected (copy only). Patient cannot edit after submit on this flow.

---

### Diary 1 Patient Mode assignment

Therapist:
Diary 1 → Start Patient Mode (connected + inactive) / Stop (confirm)

Backend/state result:
Assignment type `diary_one` created or cancelled.

Patient:
Open `diary_one` assignment card (ongoing hint) → PatientDiaryOneEntryView (create-only, no history). Submit → saved alert; card remains while assignment active. If therapist stops, save on patient may show inactive alert and refresh list.

Therapist still adds/edits/deletes entries independently on Diary 1 list.

---

### Diary 2 assignment (placeholder)

Therapist:
No dedicated Diary 2 therapist screen. Session **type** can be `diary_two` (protocol label only).

Patient:
Assignment type `diary_two` or unknown/`nil` type → “upcoming task” placeholder card (not tappable into a flow).

---

### Messages / files

**NO_UI.** No therapist or patient screens for messaging or file sharing.

---

### Chat / AI affecting patient

Therapist AI chat and session analysis do **not** write into Patient Mode. Patient Mode has no AI.

---

## 7. Patient Mode — Complete Navigation Map

```
Patient Mode
├── Loading / Retry / Activation incomplete (root substitutes, not inside stack)
└── PatientModeView
    ├── Settings (sheet) → PatientSettingsView
    │   ├── Text size
    │   ├── Appearance
    │   ├── Terms (in-app)
    │   ├── Privacy / Support / Privacy choices (in-app web)
    │   └── Leave Patient Mode (sign out)
    ├── Empty tasks
    ├── Assignment: questionnaire → PatientQuestionnaireView
    ├── Assignment: diary_one → PatientDiaryOneEntryView
    └── Assignment: diary_two | unknown → upcoming placeholder card
```

No files, messages, consent-after-activation (consent is invitation-only), no session list, no AI.

---

### Screen: Patient Mode home (tasks)

**SwiftUI view(s):**
- PatientModeView

**Purpose:** Show open assignments for the connected anonymous patient.

**Entry points:**
- Anonymous session + `get-app-context` reports active patient
- After invitation activation success (flow dismisses; root becomes this)

**Primary actions:**
- Start questionnaire → push PatientQuestionnaireView
- Add diary entry → push PatientDiaryOneEntryView
- Refresh toolbar / pull-to-refresh

**Secondary actions:**
- Settings gear

**Displays:**
- App title, tasks title, cards or empty title/body

**Conditional states:**
- Loading spinner (no cached assignments)
- Error full-page if failed and empty; footnote error if failed with stale list
- Empty open assignments
- Upcoming placeholder for diary_two/nil

**Presented UI:**
- Sheet: PatientSettingsView
- Alerts: questionnaire submitted; diary saved

**Exit/navigation:**
- Leave mode from Settings; assignment pushes; no “therapist mode” switch without leave/sign-out

---

### Screen: Patient questionnaire (Patient Mode)

**SwiftUI view(s):**
- PatientQuestionnaireView

**Purpose:** Patient-safe GAD-7+PHQ-9; submit only via Edge Function. No therapist notes. No previous answers.

**Entry points:**
- Task card NavigationLink

**Primary actions:**
- Submit (toolbar); incomplete → alert
- Back (hidden while submitting)

**Secondary actions:**
- None

**Displays:**
- Questionnaire sections; submit errors in form

**Conditional states:**
- Submitting busy overlay; interactive dismiss disabled while submitting
- Errors: already completed / cancelled / access denied / invalid / failed (localized)

**Presented UI:**
- Incomplete alert

**Exit/navigation:**
- Success → dismiss, parent alert, reload assignments

---

### Screen: Patient Diary 1 entry (Patient Mode)

**SwiftUI view(s):**
- PatientDiaryOneEntryView
- DiaryOneDraftFields / feeling picker

**Purpose:** Create-only diary entry. No history, edit, or delete in Patient Mode.

**Entry points:**
- Diary 1 task card

**Primary actions:**
- Submit
- Back with discard warning if dirty

**Secondary actions:**
- Feeling picker sheet

**Displays:**
- Event, thought, feelings fields; validation; errors

**Conditional states:**
- Validation alert; inactive-assignment alert (therapist stopped); busy submitting

**Presented UI:**
- Alerts: validation, discard, not active
- Feeling picker sheet

**Exit/navigation:**
- Success → parent saved alert + reload; inactive → reload home

---

### Screen: Activation incomplete

**SwiftUI view(s):**
- PatientActivationIncompleteView

**Purpose:** Anonymous user whose invitation is not fully active (`role == patient` but not `isActivePatient`).

**Entry points:**
- Anonymous root routing

**Primary actions:**
- Retry → refetch app context

**Secondary actions:**
- None

**Displays:**
- Title/body

**Conditional states:**
- Static until retry succeeds

**Presented UI:**
- None

**Exit/navigation:**
- Success → Patient Mode; still incomplete → same screen

---

### Screen: Patient context retry

**SwiftUI view(s):**
- PatientContextRetryView

**Purpose:** Could not load/interpret app context for anonymous session.

**Entry points:**
- Anonymous routing retry case (load failed or unexpected role)

**Primary actions:**
- Retry

**Secondary actions:**
- None

**Displays:**
- Title/body

**Conditional states:**
- None

**Presented UI:**
- None

**Exit/navigation:**
- Patient Mode / incomplete / retry again

---

### Screen: Patient Settings

**SwiftUI view(s):**
- PatientSettingsView

**Purpose:** Patient-safe settings; leave Patient Mode.

**Entry points:**
- Patient Mode gear

**Primary actions:** see §10 patient tree

**Secondary actions:**
- Back

**Displays:**
- Version

**Conditional states:**
- Leave busy overlay; leave failed alert

**Presented UI:**
- Official link web sheets; leave confirm/fail alerts

**Exit/navigation:**
- Dismiss to Patient Mode; leave → sign out → AuthView (or invitation if still active — invitation already idle)

---

### Screen: Patient connecting (anonymous loading)

**SwiftUI view(s):**
- Inline in ContentView `patientSessionRoot` `.loading`

**Purpose:** Spinner + connecting copy while `get-app-context` runs.

**Entry points:**
- Anonymous session, context loading, no context yet

**Primary actions:**
- None

**Secondary actions:**
- None

**Displays:**
- Progress + connecting label

**Conditional states:**
- Replaced when context arrives or fails

**Presented UI:**
- None

**Exit/navigation:**
- Patient Mode / incomplete / retry

---

## 8. Invitation & Patient Activation Flow

```
Therapist
→ Patient Detail → Invite
→ [optional] set display name
→ create-patient-invitation
→ system share sheet with invitationUrl

Patient taps link
→ Universal Link https://cbtipul.com/invite/<TOKEN>
   (associated domain applinks:cbtipul.com)
→ MyApp.handleIncomingURL → PatientInvitationFlow.start
→ Root destination .invitation (overrides therapist session if any)

App activation (PatientInvitationFlowView phases)
→ loading (get-patient-invitation, no sign-in)
→ preview(therapistDisplayName)  [status valid]
     Continue → consent
     Close → flow.dismiss() → previous root (Auth or Therapist)
→ unavailable: expired | claimed | cancelled | invalid  [Close]
→ failed (preview network) [Close]
→ consent (PatientInvitationConsentView)
     Privacy https://cbtipul.com/privacy/
     Terms https://cbtipul.com/terms/
     Checkbox acceptance required
     Continue → anonymous sign-in + claim-patient-invitation + get-app-context
     Back → preview
→ activating (connecting spinner)
→ activationFailed: signIn | claim(status) | context
     Retry / Close
→ success: flow.dismiss(); anonymous session + active context → Patient Mode
```

**Anonymous authentication:** created during activation (not via AuthView). Therapist signed-in on same device is overridden while `invitationFlow.isActive`; after dismiss, if anonymous session exists, Patient Mode wins over therapist because `isAnonymous` is true **UNCERTAIN if a previous therapist session is fully replaced vs signed out — UX: invitation root then Patient Mode if claim succeeded.**

**Failure UI (implemented):**
- Expired / claimed / cancelled / invalid preview
- Preview load failed (error string)
- Activation: sign-in failed, claim expired/claimed/cancelled/invalid/generic, context failed
- Invalid preview body may be empty string

---

## 9. Onboarding / Demo / Authentication

### Authentication

- AuthView email/password Sign In / Sign Up.
- Sign-up: verification card; resend; email link `cbtipul://auth-callback`.
- Forgot password: in-place on AuthView; email; then `cbtipul://password-reset` → NewPasswordView sheet; cancel signs out.
- Anonymous users never see AuthView unless they leave Patient Mode or invitation is closed without a session.
- Invitation flow does not use AuthView.

Root interaction: unauthenticated destination is AuthView unless invitation active.

### Terms

- Blocking TermsView after therapist login if not accepted for that email (UserDefaults).
- Read-only Terms from both Settings.
- Invitation consent uses **web** terms URL, not TermsView.
- Anonymous/Patient Mode skip therapist Terms gate.

### Welcome/onboarding

- WelcomeOnboardingView after Terms until `welcomeDismissed`.
- Skip → live clinic, no demo.
- Continue → demo mode + Getting Started checklist.
- Can reappear as cover from Settings “Getting Started guide” (requests demo consent; list presents Welcome and dismisses Settings).
- Empty patient list also offers enter-demo without Welcome if welcome already dismissed.

### Demo mode

- Local demo clinic (`PatientStore.enterDemoMode`); banner + exit (resets path).
- TutorialCoachCard 5 steps; skip to sample data; countdown → DemoShowcaseIntroView.
- AI consent bypassed.
- Preparations stored in DemoClinicStore.
- UI testing auto-enters demo.

### Password reset / email verification

- Verification: AuthView card + `cbtipul://auth-callback`.
- Reset: AuthView forgot + `cbtipul://password-reset` + NewPasswordView.
- Both handled in `handleIncomingURL` before invitation parsing.

---

## 10. Settings

### Therapist Settings

```
Settings (sheet from Patients list)
├── Getting Started guide (button)
│   └── Requests demo consent → list presents WelcomeOnboardingView, this sheet closes
├── Text size → TextSizePickerView
├── Terms → TermsView (read-only)
├── Privacy Policy → OfficialLinkWebView https://cbtipul.com/privacy
├── Support → OfficialLinkWebView https://cbtipul.com/support
├── Privacy choices → OfficialLinkWebView https://cbtipul.com/privacy-choices
├── AI consent approved (row only if accepted; not tappable)
├── Account
│   ├── Email (read-only, if present)
│   ├── Therapist display name → TherapistDisplayNameEditorView
│   └── Sign out (clears caches + auth.signOut)
├── Delete account (confirm + code challenge)
├── DEBUG only: send test push
└── Version/build
```

COMMENTED_OUT: AI response style picker (typing vs regular).

No appearance row. No notification preferences UI.

### Patient Settings

```
Settings (sheet from Patient Mode)
├── Text size → TextSizePickerView
├── Appearance → AppearancePickerView (light / dark)
├── Terms → TermsView (read-only)
├── Privacy Policy → OfficialLinkWebView https://cbtipul.com/privacy
├── Support → OfficialLinkWebView https://cbtipul.com/support
├── Privacy choices → OfficialLinkWebView https://cbtipul.com/privacy-choices
├── Leave Patient Mode (confirm → sign out anonymous session)
└── Version/build
```

No demo, no display name, no delete account, no AI consent row.

---

## 11. AI Features

**Feature:** Session AI structured summary  
**Entry screen:** SessionEditorView  
**User action:** Sparkles “AI summary” (disabled if notes empty)  
**Result UI:** SessionAnalysisView sheet (editable)  
**Where result is stored/shown:** `session.structuredNotes`; later “show structured summary” row  

**Feature:** View saved structured summary  
**Entry screen:** SessionEditorView  
**User action:** Show structured summary  
**Result UI:** SessionAnalysisView (`requiresSaveDecision: false`)  
**Where result is stored/shown:** same session field  

**Feature:** Prepare next session  
**Entry screen:** PatientDetailView  
**User action:** Prepare / Last preparation  
**Result UI:** NextSessionPreparationView; or PreparationInsufficientSheet; first-time ContextualTipSheet  
**Where result is stored/shown:** local file / demo store; last-prep row on detail  

**Feature:** Patient AI chat  
**Entry screen:** PatientAIView  
**User action:** Send message or tap suggested question  
**Result UI:** Chat bubbles; thinking label; optional typing animation  
**Where result is stored/shown:** in-memory on this screen only  

**Feature:** Voice transcription (+ anonymization)  
**Entry screens:** PatientDetailView notes; SessionEditorView notes  
**User action:** Record then auto-transcribe (retry if failed)  
**Result UI:** Notes field filled; transcribing/anonymizing status  
**Where result is stored/shown:** notes fields until Save  

**Feature:** AI data-sharing consent  
**Entry screen:** whichever AI action first needs OpenAI (therapist, non-demo)  
**User action:** Accept / decline  
**Result UI:** Consent sheet; Settings shows approved status if accepted  
**Where result is stored/shown:** local per-email UserDefaults  

**NO_UI (service exists, no screen/action):** `challengeFormulation`, `whatAmIMissing`, `longitudinalCaseReview`.

**COMMENTED_OUT:** Settings AI response style; session-editor follow-up list (analysis still includes follow-up fields).

---

## 12. Notifications & Deep Links

### Push notification UX

| Item | Status | Behavior |
|---|---|---|
| Permission request | IMPLEMENTED | After therapist list ready or Patient Mode active |
| Device token / registration | IMPLEMENTED | PushNotificationManager after authenticated mode |
| NSE personalization | IMPLEMENTED | NotificationService + PatientPushPersonalizer |
| Foreground presentation | IMPLEMENTED | Banner, list, sound, badge; re-post if body personalized |
| Types personalized | IMPLEMENTED | `patient_connected`, `questionnaire_completed` (local name from Keychain/App Group) |
| Notification tap → in-app screen | PLACEHOLDER | No `didReceive` response handler; extras (`assignmentId`, `sessionId`) preserved in payload but unused for navigation |
| Patient Mode push copy | UNCERTAIN | Registration exists for patient identity; no patient-specific tap UX found |
| DEBUG send test push | IMPLEMENTED | Therapist Settings DEBUG only |

### Universal Links

| Item | Status | Behavior |
|---|---|---|
| `https://cbtipul.com/invite/<TOKEN>` | IMPLEMENTED | Invitation flow root |
| Other https paths | Not claimed in code | `InvitationLink` ignores non-`/invite/` paths |

Associated domain: `applinks:cbtipul.com`. Also `onContinueUserActivity` browsing web.

### Custom URL scheme `cbtipul://`

| Host | Status | Behavior |
|---|---|---|
| `auth-callback` | IMPLEMENTED | AuthManager.handleAuthCallback (email verification / auth) |
| `password-reset` | IMPLEMENTED | Recovery session + NewPasswordView |
| Other hosts | Ignored unless invitation (invitation is https only) | |

### Invitation links

IMPLEMENTED as §8. Token never persisted; in-memory flow only.

### Password reset links

IMPLEMENTED via custom scheme (not Universal Link in `handleIncomingURL`).

### Other external entry

- Welcome info / consent / Settings: system `openURL` or in-app WKWebView for cbtipul.com legal/support pages.
- Share sheet for invitation URL (outgoing).

---

## 13. User-Visible Data Hierarchy

```
Therapist (email account)
├── Therapist display name (profile; shown to invited patients)
├── Terms acceptance (local)
├── AI consent (local)
├── Onboarding flags (welcome, demo tour, checklist, first-prep tip, display-name prompt)
└── Patients
    ├── Identity: first/last name, status Active|Inactive, avatar color
    ├── Formulation: only treatmentGoal edited in UI (other fields stored if present)
    ├── Patient-level notes (+ optional voice transcript)
    ├── Local “prepare next session” briefing (device)
    ├── Invitation (out-of-band URL; not a persisted child in UI)
    ├── Questionnaires history (GAD-7 + PHQ-9 combined records, not nested-only)
    ├── Diary 1 entries (patient-scoped, not session-scoped)
    │   └── Patient Mode assignment diary_one (start/stop)
    ├── Sessions
    │   ├── Type (optional protocol stage)
    │   ├── Date
    │   ├── Session notes (+ voice)
    │   ├── Structured AI analysis (optional)
    │   └── Combined mood questionnaire (0 or 1 per session)
    │       └── Optional Patient Mode assignment questionnaire (pending until submitted)
    └── AI chat (ephemeral, not a stored object)

Patient Mode (anonymous Auth)
└── Open assignments
    ├── questionnaire → one fill then gone from open list
    ├── diary_one → ongoing create-only entries
    └── diary_two / unknown → upcoming placeholder
```

Protocol session types in the type picker (labels localized): first phone call, intake, psychoeducation, diary 1/2/3, case formulation, behavioral interventions, relapse prevention and termination, plus “none”.

---

## 14. Complete Screen Index

| Screen | View/Class | Mode | Parent/Entry Point | Main Purpose |
|---|---|---|---|---|
| Splash | SplashView | Global | App launch overlay | Brand while restoring session |
| Sign In / Sign Up | AuthView | Unauth | Root if no session | Therapist email auth |
| Verify email | AuthView verificationCard | Unauth | After sign-up | Prompt to confirm email |
| New password | NewPasswordView | Global sheet | password-reset URL | Finish recovery |
| Display name (optional) | TherapistDisplayNameEditorView | Therapist gate | Post-login | Prompt patient-facing name |
| Terms (blocking) | TermsView | Therapist gate | After display-name | Accept terms |
| Welcome | WelcomeOnboardingView | Therapist / Demo | After terms; Settings demo | Intro + start/skip demo |
| Welcome info | WelcomeInfoSheet | Therapist | Welcome info link | Storage/privacy blurb |
| Patients list | PatientListView | Therapist | After gates | Patient directory |
| Add patient | AddPatientView | Therapist | Patients list | Create patient |
| Patient detail | PatientDetailView | Therapist | Patients list | Patient hub |
| Edit name | PatientDetailView sheet | Therapist | Detail pencil | Edit first/last name |
| Edit treatment goal | PatientDetailView sheet | Therapist | Detail pencil | Edit goal |
| Sessions | PatientSessionsView | Therapist | Detail | Session list |
| Session editor | SessionEditorView | Therapist | Sessions sheet | Create/edit session |
| Session date picker | SessionEditorView sheet | Therapist | Existing session | Change date |
| Questionnaire (therapist) | CombinedMoodQuestionnaireView | Therapist | Session / Getting Started sheet | Fill/edit GAD-7+PHQ-9 |
| Completed questionnaire | CompletedQuestionnaireView | Therapist | Questionnaires list | Read-only answers |
| Questionnaires history | PatientQuestionnairesView | Therapist | Detail | List + graphs |
| Diary 1 | PatientDiaryOneView | Therapist | Detail | Entries + Patient Mode toggle |
| Diary 1 form | DiaryOneEntryFormView | Therapist | Diary 1 | Create/edit entry |
| AI chat | PatientAIView | Therapist | Detail | Patient-context chat |
| Session analysis | SessionAnalysisView | Therapist | Session editor | Review AI summary |
| Next session prep | NextSessionPreparationView | Therapist | Detail | Pre-session briefing |
| Prep insufficient | PreparationInsufficientSheet | Therapist | Detail generate | Not enough data |
| First prep tip | ContextualTipSheet | Therapist | First prepare | Education |
| Invite share | ActivityShareSheet | Therapist | Detail invite | Share invitation URL |
| Display name (required) | TherapistDisplayNameEditorView | Therapist | Settings / invite | Set name |
| Settings | SettingsView | Therapist | Patients gear | App/account settings |
| Text size | TextSizePickerView | Both | Settings | Dynamic Type override |
| Appearance | AppearancePickerView | Patient | Patient Settings | Light/dark |
| Terms (read-only) | TermsView | Both | Settings | Read terms |
| Official link | OfficialLinkWebView | Both | Settings rows | In-app web |
| Demo showcase intro | DemoShowcaseIntroView | Therapist demo | List cover | Post-tour explore |
| Demo banner / coach | DemoModeBanner, TutorialCoachCard | Therapist demo | demoModeChrome | Demo + tutorial dock |
| AI consent | AIDataSharingConsentView | Therapist | First AI call | OpenAI sharing consent |
| Invitation loading/activating | PatientInvitationFlowView | Invitation | Universal Link | Preview/claim |
| Invitation preview | PatientInvitationFlowView | Invitation | Valid token | Therapist name + continue |
| Invitation consent | PatientInvitationConsentView | Invitation | Preview continue | Patient consent |
| Invitation unavailable/failed | PatientInvitationFlowView | Invitation | Bad token / errors | Expired/claimed/etc. |
| Patient Mode home | PatientModeView | Patient | Active anonymous context | Task list |
| Patient questionnaire | PatientQuestionnaireView | Patient | Task card | Fill assignment |
| Patient diary entry | PatientDiaryOneEntryView | Patient | Task card | Create diary 1 entry |
| Patient Settings | PatientSettingsView | Patient | Patient Mode gear | Patient-safe settings |
| Activation incomplete | PatientActivationIncompleteView | Patient | Anonymous routing | Not fully active |
| Context retry | PatientContextRetryView | Patient | Anonymous routing | Reload context |
| Patient connecting | ContentView loading | Patient | Anonymous loading | Wait for context |
| Delete code challenge | deleteCodeChallenge alerts | Therapist | Destructive deletes | Numeric confirm |
| PrivacyPolicyView | PrivacyPolicyView | — | Preview only | **NO_UI** in product |

---

## 15. Complete Navigation Graph

```
LAUNCH
  Splash (1.5s overlay)
  + onOpenURL / Universal Link
      cbtipul://auth-callback     → AuthManager (stay on Auth or complete sign-up)
      cbtipul://password-reset    → recovery sheet NewPasswordView
      https://cbtipul.com/invite/TOKEN → INVITATION ROOT (overrides everything)

INVITATION ROOT
  loading → preview → consent → activating → dismiss
       |        |         |                      \→ PATIENT MODE (anonymous + active)
       |        |         \→ activationFailed → Retry / Close
       |        \→ Close → AUTH or THERAPIST (if still signed in non-anon)
       \→ unavailable/failed → Close

UNAUTHENTICATED
  AuthView
    Sign In ───────────────→ THERAPIST GATES
    Sign Up → verify email → (link) → THERAPIST GATES
    Forgot password → email → (link) → NewPasswordView → THERAPIST GATES | Cancel → AuthView

THERAPIST GATES
  [optional display name] → [Terms Agree] → [Welcome Continue|Skip] → PATIENTS LIST
                              Welcome Continue also ENTERS DEMO

PATIENTS LIST  (NavigationStack)
  │ toolbar: Settings sheet, Add patient sheet
  │ empty: Add + optional Enter demo
  │ demo: banner, coach, showcase intro cover
  │ Settings → Getting Started → Welcome cover (demo consent)
  │
  └─► PATIENT DETAIL
        ├─► Sessions ─sheet─► Session Editor
        │                      ├─► Questionnaire (push)
        │                      ├─sheet─► Session Analysis
        │                      └─ Send questionnaire to patient ──(backend)──► PATIENT MODE task
        ├─► Questionnaires ─► Completed Questionnaire (read-only)
        ├─► Diary 1 ─► Entry form
        │     Start/Stop Patient Mode diary ──(backend)──► PATIENT MODE diary card
        ├─► AI Chat  (ephemeral)
        ├─ Invite ─► share URL ──► INVITATION ROOT (other device/user)
        ├─ Prepare next session ─sheet─► Preparation / Insufficient / Tip
        └─ Notes (patient-level) + voice

ANONYMOUS SESSION (no invitation overlay)
  loading → Patient Mode | Incomplete (Retry) | Context Retry (Retry)

PATIENT MODE  (NavigationStack)
  │ Settings sheet → Leave → AUTH
  ├─► Questionnaire assignment → submit → home
  ├─► Diary 1 assignment → submit → home
  └─ diary_two/unknown → placeholder card (no destination)

PUSH TAP: open app only (no graph edge to a screen)
```

**Reading this graph:** Therapist work is a single stack from Patients → Patient → children, with most session work in sheets. Patient Mode is a separate root with a task list only. Invitation is a third root that can interrupt either identity and then lands in Patient Mode.

# Existing contracts and open dependencies

Inspected current Android/iOS auth, app context, entitlements, patient/session stores, questionnaire/diary repositories, AI gateway/prompts, notification/message flows, local names and legal strings. `CLAUDE.md` was read. There is no backend source or website source in this checkout. The public `https://cbtipul.com` homepage was read: Cloudflare serves it and links to `/privacy/`, `/terms/`, `/support/`, `/privacy-choices/`, and `/delete-account/`.

Older `CBTIPUL_CURRENT_UX.md` claims there is no message UI and describes older diary states. Current repositories contain supported messages and Diary 2/3; code takes precedence.

| Area | Reused contract | Authoritative mobile source |
|---|---|---|
| Role/access | `get-app-context` → `role`, `entitlement.access` (`full` / `read_only`) | `android/.../data/AppContext.kt`, `EntitlementAccess.kt`; `ios/EntitlementAccess.swift` |
| Therapist name | `therapist_profiles(therapist_id,display_name)`; explicit upsert only if needed | `android/.../data/TherapistProfile.kt` |
| Patients | `Patients(id,active,notes,formulation)`; insert `{active}` and return server ID; goal in `formulation.treatmentGoal` | `android/.../data/PatientRepository.kt` |
| Sessions | `Sessions(id,patient_id,session_date,notes,type,structured_notes)`; date-only string | same, `sessionWriteBody` |
| Questionnaires | `CombinedMood(id,patient_id,session_id,created_by,answered_date,gad7_answers,phq9_answers,interference_level,combined_notes)` | same, `loadQuestionnaires` / `saveQuestionnaire`; `model/QuestionnaireTrend.kt` |
| Connection | RPC `is_patient_connected({p_patient_id})` | `data/PatientAssignment.kt` |
| Assignment status | `patient_assignments(id,patient_id,type,session_id,cancelled_at,created_at)`; ongoing if patient-level and not cancelled; completion does not deactivate questionnaire | same |
| Activation | `request-patient-questionnaire`, `request-patient-diary-one`, `request-patient-diary-two`, `request-patient-diary-three`, each `{patientId}`; fetch/verify active row after success | same; `ios/PatientAssignment.swift` |
| Cancellation | update assignment's `cancelled_at` under existing RLS | same |
| Diary 1 | `diary_one_entries`: event, automatic_thoughts, feelings, behaviour, physical_symptoms, provenance/timestamps | `data/DiaryOne.kt` |
| Diary 2 | `diary_two_entries`: event, automatic_thoughts, feelings, thinking_errors, alternative_thoughts, provenance/timestamps | `data/DiaryTwo.kt` |
| Diary 3 | `diary_three_entries`: situation; automatic thoughts `{text,beliefBefore,beliefAfter}`; feelings `{name,intensityBefore,intensityAfter}`; alternative thoughts `{text,belief}`; thinking_errors; provenance/timestamps | `data/DiaryThree.kt` |
| Clinical text | `anonymize-clinical-text({text,therapistIdentifiers:[]})` → `anonymizedText` | `data/ClinicalTextAnonymizer.kt` |
| Chat | `openai-gateway({model:"gpt-4o-mini",messages,temperature:0.4})`; current clinical prompt and provenance, no direct OpenAI | `data/AiService.kt`, `AiPrompts.kt`, `ui/patients/PatientAIScreen.kt`, `PatientRepository.diaryChatContext` |
| Analysis | `analyze-session({sessionNotes})` → `analysis` | `data/AiService.kt` |
| Preparation | `prepare-session({patientContext,lastSessionAssignments})` → `preparation` | `data/PatientContext.kt`, `AiService.kt`; order: `ios/NextSessionPreparationView.swift` |
| Notifications | `notifications` filtered by `recipient_user_id`; RPCs `mark_notifications_seen`, `mark_notification_read({p_notification_id})` | `data/NotificationRepository.kt`, `AppNotification.kt` |
| Messages | `patient_messages(id,patient_id,body,created_at,read_at)`; `send-patient-message({patientId,body})` | `data/PatientMessage.kt` |

`android/...` above expands to `android/app/src/main/java/com/cbtipul/app/`.

## Important discrepancies / limits

1. **Questionnaire assignment insertion:** the brief mentions an existing direct-insert/RLS assignment flow. Neither checked-in mobile implementation has that path: both invoke `request-patient-questionnaire`. Web follows the actual code; it does not invent an insert payload/RLS permission. Questionnaire **result entry**, separately, uses the existing direct `CombinedMood` insert/RLS path. If assignment creation was changed outside this checkout, supply its current supported insert columns, defaults, required ownership, uniqueness behavior, and notification trigger contract before changing the web path.
2. **Questionnaire dates:** `answered_date` is the measurement date. Neither current mobile result query exposes an actual creation timestamp. Web does not substitute “today”, a session date, or invented `created_at` for a missing measurement date. Native result `session_id` associations are preserved when reading; new web entries are explicitly patient-level (`session_id:null`). A creation timestamp display requires confirmation of an exposed column and its semantics.
3. **Preparations:** native preparations are saved in device-local cache (`SavedPreparation`), with no shared storage contract. Web retains its latest generated preparation only in memory. Cross-device preparation history requires a supplied authorized backend storage contract.
4. **Files:** no current patient file list/upload/download contract, storage bucket/policy, or usable file UI was found. No file button is exposed. Required support: authoritative file metadata table/schema, patient ownership, storage bucket/object naming, permitted MIME/size limits, authorized list/upload/delete/signed-download operations and RLS/storage policy behavior. No endpoint has been invented.
5. **Deletion:** no web deletion control is exposed. Mobile invokes `delete-account` and handles `appleManualRevocationRequired`, but no backend source was available to verify browser authorization/CORS or browser-created Apple-account revocation. Confirm the existing function is allowed for web JWTs, response semantics and token-revocation behavior before adding it. Existing website `/delete-account/` and mobile deletion stay unchanged.
6. **AI errors:** HTTP 429 and known quota-style codes show a Hebrew quota message. Other failures show safe retry guidance, never the raw response. Exact production gateway error payloads and server quota enforcement were not live-tested; their server contract remains authoritative.
7. **Permissions, CORS and data compatibility:** RLS/storage/provider/function configuration were not inspected in a live backend. No real auth or clinical mutation was performed. Existing JWT authorization is reused. Live provider callback, browser CORS, RLS and representative older records need authorized verification before public release.
8. **Legal copy:** current mobile terms/privacy/AI consent are reused verbatim, but some statements describe mobile encrypted name storage or voice features. Web explicitly says names are browser-local and unencrypted, and implements no voice upload. Obtain approved web-specific legal wording before release rather than silently rewriting legal policy.
9. **Voice, patient mode, native push, payments and file sharing** are outside this initial therapist web interface. There is no demo bypass or hardcoded therapist access.

# CBTipul

## Platform
Native iOS and Android clients, plus a separate therapist web workspace and public website. This design task covers only the native SwiftUI iOS patient detail screen.

## Users and purpose
Hebrew-speaking CBT therapists review patient submissions, maintain patient-level diaries and questionnaires, record treatment sessions, and communicate with patients. Patient names are device-local. Existing clinical terminology and privacy boundaries must be preserved.

## Current task — confirmed
The patient detail redesign should prioritize reviewing new patient activity. The user chose visual concepts before implementation. Keep the treatment goal at the top and preserve every existing action. Do not alter Android, backend contracts, web pages, clinical models, or authentication as part of this redesign.

## Existing capabilities
Patient name and active/inactive status editing; treatment goal editing; new session and session history; patient notes; diaries 1–3; questionnaires and trends; messages; patient invitation/connection and sending; session preparation and AI assistance. Recent submissions are already grouped relative to the latest session. Do not invent clinical summaries, scores, trends, or activity counts.

## Brand and accessibility
Reuse CBTipul navy/gold identity and the current adaptive light/dark Theme tokens. Hebrew RTL, native navigation, Dynamic Type, accessible labels and touch targets. Clinical content must not enter analytics or logs.

## Success
The therapist can identify new submissions, inspect them, and choose the next action without scanning a long undifferentiated menu. No action or existing safety behavior is lost. Review concepts before changing app implementation.

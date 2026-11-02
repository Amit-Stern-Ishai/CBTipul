# Approved patient home C and iOS paper light mode

Approved by the user on 22 October 2026. Mode: Operate.
Reference: outputs/patient-experience/index.html in the Codex workspace, concepts C (patient home) and B (iOS light visual system).

Patient home, both native platforms: welcoming header, one prominent resumable draft when one exists, messages, then all available tools/history. Keep assignment eligibility, local draft detection, read state, refresh, navigation, clinical forms and submission behavior. Do not invent activity or progress. Questionnaire drafts use neutral continuation copy rather than thought-specific copy. Android retains native Material controls; iOS uses native SwiftUI navigation and Dynamic Type.

iOS light appearance: warm paper #FAF7F1, lilac #EDE7F2, plum primary ink #352144, secondary ink #665A6F, primary actions #5C4476, pressed #49325F. White paper cards use subtle warm/lilac boundaries. Shared cards have 14pt corners; primary buttons 10pt in light mode. Patient/session headers must resolve to light surfaces and dark text, not fixed dark material. Patient identity colors and clinical semantic colors remain meaningful. Questionnaire historical frequency and recency calculations remain unchanged, with three lilac fills in light mode. Dark appearance remains navy/gold.

Verification: Android compilation and 328 JVM tests passed. Full iOS simulator build passed using current ios source in the existing local mirror. Native light-mode UI verification is in progress; do not treat this document as a visual-fidelity approval. No backend, web or release changes.

Final verification: full Android debug and iOS simulator builds succeeded. Android 328 unit tests passed. Five iPhone light-mode UI checks passed across the two bounded rounds (patient/session lists, patient detail, session editor, session questionnaire). Corrected action overlap and journey icon contrast; updated stale session accessibility selectors based on observed UI labels. Actual native screenshots are in the Codex outputs/patient-native-final directory. Patient Mode C compiled on both platforms but has not yet been visually inspected with an active patient invitation/account. No claim of whole-app visual coverage or live backend testing.


## Android extension — 22 October 2026
User approved extending B's light visual direction to Android. Native Compose layouts remain intact: warm paper base #FAF7F1, lilac #EDE7F2, plum ink #352144 and actions #5C4476. Secondary text #6C6073 meets 4.5:1 on lilac. Patient color remains a subtle header tint. Questionnaire history uses three lilac bands with plum text in light mode and retains the ocean palette in dark mode. Clinical semantic colors and scoring are unchanged.

Patient Mode C is implemented on both platforms. Native synthetic home screenshots cover assigned tools and empty messages; they do not establish live invitation, message delivery, or draft recovery behavior. Shared Android palette contrast tests cover text, actions and every history band in both appearances.

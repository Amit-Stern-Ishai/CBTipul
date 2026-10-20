# iOS patient detail
Mode: Operate. Approved: activity digest concept with treatment journey, then explicit four record actions and AI chat. Native SwiftUI implementation only.

## Direction contract
THESIS: Let the therapist see what arrived since the last session before browsing the full record. Use a single content identity header and replace the menu-like stack.
OWN-WORLD: Existing adaptive Theme base/surface/text/gold tokens, system Hebrew typography, SF Symbols, native navigation and dynamic type. No new palette or decorative imagery.
STORY: Read the treatment goal, understand the recorded sequence, inspect new submissions, start or prepare a session, then browse records or chat.
FIRST VIEWPORT: Single title.bold patient name beside the existing 52 pt InitialsAvatar in the content header; navigation title stays empty and inline. Status and compact expandable goal share the header, tinted with patientColor at 18% over Theme.surface. The journey follows on a 12% patient-color surface, then the connection/send strip; recent activity grouped into readable rows. New-session primary action and preparation secondary. Record grid in RTL DOM order: sessions, graphs, diaries, questionnaires. AI chat is a full-width fifth action. Notes and messages stay below.
FORM: Activity digest, candidate 1 in the surface hand 0d675d10; approved concept with journey at outputs/ios-patient-concepts. User-approved amendments supersede the original comp's grid.
INTERACTION: Journey groups consecutive actual types chronologically, retains unknown types and excludes future dates; the heading and stage controls open a read-only stage timeline with counts and date ranges. Horizontal order is oldest RIGHT to newest LEFT; full vertical timeline and accessibility fallback are newest TOP. Four groups fit across; more scroll horizontally. Icons remain 16 pt inside 36 pt circles. Existing native transitions, no decorative motion.
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping asset in the project.

## Earlier digest finish verification — 2026-10-19 (before A/C refinement)
Independent finish review: SHIP for scoped iPhone review after correcting RTL disclosure/chronology arrows, singular journey count, history surface and largest-text new-session label. Xcode 26.6 build on iPhone 17 Pro Simulator (iOS 26.5): two journey unit tests and four UI tests passed; final targeted largest-text test passed after label fix. Dark/light, empty/populated, journey navigation, AI/diary navigation and patient-bound new session checked. Populated activity used synthetic records in a temporary checkout only. No live backend verification, physical-device/VoiceOver verification, or iPad validation. Screenshots: got/outputs/ios-patient-digest/final-review and large-fixed. No commit, push or release performed.

User refinement: retain approved order; use neutral horizontal borders between major sections to make group boundaries clear. Preserve actions, typography and native layout.

Superseded exploration: larger navigation title and two-stage compact summary were replaced by the approved A-horizontal + C-patient-color content header. The full journey remains stages only (no session list or editor). Existing sections and dividers are retained.

Journey timeline displays the latest stage at the top; date ranges and consecutive grouping remain unchanged.

Approved A horizontal journey plus C patient-color header. References: .impeccable/mocks/patient-horizontal/horizontal.png and header.png. Latest horizontal stage goes LEFT (user correction), vertical history stays newest at top. Full chronological groups, compact expandable goal, real per-patient palette. At accessibility size preserve readable vertical flow; overflow histories scroll. Generated mockup labels remain illustrative.

### Journey emphasis — 2026-10-20
The inline journey now has a visible, tappable heading, a 16% black translucent fill, a 25% white 1 pt outline, 14 pt corners and 10 pt inset. Horizontal markers grow from 24 to 30 pt with 15 pt symbols and a 3 pt connecting line. Patient color, newest-at-left ordering, treatment-goal placement and journey destinations are unchanged.

### Compact header and session shortcut
The journey retains its translucent boundary but uses a static compact heading, 6 pt vertical inset and 26 pt markers. Stages remain tappable, with latest on the left. Identity spacing is reduced. Invitation has 10 pt exterior vertical spacing; the session action group has 12 pt exterior spacing. “הפגישה האחרונה” opens the latest recorded session through the existing editor; future days are excluded, and the shortcut is omitted when no recorded session exists.

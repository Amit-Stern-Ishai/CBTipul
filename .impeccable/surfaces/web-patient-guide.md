# Web patient workspace — Operate

Visual authority: supplied `design-system (1).md` and its inspected [sky-blue patient artifact](https://claude.ai/artifact/6bjtKfJ84NuQvt3NgNSMSV#play-53094030cabe), 2026-11-18. Reference access is resolved. The prior provisional overview sidebar is superseded by the implemented reference composition.

Overview: compact navy shell, sky-blue patient identity band, local Rubik, available clinical score labels, shared-view access, turquoise start action and calendar/list switch. Month/today controls, category filters and navy add menu sit above either a seven-day-column calendar or weekly sessions/questionnaires/diaries columns. The list groups newest weeks first; undated records appear separately. Entity tints and navy icons distinguish categories; labeled severity fills preserve existing clinical meaning.

At 850px and below, identity/actions wrap and weekly columns stack with category headings; calendar scrolls horizontally at a 700px minimum grid. Desktop overview uses 28px insets; narrow screens use 16px. Existing clinical subpages keep their rail/wrapped navigation independently of the overview.

Real records link to existing editors through entry parameters. Start/add open forms through new=1 without automatic saves, scheduling or an inferred timer. Respect permissions and shared-view access. No invented contacts, attachments, appointments, trends or patient facts where model data is absent. Public pages and shared Zoom presentation retain their contracts.

Sources: web/src/workspace/PatientTimeline.tsx, patient-timeline.css and patient-guide.css. Typecheck, lint, 152 unit tests, 36 patient-workspace browser tests and the combined production build pass. Desktop calendar/list and phone list captures inspected with synthetic data. Public content/verification preservation test passes; the unchanged clinical-consent hash assertion fails and is outside this design change. No live clinical services exercised. Review gallery: outputs/web-patient-reference-exact/index.html in the Codex workspace.

## Exact-reference pass, 2026-11-18
Read the linked artboard DOM styles directly. Desktop uses its 115% presentation scale, 64px shell, 112px minimum identity band, 30px/38px name, 32px headline badges, 38px actions, 32px view toggle, 150px calendar rows and 22px calendar entries. Weekly list has no calendar toolbar; 24px column gutters, 52px tinted icon wells, 64px minimum cards, and whole-week hover. Sticky offset follows actual identity height. Mobile preserves a compact Add menu; desktop diary action chooses among all three diary types. Keep real account identity/logo and existing shared view; do not copy fictional contacts or add nonfunctional attachment/scheduling controls.

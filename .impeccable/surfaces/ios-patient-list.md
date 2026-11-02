# iOS patients list

Mode: Operate. Refine the native directory to match the patient workspace without changing navigation, search, alphabetic/status grouping, activity counts, onboarding, or permissions.

PatientListView uses the existing large navigation title and native search, plain List sections, and per-patient row surfaces. Each row uses Theme.surface, 5.5% patient-color wash, 30% patient-color 1 pt outline, 14 pt corners, and 4 pt vertical separation. Names use title3 semibold; initials are 50 pt; date information is footnote with a calendar symbol. Existing recent-submission text has a Theme.goldGhost background with 8 pt corners. No new clinical data or counts are inferred.

The directoryStyle option is opt-in; other uses of PatientListRow retain their existing sizing. Existing semantic colors, Hebrew labels, RTL and combined accessibility labels remain authoritative.

---
name: CBTipul — iOS Patient Detail
description: Screen-scoped activity digest using the existing adaptive native theme
colors:
  base-dark: "#0C1420"
  base-light: "#FAF7F1"
  surface-dark: "#172231"
  surface-light: "#FFFFFF"
  elevated-dark: "#202E40"
  elevated-light: "#EDE7F2"
  borderFaint-dark: "#2C394B"
  borderFaint-light: "#E4DCD2"
  borderDefault-dark: "#3B4B60"
  borderDefault-light: "#D6C9DE"
  borderStrong-dark: "#60738C"
  borderStrong-light: "#96849F"
  textBright-dark: "#F3F5F8"
  textBright-light: "#352144"
  textBody-dark: "#B4C0D0"
  textBody-light: "#665A6F"
  textFaint-dark: "#8999AE"
  textFaint-light: "#73677A"
  gold-dark: "#E2BB76"
  gold-light: "#5C4476"
  accentFill-dark: "#E2BB76"
  accentFill-light: "#5C4476"
  accentFillPressed-dark: "#C49C58"
  accentFillPressed-light: "#49325F"
  textOnAccent-dark: "#0C1420"
  textOnAccent-light: "#FFFFFF"
  warning-dark: "#FFC94A"
  warning-light: "#946000"
  error-dark: "#FF5C68"
  error-light: "#BC3346"
typography:
  patient-title:
    fontFamily: "system-ui"
    fontWeight: 700
  headline:
    fontFamily: "system-ui"
    fontWeight: 600
  section-title:
    fontFamily: "system-ui"
    fontWeight: 600
  body:
    fontFamily: "system-ui"
  label:
    fontFamily: "system-ui"
rounded:
  prominent-button: "12px"
  goal: "10px"
  record: "12px"
  content-card: "14px"
  records-container: "16px"
  header-bottom: "24px"
spacing:
  row-detail: "4px"
  compact: "8px"
  group: "12px"
  section: "6px"
components:
  button-primary-dark:
    backgroundColor: "{colors.accentFill-dark}"
    textColor: "{colors.textOnAccent-dark}"
    rounded: "{rounded.prominent-button}"
    height: "44px"
  button-primary-light:
    backgroundColor: "{colors.accentFill-light}"
    textColor: "{colors.textOnAccent-light}"
    rounded: "{rounded.prominent-button}"
    height: "44px"
---

# Design System: CBTipul — iOS Patient Detail

## Overview

**Creative North Star: "Activity digest"**

This document captures the rebuilt native iOS PatientDetailView only. Final compact-layout verification passed: 2 journey unit tests and 5 iPhone UI tests using synthetic data. At default text size, AI, notes and messages are initially hittable and the notes control clears the tab bar; large text remains scrollable. This document describes current source behavior and makes no claim of pixel-perfect mockup fidelity. Its calm, compact treatment workspace uses the existing CBTipul navy/gold identity and adaptive Theme.swift values. It establishes no new app-wide visual identity and does not apply the screen composition to Android, the web workspace, or other iOS screens.

Existing brand tokens remain authoritative in ios/Theme.swift. The approved screen composition and interaction contract live in .impeccable/surfaces/ios-patient-detail.md, with the A-horizontal and C-patient-color approval recorded in .impeccable/mocks/patient-horizontal/approval.json; PRODUCT.md supplies the Hebrew, accessibility, and clinical privacy constraints. The UI presents recorded activity without implying clinical improvement.

**Key Characteristics:**
- Native Hebrew RTL navigation and system typography.
- Existing adaptive navy/gold and cool light surfaces.
- Compact recorded activity with explicit, accessible actions.
- Patient-color identity header and horizontal recorded journey.

## Colors

The dark appearance combines midnight navy surfaces and warm gold actions; light appearance uses cool neutral surfaces, navy primary fills and blue links.

### Primary
Use Theme.accentFill for new-session emphasis, Theme.textOnAccent for its label, and Theme.accentFillPressed for the pressed fill. Theme.gold identifies links and preparation. The full-width AI row now uses native Color.purple for its icon, a 14% purple fill and a 65% purple outline. This is a screen-local treatment, not a replacement brand palette; retain the native color rather than asserting an unverified fixed hex. The frontmatter suffixes describe the two resolved appearances of each existing token; they are not new Swift tokens.

### Neutral
Theme.base supports the screen and Theme.surface the bordered content blocks. Theme.textBright, textBody and textFaint preserve body hierarchy. Theme.borderDefault supplies content outlines and dividers; borderFaint outlines the activity card and borderStrong outlines preparation.

The identity, goal and horizontal journey share PatientHeaderBackdrop, a layered patient-hue treatment extending behind the toolbar. Its base is the explicit existing dark navy value recorded as colors.base-dark in the frontmatter (UIColor hex 0x0C1420 in source), kept dark in both appearances. It does not rely on the dynamic Theme.base provider or a local color-scheme override to force the header dark. Over this canvas, patient accent forms a top-trailing to bottom-leading linear light at 62% to 12% opacity and a top-trailing radial light at 42% to transparent, with radius 1.1 times the available width. Three translucent white diagonal planes use 4.5%, 3.5% and 5% opacity, followed by a clear-to-black 18% vertical shade. This replaces the earlier opaque header fill.

Header text is white; secondary header text uses white at 85%, and the status capsule uses black at 22%. Native toolbar background is hidden, with dark toolbar color scheme, allowing the screen-level backdrop to continue through the top safe area. Body surfaces retain adaptive Theme values. AccountActionNotices applies its Theme.surface background with ignoresSafeAreaEdges: [], keeping even an empty banner from painting over the status/header region; authentication behavior is unchanged. The goal has dark ultraThinMaterial at 25% opacity with a 1 pt white-at-22% border. The 48 pt initials avatar uses the existing patient accent fading to 68% opacity, a 1 pt white-at-24% outline, and PatientAvatarColor.foreground(for:) for its initials. No new patient palette is introduced.

Journey marker outlines and connectors use the existing patient accent. The newest marker has a solid accent fill and 3 pt ring; earlier markers use the dark patient header fill and 1.5 pt ring. Connectors are 2 pt with accent at 80%. Preserve the existing patientAtmosphere background.

Theme.warning marks an outdated preparation; Theme.error marks actual failures. Pair state color with readable text or icons. Appearance follows the app's existing appAppearance setting, with dark as its current default; do not replace this with a new system-appearance policy.

## Typography

Use SwiftUI system text styles and Hebrew system fallback. Frontmatter fontFamily is a portable representation of native system type, not a new web-font dependency. Point sizes and line heights remain controlled by the native text styles and Dynamic Type rather than fixed CSS sizes.

- Record section heading: headline, natural casing.
- Patient name: bold system type at ScaledMetric 24 pt relative to title2, with a header accessibility trait; status: caption in a capsule.
- Goal: subheadline, medium, compact at two lines with inline expand/collapse; accessibility Dynamic Type shows the full text.
- The header journey has no separate visible heading; its stage buttons open the timeline. Other primary labels use native headline where implemented.
- Record actions and activity titles: subheadline, semibold.
- Horizontal journey labels: caption, semibold; preparation: subheadline, semibold.
- Journey symbols: horizontal 13 pt medium inside 24 pt circles; vertical accessibility fallback 16 pt inside 36 pt circles. Horizontal stack and label gaps are 2 pt; interactive areas remain at least 44 pt high and labels follow Dynamic Type.
- Dates and counts: caption; supporting errors: footnote.

## Layout

Scope: this screen alone. Root layout is ScrollView with a leading VStack, 6 pt section spacing and 12 pt horizontal padding, and 16 pt bottom padding. Navigation title stays empty and inline. The patient name appears once beside the 48 pt gradient initials avatar. Identity, compact material goal and horizontal journey sit over one screen-level backdrop. The header content uses 6 pt internal gaps, 16 pt horizontal padding, 8 pt bottom padding and negative 12 pt outer inset. Header geometry reports its global bottom edge into headerBottom; the background height is the nonnegative difference between that bottom and the background origin. The backdrop ignores the top safe area, continues behind the hidden native toolbar background, and clips only its two lower corners at 24 pt. Height tracks content and scroll geometry rather than a fixed header size.

Read top to bottom: identity/status, goal and journey within the header; connection/send block; recent submissions; session actions; one enclosing record surface containing its heading, four record buttons, full-width AI chat, and notes/messages; saved preparation when present below the enclosure. The record enclosure uses 8 pt padding, 4 pt internal spacing, Theme.surface, a 1 pt Theme.borderFaint outline and 16 pt corners. Records use two flexible columns with 8 pt column gaps and 4 pt row gaps, becoming one column at accessibility sizes. Session actions and notes/messages also stack at accessibility sizes. Record order remains sessions, graphs, diaries, questionnaires in RTL reading order.

Up to four journey groups fit with equal widths. More than four use a horizontal scroller with each stage sized to one quarter of the container width, preserving four equal visible slots. For overflow, the scroller uses a physical left-to-right origin with reversed group iteration and right-to-left stage content; default scroll anchor is leading. Scroll indicators are hidden. On appearance and when the group-ID sequence changes, the scroller targets the latest group with a center anchor; at the chronological end the intended visible arrangement keeps the latest stage at the left. The final compact-layout long-journey check passed. Horizontal order is oldest at the RIGHT and newest at the LEFT; the newest marker is visually emphasized. Full vertical timeline and accessibility fallback place newest at the TOP. Groups remain recorded consecutive types, not predetermined treatment stages.

The goal has 4 pt vertical padding and starts at two lines and expands in place; accessibility sizes show full text. Keep separate expansion and edit actions. Interactive areas have at least 44 pt minimum height. Record rows retain 44 pt minimum height and 10 pt horizontal padding, with no added vertical padding. Other clinical text wraps without fixed heights. CSS pixel values in portable frontmatter represent observed numerical point values; SwiftUI points remain authoritative.

## Elevation & Depth

Use the layered patient-hue light, translucent diagonal planes and native goal material described in Colors, with bordered body surfaces and the existing patient atmosphere. The backdrop is decorative, hidden from accessibility and excluded from hit testing. Reduce Transparency removes the three Canvas planes; the accent lights and bottom shade remain. Native sheets and navigation retain platform depth and transitions. Reuse existing restrained state motion and honor Reduce Motion. Final compact-layout native verification remains pending; documentation does not establish exact mockup fidelity.

## Shapes

The compact new-session action uses 12 pt corners, Theme.accentFill and Theme.textOnAccent with 44 pt minimum height and plain native button style; it no longer uses the shared padded pressableProminent style. The outlined goal uses 10 pt corners and dark ultraThinMaterial at 25% opacity and a 1 pt white-at-22% outline. Connection, activity and preparation use 14 pt corners with 1 pt outlines; record and AI controls use 12 pt corners with 1 pt outlines. Status is a capsule. Journey circles are 24 pt horizontally and 36 pt in the accessibility fallback. These are explicit ScrollView components, not native List row shapes.

## Components

- **Identity and goal:** the 48 pt gradient initials avatar, ScaledMetric 24 pt bold white patient name and status capsule sit above the outlined compact goal over the layered patient-hue backdrop. Goal text uses two lines initially, with a tappable text area and chevron for expand/collapse, plus a separate labeled pencil action. Accessibility Dynamic Type exposes the full text without requiring expansion. Empty goals use the existing localized placeholder and keep editing available.
- **Journey:** show all consecutive recorded session-type groups, with actual counts, fixed-size SF Symbols inside outlined patient-color circles and connecting rules. The newest LEFT marker has the stronger ring and solid accent fill. Four or fewer fit horizontally; longer histories scroll. Horizontal chronology runs oldest right to newest left. There is no separate journey heading inside the patient header; stage controls open the full read-only stage timeline, which shows newest at top with counts and date ranges. The accessibility-size in-place fallback also shows newest at top. Preserve unknown types and exclude future calendar days. The timeline is not a session browser/editor or clinical progress meter; session browsing remains in the explicit sessions destination.
- **Connection/send strip:** a full-width 44 pt minimum rounded bordered strip with 10 pt horizontal padding and no added vertical padding, compact caption status and a short outlined send action in the connected state. The connected label and send action retain their full accessibility labels. Status/action use a horizontal layout normally and vertical layout at accessibility sizes. Reinvite is in the top toolbar overflow menu, not another control in the status strip; preserve checking, connected, disconnected, failed/retry and unavailable states, invitation guidance and sending flows.
- **Recent activity:** a compact bordered card with zero stack spacing, 12 pt horizontal/4 pt vertical padding and 44 pt header controls and rows, showing the two latest non-dismissed submissions by default, with actual count, dates and destinations. More than two exposes a show-all/show-less chevron in the header. An ellipsis menu dismisses the current activity IDs for the owner/patient; clinical records remain accessible through their destinations. Row title/date share a line normally and stack at accessibility sizes. Preserve failure/retry and hidden-empty behavior; do not invent summaries or trends.
- **Session actions:** compact plain-style 44 pt minimum new-session button and outlined rounded preparation action. Busy preparation shows its native progress indicator and disables repeat requests. Preserve entitlement controls and saved-preparation stale labeling.
- **Records and AI chat:** four explicit record destinations, then the fifth full-width violet AI chat action. The heading, four record buttons, AI row and notes/messages share a single enclosing bordered surface. Record buttons are bordered rounded controls with patient-color icons; AI uses the sparkle icon and native purple treatment. Compact AI and notes labels retain their full accessibility labels. Diaries open the existing diary directory. Graphs enter the graph destination directly. Icons supplement text and decorative chevrons stay hidden from accessibility.
- **Notes/messages and editing:** retain native destinations, voice transcription, save/discard protections, patient status/name editing, goal editing and deletion protections. Inputs remain existing native editors; this document introduces no new input styling.

Repository UI assertions require AI, notes and messages to be hittable initially and the notes control to remain above the tab bar. These assertions passed with the final 6 pt root gap on iPhone 17 Pro Simulator in dark and light appearance.

The sidecar previews are illustrative HTML equivalents of native patterns for the design panel, not production assets or pixel-exact SwiftUI renderings. Production uses SF Symbols and native Button/NavigationLink semantics, focus, disabled state and VoiceOver behavior.

## Do's and Don'ts

- Do preserve adaptive Theme body surfaces, layered patient-hue backdrop and the scoped native purple AI treatment.
- Do preserve Hebrew RTL order, readable wrapping, Dynamic Type and labeled native actions.
- Do preserve all existing destinations and safety behavior.
- Do derive activity counts and journey groups from recorded data.
- Do place the newest stage at the left horizontally and at the top vertically.
- Do derive header and journey colors from the existing patient palette, using white header text and adaptive body text.
- Don't apply this screen's composition as an app-wide redesign.
- Don't invent clinical summaries, progress stages, scores or trends.
- Don't use color alone to express connection, failure or clinical meaning.
- Don't replace native iOS interactions with web-style controls.


### Patient header translucency refinement
The header now uses dark ultraThinMaterial instead of an opaque navy base. The patient-color tint is 28% to 8%, with an 18% radial accent and 6% bottom shade. The previous white brightness wash is removed. The existing translucent facets and compact geometry remain. Reduce Transparency uses the solid navy fallback. This supersedes the earlier opaque-backdrop description.

The selected midpoint retains ultraThinMaterial under a 50% navy veil, with 46%–15% patient tint, 30% radial accent, 5%–1.75% light wash and 9% bottom shade. Light appearance uses a 17% contrast scrim. This replaces the stronger-translucency values above; geometry is unchanged.


### iOS session editor — approved A (screen-local)

The session editor uses the approved summary-first A direction and the heading **סיכום הפגישה**. Its contract and validation are recorded in [.impeccable/surfaces/ios-session-editor.md](.impeccable/surfaces/ios-session-editor.md). This extension does not change the patient-detail decisions above or establish a global redesign.

`SessionEditorView` uses an 18 pt scroll rhythm and horizontal inset, a patient identity/date/type header, the existing summary editing sheet, recording, an optional AI panel, the existing questionnaire and a pinned save action. Preserve date/type-first creation, stop → transcription → anonymization, AI review and save/discard protections. Native system typography, Hebrew RTL, patient palette and adaptive Theme body tokens remain authoritative.

Session-local header values are #233D44 with a 34% patient-color gradient and a 4.5% white plane; the toolbar is #285454. Identity uses a 42 pt initials circle; date/type controls have 9 pt corners and 44 pt minimum height. Recording uses 12 pt corners, 10% patient-accent fill and 40% outline. AI uses native purple at 8% fill/30% outline, 12 pt corners and 14 pt padding. Summary and AI help use Theme.textBody following contrast review. These observed values do not replace patient-header styling or the existing frontmatter tokens. Build, creation and dark/light summary/edit/discard checks passed, including the final contrast-corrected build and dark/light edit/discard rerun. Final captures are complete; reviewer contrast verification passed in both appearances; the finding is resolved. Live microphone/backend behavior was not tested.

The summary interaction refinement separates full-text reading from writing, preserves the draft across modes, and shares recording/recovery controls between overview and summary. See the session surface brief for the current interaction contract and verification limits.


## Approved iOS light redesign — 22 October 2026

The user approved concept B (personal notebook) as the entire iOS light visual direction, superseding the cool-neutral/blue light appearance described above. Paper #FAF7F1, lilac #EDE7F2, plum ink #352144 and plum actions #5C4476 are authoritative in Theme.swift. Headers, shared cards/buttons, settings preview and questionnaire-history fills follow this direction. Dark tokens and clinical semantics remain unchanged. Patient Mode uses concept C’s composition on both platforms, with B’s visual treatment in iOS light appearance. See .impeccable/surfaces/patient-home-c-and-ios-paper.md for scope and verification.


### Approved Android paper appearance (2026-10-22)
Extend Concept B's approved iOS light direction to Android with native Material controls. Warm paper, lilac sections, plum ink/actions; retain dark mode and clinical status semantics. Secondary ink is #6C6073 for contrast on lilac. Patient Mode uses approved Concept C information hierarchy on both platforms.

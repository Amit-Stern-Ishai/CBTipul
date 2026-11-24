---
name: CBTipul — Botanical Mobile System
description: Single light botanical mobile palette with emerald actions, forest ink, sage surfaces and Rubik typography
colors:
  historyBase: "#E8F1EF"
  historyInk: "#153D35"
  historyLow: "#DCEBE6"
  historyMedium: "#BDD6CD"
  historyHigh: "#91BBAA"
  patientHomeHeader: "#DDECE7"
  headerInk: "#153D35"
  headerLine: "#6C8D81"
  turquoise: "#BDDCD2"
  turquoiseInk: "#153D35"
  accentLine: "#2B7B77"
  sessionTint: "#E8F1F5"
  sessionInk: "#365D70"
  questionnaireTint: "#E5F1E9"
  questionnaireInk: "#30664A"
  diaryTint: "#F7EFDF"
  diaryInk: "#775B2A"
  severityMinimal: "#DBEEE3"
  severityMild: "#F4DFA4"
  severityModerate: "#F0C49F"
  severitySevere: "#EFB6B2"
  base: "#F5F8F6"
  surface: "#FFFFFF"
  elevated: "#E8F1EF"
  hover: "#DCEBE6"
  surfaceWarm: "#E8F1EF"
  borderFaint: "#D5E2DD"
  borderDefault: "#B9CEC5"
  borderStrong: "#6C8D81"
  textBody: "#49665F"
  gold: "#087052"
  goldVivid: "#096B50"
  goldDim: "#05583F"
  goldGhost: "#0870521A"
  accentFill: "#087052"
  accentFillPressed: "#05583F"
  textOnAccent: "#FFFFFF"
  prestige: "#087052"
  prestigeGhost: "#0870521A"
  brandSecondary: "#087052"
  brandAccentSoft: "#E8F1EF"
  brandSoft: "#E8F1EF"
  success: "#28734E"
  warning: "#886019"
  warningSoft: "#8860191F"
  error: "#B33D49"
  positiveMedium: "#28734E"
  positiveSoft: "#28734E1F"
  negativeMedium: "#B33D49"
  negativeSoft: "#B33D491F"
  neutral: "#49665F"
  neutralMedium: "#49665F"
  neutralSoft: "#E8F1EF"
  critical: "#B33D49"
  criticalSoft: "#B33D492E"
  uiTextBright: "#153D35"
  uiTextFaint: "#49665F"
  uiAccentFill: "#087052"
  uiTextOnAccent: "#FFFFFF"
  uiElevated: "#E8F1EF"
typography:
  largeTitle:
    fontFamily: "Rubik, system-ui, sans-serif"
    fontSize: "34px"
  title:
    fontFamily: "Rubik, system-ui, sans-serif"
    fontSize: "28px"
  title2:
    fontFamily: "Rubik, system-ui, sans-serif"
    fontSize: "22px"
  title3:
    fontFamily: "Rubik, system-ui, sans-serif"
    fontSize: "20px"
  headline:
    fontFamily: "Rubik, system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 600
  subheadline:
    fontFamily: "Rubik, system-ui, sans-serif"
    fontSize: "15px"
  body:
    fontFamily: "Rubik, system-ui, sans-serif"
    fontSize: "17px"
  callout:
    fontFamily: "Rubik, system-ui, sans-serif"
    fontSize: "16px"
  footnote:
    fontFamily: "Rubik, system-ui, sans-serif"
    fontSize: "13px"
  caption:
    fontFamily: "Rubik, system-ui, sans-serif"
    fontSize: "12px"
  caption2:
    fontFamily: "Rubik, system-ui, sans-serif"
    fontSize: "11px"
rounded:
  primary-light: "10px"
  primary-dark: "16px"
  record: "12px"
  card: "14px"
  enclosure: "16px"
spacing:
  compact: "8px"
  group: "12px"
  inset: "16px"
components:
  button-primary-light:
    backgroundColor: "{colors.accentFill}"
    textColor: "{colors.textOnAccent}"
    rounded: "{rounded.primary-light}"
    padding: "13px 16px"
  button-primary-dark:
    backgroundColor: "{colors.accentFill}"
    textColor: "{colors.textOnAccent}"
    rounded: "{rounded.primary-dark}"
    padding: "13px 16px"
  button-new-session:
    backgroundColor: "{colors.turquoise}"
    textColor: "{colors.turquoiseInk}"
    rounded: "{rounded.record}"
    height: "44px"
---

# Design System: CBTipul — iOS Brand System

## Overview

**Creative North Star: "Operate — native RTL"**

The approved iOS replacement uses the supplied CBTipul color guide, Rubik typography and a native Hebrew RTL workspace. White and pale-blue surfaces in light appearance become layered navy surfaces in dark appearance, with the same clear action hierarchy and record-type meaning. The user-supplied blue-gray/emerald branching mark supersedes the previous logo as of 24 November 2026; see `assets/brand/README.md`. This asset-only update preserves the palette, typography, native controls and component contracts.

This is the app-wide iOS visual system. It supersedes the earlier iOS paper/plum palette, system-type direction and patient-colored header planes. Source authority is ios/Theme.swift and ios/BrandTypography.swift. Existing surface briefs retain interaction contracts; conflicting historical palette and typography descriptions defer here. Android and web have not been migrated by this work.

**Key Characteristics:**
- Rubik with native Dynamic Type and Hebrew RTL.
- White and pale-blue light surfaces; coordinated navy dark surfaces.
- Turquoise new-session action and distinct record-type tiles.
- Native controls, preserved destinations and clinical meaning.

## Colors

### Primary
Light-mode primary fills and links use navy through accentFill and gold; dark-mode equivalents use turquoise with dark ink for contrast. The legacy token name gold is a compatibility name, not a gold color. Pressed fills use accentFillPressed. The new-session action uses turquoise with turquoiseInk in both appearances.

### Secondary
Session tiles use sessionTint/sessionInk (lavender and blue in light); questionnaires use questionnaireTint/questionnaireInk (mint and green); diaries use diaryTint/diaryInk (cream and brown). Dark variants preserve these identities with darker fills and brighter ink. AI uses the shared accent family rather than the prior local purple treatment.

### Neutral
Base, surface, elevated and hover form the surface stack. TextBright, textBody and textFaint define readable hierarchy. Border tokens define structural edges. Patient and session headers share patientHomeHeader and headerInk: pale blue with navy ink in light, navy with white ink in dark. Patient identity colors remain on avatars and journey markers, not large header planes.

**The Meaning Rule.** Entity tints identify record types. Severity fills use navy ink and explicit labels; success, warning and error retain their clinical/status meaning. Clinical improvement follows the instrument's meaning, not the direction of a number alone.

Appearance follows the existing appAppearance setting (default dark). Frontmatter light/dark suffixes represent resolved values, not new Swift identifiers. HeaderLine is a light border token in light mode and white at 22% in dark. GoldGhost uses navy at 10% in light and turquoise at 12% in dark.

## Typography

Rubik is bundled in ios/Fonts/Rubik.ttf with Rubik-OFL.txt under the SIL Open Font License. SwiftUI uses the font's actual PostScript name Rubik-Light_Regular. BrandTypography binds each role to the matching native relative text style; frontmatter sizes represent baseline SwiftUI points, not fixed sizing or a web implementation. Headline is semibold; other weights are supplied by component context.

Use the title hierarchy for screen headings, headline/subheadline for actions and sections, body/callout for content, and footnote/caption for helpers, dates and counts. Patient-name typography scales from its existing 24 pt ScaledMetric. UIKit editors use UIFontMetrics with a system-font fallback. Native navigation title appearances use Rubik. Preserve Dynamic Type rather than fixing text containers to baseline dimensions.

## Layout

Keep native NavigationStack, List/Form/ScrollView, sheets, system keyboard and toolbar behavior. RTL determines reading order; dates and numeric data keep appropriate locale treatment. Controls retain accessible targets and content wraps or scrolls at accessibility sizes. Existing screen composition is preserved, including patient detail's compact activity digest and session editor's summary-first hierarchy; visual identity does not impose one layout on every screen.

Patient detail retains 6 pt section gaps and 12 pt horizontal inset, compact record rows with 44 pt minimum height, two record columns becoming one at accessibility sizes, and the horizontal recorded journey with vertical accessibility fallback. Session editor retains its 18 pt rhythm/inset and pinned save action. See the existing surface briefs for complete behavior contracts.

## Elevation & Depth

Depth comes primarily from tonal surfaces, thin borders and native sheet/material behavior. The shared header is a flat adaptive brand surface; the previous patient-tinted lights and diagonal planes are superseded. The compact goal retains native material. Shared content transitions use easeInOut over 0.18 s and disable animation for Reduce Motion. Prominent button press feedback uses easeOut over 0.15 s, opacity 0.85 and scale 0.985; Reduce Motion removes the scale/animation.

## Shapes

The shared prominent button has 10 pt corners in light and 16 pt in dark. Compact record and new-session controls use 12 pt corners; standard themed cards use 14 pt and a 0.75 pt faint outline. Patient record enclosure uses 16 pt corners. Existing circles for avatars/journey markers and capsules for statuses remain native, compact identity cues.

## Components

- **Primary action:** BrandTypography body semibold, accentFill/textOnAccent, 13 pt vertical and 16 pt horizontal padding. Press uses accentFillPressed; disabled uses elevated/textFaint. Preserve the existing enabled and loading behavior.
- **New session:** turquoise/turquoiseInk, subheadline semibold, 12 pt corners and 44 pt minimum height; compact plain-style behavior.
- **Record tiles:** session, questionnaire and diary tint/ink pairs with text and SF Symbols, neutral borders and 12 pt corners. The AI destination uses the shared accent fill/outline treatment.
- **Headers:** shared patientHomeHeader/headerInk; Rubik identity/title, retained avatar colors, native toolbars and explicit contrast-aware helper text. Patient detail keeps goal and journey beneath identity.
- **Inputs:** native editors and fields on adaptive surfaces; Rubik in custom UIKit editors, with existing keyboard, dictation, focus, draft and save/discard behavior.
- **Navigation and status:** native toolbar/tab/sheet semantics with branded typography and tint. Status and severity always retain readable labels; color supplements meaning.

The sidecar's HTML snippets are illustrative native-component equivalents for the design panel, not production UI or screenshots. They include basic keyboard focus/press states for preview use. The iOS brand surface brief records verification status and the gallery path.

Android's previously approved paper appearance remains separately scoped: warm paper, lilac sections, plum ink/actions and secondary ink #6C6073, with native Material controls, existing dark mode and clinical semantics. Patient Mode retains its approved Concept C hierarchy. This work changes no Android or web design contract.

### Web patient workspace (scoped)

The overview follows the inspected “מסך מטופל כחול שמיים” live artifact linked in the supplied `design-system (1).md`: [visual reference](https://claude.ai/artifact/6bjtKfJ84NuQvt3NgNSMSV#play-53094030cabe). The source reference is now available; the prior provisional sidebar composition is superseded for the overview. Implementation authority is `web/src/workspace/PatientTimeline.tsx`, `patient-timeline.css` and shared `patient-guide.css`. The existing iOS frontmatter and Android contract remain separately scoped; earlier web exclusions describe the iOS-only refresh. See `.impeccable/surfaces/web-patient-guide.md`.

**Colors.** White canvas, sky identity band `#D0F0FF`, navy ink `#00244E`, muted text `#5B6B82`, compact navy application shell `#002B5D`, primary navy `#0D3B66` and hover `#09345F`. The overview start action and selected calendar/list toggle use turquoise `#00E3DB`, with `#00CCCA` hover; the start action has a teal `#008480` border and navy text. The add menu uses navy with white text. Selected category filters use `#D6EAF8` and `#082A4A` ink. Borders use `#CBD5E1` and `#A3B1C2`; ordinary hover uses `#EBEDF1`, entry hover border `#A6B2C1`. Entity treatments use lavender/session `#F2EFFF`, mint/questionnaire `#D8FEF5` and cream/diary `#FFF5D5`, with navy `#002B5D` icons. Calendar entries use full entity tints; weekly-list cards use white bodies with tinted icon strips. Severity fills use minimal `#B9FFEF`, mild `#FFC516`, moderate `#FF9C45`, severe `#FB513A` and navy labels. Existing score interpretation and risk attention labels remain clinical data, separate from entity colors.

**Typography.** Local Rubik from `web/src/assets/Rubik.ttf`, `font-display: swap`, declared weights 300–800, with `system-ui, sans-serif` fallback. Workspace and header/footer use 1.4 line height and tabular numerals. The overview base is 14px; patient title 28px/700 with 1.2 line height, reducing to 24px below 850px. Month title is 16px/600 (15px below 850px), weekly category headings 15px, entry titles 13px/500, helper labels 12px and compact calendar titles 11px. Native Dynamic Type roles remain independent.

**Overview layout.** Hebrew RTL identity band contains patient title, available score labels, shared-view access, turquoise start action and calendar/list switch. A toolbar contains calendar month/today controls, entity filters and an add menu. Calendar is the default view: seven equal day columns with 126px minimum cell height, current-day navy circle and linked compact records. List view groups dated records by week, newest first, into three equal sessions/questionnaires/diaries columns with 22px gaps and pale-blue `#F4FBFF` column surfaces. Current-week heading uses `#E6E9ED`; undated records have a separate section. Main inset is 28px. At 850px and below, identity/actions wrap, inset becomes 16px, weekly columns stack with category labels, and the calendar scrolls horizontally over a 700px minimum grid. Above 1100px the surrounding application header uses a compact 52px minimum height and 28px logo. The existing clinical subpages retain their scoped rail/wrapped-navigation layout; that rail no longer describes the overview.

**Shapes and states.** Overview actions and calendar enclosure use 6px corners, record cards 8px, compact calendar records 4px, score badges 5px and filter pills 18px. Primary start has 36px minimum height; toggle/filter controls 32px; toolbar controls 34px. White cards and thin borders provide depth; only the add popup uses `0 8px 24px #00244e20`. Focus uses a 3px teal outline with 3px offset; shell focus is turquoise. Calendar/list and category buttons expose pressed state.

**Behavior and verification.** The overview presents existing session, questionnaire and diary records. Entry links open existing editors through `entry` parameters; start/add links use `new=1` and open forms without automatic saves. Start does not create a scheduled event or start an inferred timer. Shared-view access and write actions preserve permissions. Missing model data does not become invented contacts, attachments, appointments, trends or patient facts. Public pages and shared Zoom presentation retain their contracts. Typecheck, lint, 152 unit tests, 36 patient-workspace browser tests and the combined production build pass. Desktop calendar/list and phone list captures inspected with synthetic data. Public content/verification preservation test passes; the unchanged clinical-consent hash assertion fails and is outside this design change. No live clinical services exercised. Review gallery: outputs/web-patient-reference/index.html in the Codex workspace.

## Do's and Don'ts

- Do resolve colors through Theme and text through BrandTypography.
- Do preserve Hebrew RTL, Dynamic Type, labeled actions and existing safety behavior.
- Do pair record-type and clinical colors with text or symbols.
- Do keep the newest journey stage at the left horizontally and at the top vertically.
- Don't reintroduce paper/plum iOS tokens or patient-colored header planes.
- Don't treat entity tints as clinical severity or infer improvement from raw score direction.
- Don't claim this iOS replacement migrated Android or web.
- Preserve the approved branching mark (see `assets/brand/README.md`); do not replace native controls with raster assets or web controls.


## Botanical mobile palette — 24 November 2026

This supersedes earlier mobile light/dark and navy/plum color directions. iOS and Android use one light appearance regardless of stored preference or OS mode. The branch logo anchors emerald actions (#087052), forest ink (#153D35), sage surfaces (#E8F1EF), and blue-gray information (#365D70). White cards sit on #F5F8F6 canvas. Amber #886019 and rose #B33D49 retain warning/destructive meaning. Clinical labels and severity remain distinct; user-selected patient identity colors are preserved. Appearance selectors are removed, text-size accessibility stays. Web colors are unchanged by this mobile-only task. Full tokens: `assets/brand/palette.json`.

Soft tokens use #RRGGBBAA where alpha is present; render them over the specified base/surface. Earlier appearance descriptions are historical and are superseded by the botanical mobile section.


## Palette balance — 2026-11-24

Current iOS, Android and web application surfaces use white (#FFFFFF), neutral off-white (#F7F8FA), and neutral elevated surfaces (#F2F4F6). Navy (#00244E) anchors headings and navigation. Brand blue (#285A8C), pressed navy (#0D3B66), and selective pale blue (#E5EFF9) identify actions, selected states and focus. Green (#28734E) is reserved for success/completion and small accents; patient avatar hues remain intact. Full-page patient-color washes and nested green panels are removed. Layout, typography and RTL are unchanged. This supersedes the previous green surface palette; the icon is unchanged.

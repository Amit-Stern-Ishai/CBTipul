# iOS brand guide replacement

## Authority and scope
The user approved a full iOS makeover using `/Users/amitishai/Downloads/צבעוניות-CBTipul.pdf`, with matching light and dark modes. The direction is **Operate — native RTL**. Root DESIGN.md and ios/Theme.swift define the current tokens; ios/BrandTypography.swift defines Rubik roles. This supersedes prior iOS paper/plum, system-typography and patient-colored header-plane instructions in historical briefs. Existing interaction contracts remain in those briefs. Android and web are outside this migration.

## Built expression
White/light-blue light surfaces, navy ink and primary actions; coordinated navy dark surfaces with turquoise primary fills. New-session is turquoise with navy ink in both modes. Shared patient/session headers use the adaptive brand header surface and explicit header ink. Record destinations use lavender/blue for sessions, mint/green for questionnaires and cream/brown for diaries, with matching dark pairs. Native SF Symbols and the current logo remain. Rubik is bundled under SIL OFL; no new raster assets.

## Preserved behavior
Keep every source destination and workflow, Hebrew RTL, Dynamic Type, native navigation, clinical semantics, authentication/entitlements, recording/recovery, AI review and save/discard safeguards. Patient journey remains oldest right/newest left horizontally and newest top vertically; entity tints do not imply clinical severity.

## Review artifacts and verification
Gallery: `/Users/amitishai/Documents/Codex/2026-10-14/got/outputs/ios-brand-guide/index.html`.
Full simulator build and focused tests passed, including bundled Hebrew glyphs, contrast, Dynamic Type, native clinical navigation and explicit title visibility. Accessibility XXXL popup actions were verified separately. The fresh reviewer scored all five material findings resolved and returned “Ship within the reviewed scope.” Native inline Rubik titles replace missing large titles on the clinic/create surfaces. The gallery is a review aid, not proof that every native flow was exercised. Do not claim backend, microphone, invitation or messaging verification without separate evidence.

## Documentation caveats
PRODUCT.md still describes a patient-detail-only task and navy/gold identity, and contains a device-local patient-name claim requiring separate factual/privacy reconciliation. It was deliberately not changed by this visual documentation pass. Historical Android paper guidance is retained separately in DESIGN.md; the iOS replacement does not supersede it.

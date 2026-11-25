# מדרג חשיפות — implementation and verification

## Design direction
An extension of the existing diary reading/editing experience, not a new design system. Therapists work privately or share a laptop screen; patients work on a phone. Keep neutral surfaces, navy Hebrew headings and blue actions from DESIGN.md. Ordered, numbered situations are the primary content; ratings are secondary and never determine order. Reading has no reorder controls. Editing uses native mobile dragging or a visible web handle, plus explicit accessible arrows. Keep Save and Cancel visible. No AI, publication copy, repetitions or retrospective forms.

## Contract and integration
All clients use `patient-exposure-hierarchy` with `load` / `save`, opaque expected revision, explicit nullable ratings, and the complete ordered item array. Therapist requests include patient_id; Patient Mode requests omit it. A null document opens a new editor. A saved document opens reading mode. Conflicts retain the local draft; explicit reload keeps a temporary backup available through “חזרה לשינויים שלי”. No automatic retries or alternate writes.

Therapist Actions uses `set_patient_exposure_hierarchy_enabled`, then re-reads uncancelled `patient_assignments` for the exact patient and raw type. The switch changes only after confirmation. Existing Patient Mode assignment queries do not whitelist types; hierarchy recognition was added without routing it through diary submission. A completed timestamp does not close this ongoing assignment. Patient hierarchy access is rechecked on foreground; a confirmed denial hides its contents.

## Verification
- Full iOS simulator, Android debug and web production builds passed.
- Focused model/contract tests cover null versus 0%, preserved manual order, immutable baseline, UUID/validation restrictions, omitted patient identity, and ongoing assignment recognition.
- Web synthetic HTTP tests cover reading, pointer dragging, keyboard Move, Cancel, one save, reopened order, conflict retention, account-switch response rejection, and shared-view request isolation. The verification runner is `web/scripts/verify-exposure.mjs`; build with `VITE_SERVER_CONSENT_ENABLED=true VITE_SUPABASE_URL=https://fixture-cbtipul.supabase.co VITE_SUPABASE_PUBLISHABLE_KEY=synthetic-public-key-for-local-tests npm --prefix web run build`, then run `node web/scripts/verify-exposure.mjs`. It uses no real account or clinical data.
- Native screenshots use the actual views with debug-only synthetic in-memory responses. iOS: `-UITesting -ExposureHierarchyReview`, optionally `-ExposureEditingReview`. Android: intent boolean extras `exposure_review` and `exposure_editing`. These review modes do not save to a backend.
- iOS simulator UI test passed Move down → Cancel → reopen → Move down → Save, with 0% still displayed (synthetic local responses). The UI-test target needed command-local `SUPPORTED_PLATFORMS=iphonesimulator`; project settings were not changed.
- Android emulator Move down and long-press handle drag were exercised; both changed the synthetic order while preserving each row’s text/rating. iOS native drag interaction and full accessibility gesture traversal still need a hands-on check; model reorder operations are tested.

## Still requires live disposable accounts
The Samsung was not connected; only an emulator and paired iPhone 17 were available. No real hierarchy or activity setting was changed. Verify therapist save+enable → patient edit+reorder → therapist reload; disable → patient endpoint denies access while list remains stored; re-enable restores it. Verify enabling clears the pending activity request (server behavior) and the assignment is visible under deployed patient RLS. Backend function/SQL enforcement and cross-device conflicts were not asserted from local fixtures.

## Manual checks
On both native apps, edit a three-item list with ratings 80, null, 0; long-press the handle and move the last row first, then Cancel and reopen. Repeat and Save; verify another device gets 0,80,null in that chosen order. Test long text with the keyboard open and VoiceOver/TalkBack Move up/down. On two clients, edit the same revision and verify the second save retains its draft on conflict. Disable from Actions while Patient Mode is open, background/foreground the patient app, and verify content is hidden after denial.

No backend, SQL, minimum-version, AI, consent, diary or invitation behavior changed. No commit, push or deployment performed.

## Finish review
Impeccable finish reviewer: `ship` for the two corrected findings (visible Android Cancel; pinned web Save/Cancel). Documenter confirmed this is an ordinary extension of the incumbent design system. Existing PRODUCT/DESIGN frontmatter drift was left untouched.

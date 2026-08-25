
# Xcode Coding Agent Rules

You are working on an existing Swift / SwiftUI application.

Your primary goal is to implement changes with the **minimum possible context and token usage** while preserving existing behavior.

## Context efficiency

* Do NOT scan the entire project.
* Do NOT inspect unrelated files.
* Start by identifying the smallest set of files required for the task.
* Only open additional files when they are genuinely necessary.
* If another file is needed, explain why it is needed before inspecting it.
* Prefer reading a specific type/function over an entire large file when possible.
* Do not repeatedly reread files already inspected.

## Code changes

* Make the smallest possible change that solves the requested problem.
* Do not refactor unrelated code.
* Do not rename existing APIs unless explicitly requested.
* Do not rewrite entire files when a small edit is sufficient.
* Preserve the existing architecture and coding style.
* Reuse existing models, services, utilities and components whenever possible.
* Do not introduce a new abstraction unless it is actually required.
* Do not add dependencies unless explicitly requested.
- Anytime you create a string, make it a localized string - follow the current practise of adding in Localization file.

## File scope

Before making changes, determine:

1. Which files need to change.
2. Why each file needs to change.
3. Which files do NOT need to change.

Prefer changing 1–3 files per task.

If the task appears to require many files, stop and propose breaking it into smaller tasks.

## Implementation workflow

For each task:

1. Understand the requested behavior.
2. Identify the minimum relevant files.
3. Inspect only those files.
4. Implement the smallest change.
5. Run/build the relevant target if available.
6. Report what changed and any build/test result.
7. Stop.

Do NOT automatically continue implementing additional improvements.

## Errors

When a build error occurs:

* Focus only on the reported error.
* Inspect the smallest relevant code area.
* Fix the error.
* Do not perform unrelated cleanup.
* Do not restart the implementation from scratch.

## Communication

Keep responses concise.

After implementation, report:

* Files changed
* What changed
* Build/test result
* Any remaining issue

Do not provide long explanations unless requested.

## Important

Do not optimize code that already works.

Do not refactor code simply because you would personally structure it differently.

Do not modify code outside the requested feature.

When uncertain, ask rather than exploring the entire project.

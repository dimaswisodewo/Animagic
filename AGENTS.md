# AGENTS.md

## Project overview

AniMagic is an iOS SwiftUI application. Follow the existing SwiftUI, Observation, SwiftData, and `MainActor` conventions when making changes.

## Navigation

- `Animagic/App/Navigation/AppRoute.swift` and `NavigationRouter` are the single source of truth for application navigation.
- Add new destinations as `AppRoute` cases and map them through `AppRouterView` in `Animagic/App/Navigation/AppRoute+Modifier.swift`.
- Use `NavigationRouter` APIs for pushes, replacements, sheets, full-screen covers, dismissals, and back navigation.
- Do not introduce independent route enums, ad hoc navigation state, or navigation flows that bypass `NavigationRouter`.
- Preserve route payloads and keep routes compatible with the existing `Hashable` and `Identifiable` requirements.

## Project organization

- Put feature-specific views, view models, components, and managers under `Animagic/Features/<FeatureName>`.
- Put broadly reusable models, services, persistence, rendering, image processing, and infrastructure under `Animagic/Core`.
- Keep application composition and routing under `Animagic/App`.
- Keep reusable UI primitives and design-system code in the existing shared areas.
- Prefer one primary responsibility per file. Split unrelated components, services, and managers into separate files.
- Keep features isolated from unrelated feature implementation details.

## Architecture and code quality

- Follow Clean Architecture and SOLID principles:
  - Views focus on presentation.
  - View models coordinate UI state and user actions.
  - Managers and services handle side effects and orchestration.
  - Repositories abstract persistence and external data access.
  - Protocols define useful substitution and testing boundaries.
- Prefer dependency injection over constructing concrete dependencies deep inside features.
- Keep public interfaces minimal and make ownership, lifecycle, and side effects easy to identify.
- Inspect existing patterns before introducing new abstractions.

## Readability and maintainability

- Write straightforward, self-documenting code with clear names and predictable control flow.
- Prefer small functions, focused types, shallow nesting, and explicit data flow.
- Avoid clever abstractions, premature generalization, duplicated logic, magic values, and unnecessary coupling.
- Preserve existing conventions unless a change clearly improves consistency or maintainability.
- Add comments when they explain intent, non-obvious constraints, platform workarounds, algorithms, or important tradeoffs.
- Do not add comments that merely restate what the code already says. Update comments whenever the documented behavior changes.

## SwiftUI view composition

- Keep `body` concise and easy to scan.
- Extract meaningful sections into `@ViewBuilder` functions, computed subviews, or private `Subview` types.
- Keep business logic and side effects out of `body`.
- Make state ownership and environment dependencies explicit.
- Preserve accessibility, previews, and existing visual behavior when refactoring.

## Blender and USDZ assets

- Follow the authoritative [AR asset pipeline](docs/asset-pipeline/README.md) when adding or replacing Blender-derived USDZ resources.
- Use the [Blender-to-USDZ runbook](docs/asset-pipeline/BLENDER_TO_USDZ.md) and complete every check in [USDZ validation and troubleshooting](docs/asset-pipeline/VALIDATION_AND_TROUBLESHOOTING.md).
- Never overwrite an artist's source Blend or accept a USDZ based only on successful export; dependency validation and an Apple Metal render are required.

## File headers and authorship

- Every new or modified source file must contain a header identifying its author.
- Follow the existing Xcode-style convention, for example:

  ```swift
  //
  //  FileName.swift
  //  AniMagic
  //
  //  Created by <Author Name> on <DD/MM/YY>.
  //
  ```

- Preserve existing author attribution when modifying a file; do not replace or erase it.
- Use the configured repository or user author identity for new files. If no identity is available, ask the user before creating the file.
- Keep the filename and author metadata accurate.

## Change workflow

- Update routing, dependency wiring, and feature organization together when adding functionality.
- Validate changes using the available Xcode build and test workflow.
- Report environment limitations or unavailable validation tools clearly.

# AGENTS.md

## Project overview

AniMagic is an iOS SwiftUI application. Follow the existing SwiftUI, Observation, SwiftData, and `MainActor` conventions when making changes.

## Required context

Before changing code:

1. Read this file.
2. Read [CONTEXT-MAP.md](CONTEXT-MAP.md).
3. Read the owning module's `CONTEXT.md` when changing Creation or Play.
4. Read applicable decisions under [docs/adr](docs/adr).
5. Read [docs/ONBOARDING.md](docs/ONBOARDING.md) for commands and subsystem orientation.
6. For AR assets, read every document linked in the asset-pipeline section below.

Repository code and `project.yml` are authoritative when documentation and implementation disagree. Correct stale documentation in the same change.

## Architecture and target boundaries

AniMagic is a modular monolith:

- `AniMagic` owns app composition, navigation, Home, Help, and cross-context handoffs.
- `AniMagicCreation` owns the canonical Creation model, repository contract, SwiftData record, and catalog orchestration.
- `AniMagicPlay` owns environment-independent Play intent and session state.
- `AniMagicSupport` owns reusable audio and haptic infrastructure.
- `AniMagicDesignSystem` is the framework boundary for reusable visual primitives.

Dependency direction is App → Play → Creation, with Design System and Support as narrow foundations. Creation must not import Play. Neither Creation nor Play may import application routing.

Runtime Creation behavior belongs behind `CreationRepository`, `CreationLibraryStore`, and Creation value types. Former Artwork, Saved Drawing, and Cutout names may appear only in private migration schemas and historical documentation.

## Navigation

- `Animagic/App/Navigation/AppRoute.swift` and `NavigationRouter` are the single source of truth for application navigation.
- Add new destinations as `AppRoute` cases and map them through `AppRouterView` in `Animagic/App/Navigation/AppRoute+Modifier.swift`.
- Use `NavigationRouter` APIs for pushes, replacements, sheets, full-screen covers, dismissals, and back navigation.
- Do not introduce independent route enums, ad hoc navigation state, or navigation flows that bypass `NavigationRouter`.
- Preserve route payloads and keep routes compatible with the existing `Hashable` and `Identifiable` requirements.
- Play is entered through `AppRoute.play(PlayIntent)`. Use `PlayEnvironment` to select AR or Virtual Room instead of adding environment-specific app routes.

## Project organization

- Put Creation and Play feature-specific code under their owning module's `Features` directory.
- Put app-only Home and Help presentation under `Animagic/App/Presentation`.
- Keep application composition and routing under `Animagic/App`.
- Put canonical Creation and Play behavior in their framework under `Animagic/Modules`.
- Keep reusable UI primitives and design-system code in the existing shared areas while the Design System framework extraction is completed incrementally.
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
- Introduce protocols only at useful substitution or side-effect boundaries. Avoid one-to-one protocols without a testing or ownership benefit.
- Prefer immutable, `Sendable` value types at module and concurrency boundaries.

## State and concurrency

- Use `@Observable` for new state models unless an Apple framework requires `ObservableObject`.
- Make UI state, SwiftData `ModelContext` access, and RealityKit scene mutation `@MainActor`.
- Keep business logic and side effects outside SwiftUI `body`.
- Make async cancellation and stale-result protection explicit when later user actions invalidate earlier work.
- Inject repositories and side-effecting services from composition roots. Do not construct them deep inside views.

## Readability and maintainability

- Write straightforward, self-documenting code with clear names and predictable control flow.
- Prefer small functions, focused types, shallow nesting, and explicit data flow.
- Avoid clever abstractions, premature generalization, duplicated logic, magic values, and unnecessary coupling.
- Preserve existing conventions unless a change clearly improves consistency or maintainability.
- Add comments when they explain intent, non-obvious constraints, platform workarounds, algorithms, or important tradeoffs.
- Do not add comments that merely restate what the code already says. Update comments whenever the documented behavior changes.

## SwiftUI view composition

- When creating UI, first inspect and reuse components, colors, typography, and motion tokens from `Animagic/Modules/DesignSystem`.
- Prefer extending an existing design-system component with a focused, reusable variant over duplicating its styling inside a feature.
- Create a feature-local UI component only when no design-system component fits and the component is genuinely specific to that feature.
- Keep `body` concise and easy to scan.
- Extract meaningful sections into `@ViewBuilder` functions, computed subviews, or private `Subview` types.
- Keep business logic and side effects out of `body`.
- Make state ownership and environment dependencies explicit.
- Preserve accessibility, previews, and existing visual behavior when refactoring.

## Persistence and migration

- `CreationRecord` is the current SwiftData representation.
- Access Creation persistence through `CreationRepository`; feature views must not access `ModelContext` directly.
- Treat schema migration as product behavior. Any schema change requires a new `VersionedSchema`, an explicit migration stage, and disk-backed migration tests.
- Preserve Creation Source and Playable Asset data. Never silently drop a legacy drawing, photo, or orphaned processed image.
- On store-open failure, preserve the existing store and retain the in-memory recovery behavior. Do not add automatic deletion or destructive reset.

## Generated files and resources

- `project.yml` is the source of truth for targets, membership, resources, and build settings.
- Do not hand-edit `AniMagic.xcodeproj` for durable changes.
- After changing `project.yml`, run `./generate-project.sh`, then commit the specification and regenerated project together.
- Use `./generate-project.sh --check` to verify consistency.
- Keep application resources under `Animagic/Resources`; do not duplicate bundled assets across frameworks without an explicit resource-bundle decision.

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

- Inspect the owning feature, public boundary, consumers, tests, and relevant docs before editing.
- For a feature: identify its bounded context, reuse the Design System, inject dependencies, and test behavior.
- For a route: update `AppRoute`, its central mapping, dependency wiring, and call sites together.
- For persistence: update the domain contract, adapter, schema/migration, and migration tests together.
- For a context-boundary change: update `CONTEXT-MAP.md`, the affected `CONTEXT.md`, and add or supersede an ADR.
- Update routing, dependency wiring, and feature organization together when adding functionality.
- Validate changes using the available Xcode build and test workflow.
- Report environment limitations or unavailable validation tools clearly.

Minimum checks:

```sh
git diff --check
./generate-project.sh --check
xcodebuild \
  -project AniMagic.xcodeproj \
  -scheme AniMagic \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/AnimagicDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Run the relevant XCTest bundles for behavior changes. AR, camera, Apple Pencil, audio, haptic, and USDZ acceptance still require appropriate physical-device validation; a Simulator build is not sufficient.

## Documentation maintenance

- Update Markdown whenever a referenced path, symbol, command, ownership rule, or data flow changes.
- Use current canonical terminology in new docs and code. Mention former terms only when explaining compatibility or migration.
- ADRs are append-only decisions: supersede an old decision with a new ADR instead of silently rewriting its meaning.
- Do not duplicate detailed subsystem guidance across files. Keep universal rules here, context rules in `CONTEXT.md`, and operational teaching in the onboarding handbook.

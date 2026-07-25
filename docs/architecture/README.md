# AniMagic architecture

AniMagic is organized as a modular monolith. XcodeGen's `project.yml` is the
source of truth for the project and target graph.

AI coding agents should read the root [`AGENTS.md`](../../AGENTS.md), then the
[`CONTEXT-MAP.md`](../../CONTEXT-MAP.md) and the owning module's `CONTEXT.md`
before changing a boundary. Human contributors should begin with the
[onboarding handbook](../ONBOARDING.md).

## Target boundaries

- `AniMagic`: app composition, routing, Home, Help, and cross-context handoffs.
- `AniMagicCreation`: the canonical creation model, repository boundary,
  SwiftData record, and creation catalog orchestration.
- `AniMagicPlay`: Play intent, session state, AR, Virtual Room, rendering, and motion.
- `AniMagicSupport`: reusable audio and haptic services.
- `AniMagicDesignSystem`: the extraction boundary for shared visual primitives.

Creation does not depend on Play. Play consumes creation identities and is the
only domain that distinguishes augmented reality from the virtual room.
Application routing uses a single `AppRoute.play(PlayIntent)` destination and
selects the environment through `PlayEnvironment`.

## Persistence

`CreationRecord` is the current persisted representation. The private
one-release bridge in `ArtworkMigrationPlan` upgrades the former drawing and
cutout tables without deleting source data. Creation owns container startup,
migration, repository composition, and non-destructive recovery.

If the persistent store cannot be opened or migrated, startup falls back to an
in-memory library and tells the user. It never deletes or replaces the failed
store.

## Dependency rules

- Feature views present state and forward actions.
- Observable models coordinate UI state and workflows.
- Repositories own persistence access.
- Side-effecting platform services live behind focused boundaries.
- Navigation flows only through `NavigationRouter` and `AppRoute`.
- New cross-feature dependencies require an ADR.

See the root `CONTEXT-MAP.md`, module `CONTEXT.md` files, and `docs/adr` for the
decisions behind these boundaries.

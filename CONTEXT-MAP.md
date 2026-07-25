# AniMagic Context Map

## Contexts

- [Creation](./Animagic/Modules/Creation/CONTEXT.md) — owns user-created content from capture through playable-asset preparation and Backpack management.
- [Play](./Animagic/Modules/Play/CONTEXT.md) — consumes playable creations and owns ephemeral placement, motion, and scene interaction.
- **App** — owns startup, dependency composition, Home, Help, `AppRoute`, `NavigationRouter`, and translation between context actions and routes.
- **Support** — supplies context-neutral audio and haptic capabilities.
- **Design System** — supplies reusable visual primitives without owning feature workflows.

## Relationships

- **Creation → Play**: Creation exposes read-only `PlayableCreation` values. Play never edits Creation persistence directly.
- **Play → Creation flow**: Play emits an intent to draw or import. The app presents Creation UI through `NavigationRouter`, then returns the resulting Creation identifier to the suspended Play session.
- **App → Creation and Play**: The app owns composition and navigation. Neither context imports app routing types.
- **Play → environment adapters**: shared Play intent is translated into AR or Virtual Room behavior by app-owned adapters. Environment-specific tracking and scene details do not leak into Play contracts.
- **Creation → persistence**: Creation owns its repository contracts, SwiftData implementation, presentation store, migration schemas, and non-destructive startup recovery.
- **Creation/Play → Support and Design System**: both contexts may depend on these narrow foundations. Support and Design System must not depend on feature or context implementations.

## Enforced and transitional boundaries

- Xcode framework dependencies enforce the Creation, Play, Support, and Design System direction.
- Creation and Play own their feature UI, workflows, platform implementations, and resources behind compiler-enforced framework boundaries.
- The repository has no generic `Core`, `Features`, or `Shared` source bucket.
- Changes to ownership or dependency direction require an ADR and updates to this map.

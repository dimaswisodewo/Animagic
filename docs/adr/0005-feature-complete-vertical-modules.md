# Make vertical modules feature-complete

**Status:** Accepted

## Context

ADR 0001 established Creation and Play framework boundaries while leaving the
current feature UI, processing, rendering, and compatibility adapters in the
application target. That transitional layout kept domain ownership clear but
allowed most implementation code to remain compiler-unisolated.

## Decision

Creation and Play are feature-complete vertical frameworks. They own their
domain, application workflows, feature UI, platform implementation, and
resources. The app owns composition, `AppRoute`, `NavigationRouter`, Home,
Help, and cross-context handoff coordination.

Module views emit semantic actions which the app translates into routes.
Resources are loaded from their owning framework bundles. Generic `Core`,
`Features`, and `Shared` source buckets are not used.

## Consequences

- Creation owns Canvas, Backpack, Creation detail, photo import, processing,
  persistence, and its migration bridge.
- Play owns AR, Virtual Room, motion, rendering, and scene interaction.
- Design System and Support remain narrow shared foundations.
- A new shared target requires a distinct responsibility and a superseding ADR.
- Existing user flows and persisted Creation data remain compatible.

This ADR supersedes ADR 0001's transitional app ownership of feature UI and
adapters; its dependency direction remains in force.

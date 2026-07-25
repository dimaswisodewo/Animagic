# Treat AR and Virtual Room as Play environments

**Status:** Accepted

## Context

AR and Virtual Room share selection, placement, editing, and motion language, but
their tracking, camera, environment, and scene-lifecycle mechanics differ.
Separate app routes made the shared product flow harder to preserve.

## Decision

AR and Virtual Room are `PlayEnvironment` values entered through one
`AppRoute.play(PlayIntent)` destination. Shared session intent lives in Play.
Environment-specific behavior remains in separate adapters.

## Consequences

- Environment switching preserves the selected Creation.
- Play contracts do not expose ARKit or RealityKit implementation objects.
- AR and Virtual Room are not forced into one scene controller.
- New environments update the Play enum, route mapping, adapter wiring, and
  preservation tests together.
- Play sessions remain ephemeral unless a later ADR introduces saved scenes.

Supersede this ADR if Play environments gain fundamentally different product
ownership or persistence.

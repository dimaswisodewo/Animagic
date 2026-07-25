# Play

Play owns ephemeral worlds in which playable creations and bundled props can be placed, selected, edited, and animated.

## Owns

- `PlayIntent`, `PlayEnvironment`, and `PlaySessionModel`.
- Environment-independent selection, pause/resume, and session intent.
- Shared language for placed objects and environment adapters.
- Ephemeral placement, editing, and motion semantics.

## Does not own

- Creation persistence, editing, classification, or source processing.
- App routing and presentation.
- Creation workflows, persistence, and application routing.
- Permanent scene persistence.

## Public interface

- `PlayEnvironment` selects augmented reality or Virtual Room.
- `PlayIntent` carries the environment and optional initial Creation identifier.
- `PlaySessionModel` preserves selected Creation state while switching environments and owns pause/resume state.

App navigation enters Play only through `AppRoute.play(PlayIntent)`. App-owned route types must not move into the Play framework.

## Invariants

- A Play Session is ephemeral.
- Switching environment preserves the selected Creation.
- Play consumes identifiers or read-only `PlayableCreation` values.
- Play never edits Creation storage directly.
- Environment adapters translate shared intent without forcing AR and Virtual Room into one scene controller.

## Dependencies

Play may depend on Creation, Design System, and Support. It must not depend on App routing or feature implementations.

AR and Virtual Room implementations live in Play feature slices. Keep tracking,
raycasting, camera, room, and RealityKit details private to their environment.

## Extension recipe

- Add shared session behavior to Play and cover it in `AniMagicPlayTests`.
- Add environment-specific behavior to the owning adapter without exposing platform types through Play.
- Request Creation workflows through app composition and `NavigationRouter`.
- Add a new environment only by extending `PlayEnvironment`, its app route mapping, adapter wiring, and preservation tests together.

## Tests

Use `AniMagicPlayTests` for environment-independent session behavior. Use `AnimagicTests` for app adapters, rendering analysis, and motion.

## Common agent mistakes

- Restoring separate `.arView` or `.virtualRoom` app routes.
- Importing `NavigationRouter` into Play.
- Storing RealityKit entities in `PlaySessionModel`.
- Mutating Creation persistence from a Play adapter.
- Sharing an environment-specific scene controller between AR and Virtual Room.

## Language

**Play Session**:
An ephemeral interaction session whose placements and edits end when the user leaves Play.
_Avoid_: Saved scene

**Play Environment**:
The spatial host for a Play Session: real-world augmented reality or Virtual Room.
_Avoid_: AR feature, Virtual Room feature

**Placed Object**:
An object instantiated in a Play Environment from a playable creation or bundled prop.
_Avoid_: Scene asset

**Environment Adapter**:
The implementation that translates shared Play commands into AR or Virtual Room behavior.
_Avoid_: Scene manager

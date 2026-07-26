# AniMagic Architecture

AniMagic uses a hybrid, responsibility-oriented architecture inside one application module.
The directory boundary communicates ownership today and is intended to support future module
extraction without requiring it now.

## Dependency direction

```text
App ────────> Features ────────> Domain
 │                │                 ▲
 │                └──> Platform ────┘
 ├───────────────> Platform
 └───────────────> DesignSystem

DesignSystem ────> Domain (only when a reusable primitive needs a domain value)
```

- `App` owns composition, route identity and rendering, and app-wide observable state.
- `Domain` owns product entities, policies, protocols, and deterministic simulation. It has no
  persistence, SwiftUI, Vision/Core ML, RealityKit/ARKit, AVFoundation, or side effects.
- `Platform` owns Apple-framework implementations: SwiftData, image processing, Photos, audio,
  haptics, and reusable RealityKit rendering.
- `Features` owns user journeys and feature-specific orchestration. AR session control, Pencil
  interaction, AR gestures, and AR presentation belong to `ARPlacement`.
- `DesignSystem` owns reusable visual tokens and UI primitives. A component named for one
  feature belongs to that feature.
- `Resources` owns bundled data and media. `Prototypes` is reference-only and never compiled.

Platform and DesignSystem must not depend on feature-owned types. Features may collaborate only
through Domain contracts, app routing, or purpose-built shared Platform services.

## Naming vocabulary

Use `Home`, `DrawingCanvas`, `Backpack`, `DrawingDetail`, `Help`, `ARPlacement`, and
`VirtualRoom` consistently for feature types and routes. Avoid historical names such as
`ContentView`, `DrawingCanvasView`, `HanddrawnDetail`, and the `NewAR` prefix.

## File responsibility

Give an independently meaningful type its own file. A small private helper may remain beside its
sole owner when separating it would obscure the relationship. Files above 400 lines require a
responsibility review; the threshold is a review signal, not an automatic split rule. Repository
validation rejects an oversized file unless it is listed in
`architecture-large-file-exceptions.txt`; stale exceptions also fail validation.

The current exceptions are deliberate migration boundaries:

- `MotionConfiguration`, `MotionSimulation`, `CardboardRimMeshGenerator`, and
  `CutoutContourExtraction` are cohesive algorithm or taxonomy modules whose invariants are easier
  to review together.
- `CutoutSceneEditor` owns one mutable scene-editing lifecycle.
- `AnimagicDesignSystem`, `ARPlacementControls`, `ARPlacementView`, `HelpView`,
  `VirtualRoomCoordinator`, and `CutoutRenderingResources` remain reviewed refactor candidates.
  Their exception records prevent unrelated work from creating additional oversized files while
  these presentation, orchestration, and rendering responsibilities are separated incrementally.

Feature views call Domain policies and contracts and delegate Apple-framework side effects to
Platform services. `ARPlacementSceneController` and `VirtualRoomCoordinator` remain feature-owned
lifecycle orchestration interfaces; reusable entity rendering stays in Platform. Preview storage
is an app-composition adapter, while backpack AR synchronization is owned by the Backpack feature.

## Persistence compatibility

Refactoring directory ownership must not rename SwiftData record properties, change stored value
encoding, or modify external asset formats. Schema changes require an explicit migration plan.

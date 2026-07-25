# Creation

Creation owns everything a person makes or imports into AniMagic, from its retained source through preparation for Play.

## Owns

- Creation identity, title, retained source, species assessment, habitat, and playable-asset availability.
- The `CreationRepository` persistence contract and `SwiftDataCreationRepository`.
- `CreationRecord` and conversion between persisted and domain representations.
- `CreationCatalog` orchestration for loading, saving, and deleting Creations.
- Canvas, Backpack, Creation detail, photo import, classification, foreground extraction, and Creation resources.
- Backpack semantics and read-only values exported to Play.

## Does not own

- App routing or screen presentation.
- ARKit, RealityKit, Virtual Room, placement, or ephemeral scene state.
- Audio, haptics, or reusable visual styling.
- Compatibility APIs named Artwork, Saved Drawing, or Cutout.

## Public interface

- `CreationID` is the stable cross-module identity.
- `Creation`, `CreationSummary`, and `PlayableCreation` are domain-facing values.
- `CreationSource`, `PlayableAsset`, `SpeciesAssessment`, and `Habitat` describe the aggregate.
- `CreationRepository` is the substitution boundary for persistence.
- `CreationCatalog` coordinates repository-backed UI workflows.

Keep the public surface minimal. Export values and intentions, not SwiftData records or `ModelContext`.

## Invariants

- Every Creation retains a source. A playable asset is derived and optional.
- A Creation is playable only when its playable asset exists.
- User title and species overrides take precedence over automatic values.
- Habitat is derived from the effective species label.
- Play receives read-only playable values and never mutates Creation persistence.
- Migration preserves legacy source and playable bytes, including unlinked cutouts.

## Dependencies

Creation may depend on Design System and Support foundations. It must not depend on Play, App routing, or feature implementations.

Image-processing workflows live behind focused Creation services and update the canonical aggregate through the Creation library boundary.

## Persistence changes

For every schema change:

1. Add a new `VersionedSchema`.
2. Define an explicit migration stage.
3. Test migration using an on-disk prior-schema store.
4. Verify identifiers, retained source, playable data, assessment metadata, and orphan handling.
5. Preserve the non-destructive startup fallback.

`CreationLibraryStore` is the presentation-facing library API. It delegates persistence to Creation-owned repository implementations; former record names remain private to migration.

## Tests

Use `AniMagicCreationTests` for Creation values, catalog/repository orchestration, and disk-backed migration tests.

## Common agent mistakes

- Adding runtime behavior to a private legacy migration record.
- Passing `CreationRecord` into SwiftUI or Play.
- Treating a processed cutout as the source when the original drawing or photo is available.
- Persisting Play placements as part of Creation.
- Changing schema without a real old-store migration test.

## Language

**Creation**:
A user-owned item made from a drawing or imported photo and kept in the Backpack.
_Avoid_: Artwork, Saved Drawing, Cutout

**Creation Source**:
The retained input from which a Creation was made: PencilKit drawing data, an original photo, or a migrated legacy processed image.
_Avoid_: Input asset

**Playable Asset**:
The derived transparent visual representation consumed by Play. It can be regenerated when the Creation Source is available.
_Avoid_: Cutout Asset

**Species Assessment**:
An automatic species prediction and confidence, an optional user override, or a classification failure.
_Avoid_: Doodle classification

**Habitat**:
The land, skies, or underwater grouping derived from a Creation's effective species.
_Avoid_: Artwork Category

**Backpack**:
The user-facing collection of Creations.
_Avoid_: Artwork Library, Cutout Library

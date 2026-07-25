# Model user content as a Creation

**Status:** Accepted

## Context

Drawings and imported-photo cutouts previously had overlapping models and
lifecycles. That made Backpack ownership, classification, naming, and Play
eligibility depend on which entry path created an item.

## Decision

Drawings and imported photos are represented by one Creation aggregate. A
Creation retains its source and owns title state, species assessment, habitat,
and an optional derived playable asset. Play consumes a read-only
`PlayableCreation`.

## Consequences

- Creation Source is durable; Playable Asset is derived and optional.
- Former Artwork, Saved Drawing, and Cutout names are compatibility terminology.
- Original photos and drawing data should be retained when available.
- A legacy processed image remains representable when no original source exists.
- New user-content behavior is added to Creation, not parallel legacy models.

Supersede this ADR if user-created content is split into independently owned
aggregates.

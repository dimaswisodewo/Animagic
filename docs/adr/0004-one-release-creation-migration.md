# Migrate Creations through a bridge schema

**Status:** Accepted

## Context

The former schema stored drawings and cutouts separately. The current schema
joins them into one `CreationRecord`, including orphaned photo cutouts. A direct
two-entity-to-one-entity lightweight migration cannot express that join safely.

## Decision

Migrate in one app release through an internal bridge schema containing both
legacy and Creation models. A custom stage performs the verified join, followed
by a lightweight stage that removes legacy models.

## Consequences

- A drawing and its linked cutout become one Creation.
- Unconsumed cutouts become legacy-processed-image Creations.
- Migration must be idempotent and preserve source and playable bytes.
- Tests use real on-disk old-schema stores.
- Store-open failure falls back to an in-memory library without deleting the
  failed store.
- The bridge may be removed only through a future, explicitly tested migration
  decision.

Supersede this ADR before changing migration retention or recovery policy.

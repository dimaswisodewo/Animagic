# Use vertical context frameworks

**Status:** Accepted

## Context

The former single app target allowed feature, persistence, rendering, and UI code
to depend on each other without an explicit ownership boundary. A target for
every technical layer would add ceremony without matching the product model.

## Decision

AniMagic uses a small number of XcodeGen-managed vertical frameworks organized
around Creation and Play, with Design System and Support as narrow shared
foundations. The app target owns composition, routing, current feature UI, and
transitional adapters.

## Consequences

- Creation cannot import Play or app routing.
- Play may consume Creation and shared foundations.
- Target changes are made in `project.yml` and regenerated.
- App-owned Core and Features code remains transitional until it moves behind a
  context interface.
- New frameworks require a distinct ownership boundary, not merely a folder.

Supersede this ADR if the target strategy or dependency direction changes.

# Contributing Guide

RetroSmart is meant to be adapted by others, but contribution quality matters because the project is configuration-driven and cross-layer changes can drift quickly.

This guide sets the baseline for changes.

## 1. Source Of Truth

For product behavior and prototype intent, use [RetroSmart-PRD.md](./RetroSmart-PRD.md).

If implementation and docs disagree, either update the code to match the PRD or update the PRD deliberately to reflect a justified implementation decision.

## 2. Preferred Change Style

Prefer:

- small, inspectable edits
- directness over abstraction
- explicit ids and config fields
- lightweight patterns that fit the existing codebase
- docs updates in the same change set as behavior changes

Avoid:

- speculative rewrites
- generic frameworks for future possibilities
- config features that the app does not actually support
- silently changing BLE ids, action ids, or reading ids

## 3. Hardware And Firmware Expectations

When changing firmware:

- keep the YAML definition in sync
- keep reading/action ids stable where possible
- document pin-map changes
- note library additions
- preserve safety behavior for actuators

When changing hardware assumptions:

- update [README.md](../README.md)
- update [Hardware Notes](./Hardware-Notes.md)
- update [Compatibility Matrix](./Compatibility-Matrix.md)
- update the PRD if the change is now part of the prototype baseline

## 4. App Expectations

When changing the app:

- preserve inspectability of device types and config
- keep device flows understandable to non-expert users
- prefer fixes that improve correctness and reliability first
- keep automation behavior honest about foreground-only execution
- keep UI language compact and operational

## 5. BLE Expectations

Changes to BLE behavior should be evaluated for:

- reconnect behavior
- onboarding behavior
- stale identity handling
- multiple-device interaction
- state consistency between firmware and UI

This is the most fragile subsystem at scale, so treat BLE changes carefully.

## 6. YAML Expectations

The YAML parser is a limited schema parser, not a full YAML engine.

That means:

- keep examples and built-in configs simple
- avoid advanced YAML features unless the parser is extended intentionally
- keep `capabilities` and `automation` aligned with firmware behavior

## 7. Documentation Expectations

If a change affects module behavior, wiring, configuration shape, app flows, or BLE contract, update docs in the same change set.

Minimum targets:

- [README.md](../README.md)
- [RetroSmart-PRD.md](./RetroSmart-PRD.md)
- [Compatibility Matrix](./Compatibility-Matrix.md)
- any relevant guide in [docs](./)
- root community files if contribution, support, or security expectations change

## 8. Recommended Verification

For app changes:

- build the iOS app
- verify key flows in simulator or on device when useful

For firmware changes:

- compile or flash if possible
- verify the module still publishes the expected readings and actions

For docs-only changes:

- check links are relative and portable
- check examples match current YAML and firmware
- search for local absolute paths before committing

## 9. Pre-Commit Checklist

- `git status --short` shows only intended files
- iOS build passes when app code changed
- firmware compile status is stated when firmware changed
- docs mention any new limitations or safety notes
- no local machine paths appear in Markdown links

## 10. Good First Contribution Areas

- new module definitions
- doc improvements
- BLE robustness fixes
- device-page UX cleanup
- clearer settings/config inspection
- compatibility matrix updates

## 11. Open Areas That Still Need Structure

The repo is open and reusable now, but a few public-project conventions are still light:

- no dedicated hardware CAD/BOM release pack
- no contributor workflow automation
- no automated firmware build matrix

Those are good follow-up improvements if the project starts taking outside contributions.

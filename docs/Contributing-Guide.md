# Contributing Guide

## Purpose

RetroSmart is meant to be adapted by others, but contribution quality matters because the project is configuration-driven and cross-layer changes can drift quickly.

This guide sets the baseline for changes.

## 1. Source Of Truth

For product behavior and prototype intent, use:

- [docs/RetroSmart-PRD.md](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/docs/RetroSmart-PRD.md)

If implementation and docs disagree, either:

- update the code to match the PRD, or
- update the PRD deliberately to reflect a justified implementation decision

## 2. Preferred Change Style

Prefer:

- small, inspectable edits
- directness over abstraction
- explicit ids and config fields
- lightweight patterns that fit the existing codebase

Avoid:

- speculative rewrites
- generic frameworks for future possibilities
- config features that the app does not actually support

## 3. Hardware And Firmware Expectations

When changing firmware:

- keep the YAML definition in sync
- keep reading/action ids stable where possible
- document pin-map changes
- note library additions

When changing hardware assumptions:

- update README
- update docs
- update the PRD if the change is now part of the prototype baseline

## 4. App Expectations

When changing the app:

- avoid hiding important behavior behind clever abstractions
- preserve inspectability of device types and config
- keep device flows understandable to a non-expert user
- prefer fixes that improve correctness and reliability first

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
- do not depend on advanced YAML features unless the parser is extended intentionally

## 7. Documentation Expectations

If a change affects:

- module behavior
- wiring
- configuration shape
- app flows
- BLE contract

then update the docs in the same change set.

Minimum targets:

- [README.md](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/README.md)
- [docs/RetroSmart-PRD.md](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/docs/RetroSmart-PRD.md)
- any relevant guide in [docs](/Users/tong/Library/CloudStorage/OneDrive-Personal/Desktop/Solo%20Y/RetroSmart/docs)

## 8. Recommended Verification

For app changes:

- build the iOS app
- verify key flows in simulator or on device when useful

For firmware changes:

- compile or flash if possible
- verify the module still publishes the expected readings and actions

## 9. Good First Contribution Areas

- new module definitions
- doc improvements
- BLE robustness fixes
- device-page UX cleanup
- clearer settings/config inspection

## 10. Open Areas That Still Need Structure

The repo is open and reusable now, but a few public-project conventions are still light:

- no dedicated hardware release pack
- no formal issue templates
- no contributor workflow automation
- no explicit compatibility matrix yet

Those are good follow-up improvements if the project starts taking outside contributions.

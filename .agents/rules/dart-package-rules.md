# Dart & Flutter Package Factory Rules

These rules apply to all packages in this repository (both standalone and Dart workspace members under `packages/*`).

## 1. Static Analysis & Code Quality
- All Dart and Flutter code must pass `dart analyze --fatal-infos` with zero errors, warnings, or infos.
- Enforce strict typing: never use untyped declarations or `dynamic` unless interacting with raw untyped serialization boundaries.
- Sound Null Safety is mandatory across all packages.
- Follow the Dart Style Guide and enforce standard formatting via `dart format .`.

## 2. Public API & Documentation Standards
- Every public class, enum, mixin, extension, top-level function, constant, and public method must have a doc comment (`///`).
- Document parameter semantics, return values, and any thrown exceptions (`@throws`).

## 3. Widest Supported SDK & Dependency Ranges
- **SDK Lower Bounds**:
  - Keep Dart and Flutter SDK lower bounds as permissive and wide as possible.
  - **Never arbitrarily bump the SDK lower bound** (e.g., jumping from `sdk: ^3.0.0` to `sdk: ^3.7.0`). Only raise the minimum SDK constraint when the package strictly requires a new language or compiler feature that cannot be polyfilled.
  - Aim for broad community compatibility (e.g., supporting Dart `^3.0.0` or `^3.2.0` and Flutter `^3.10.0` / `^3.16.0` where possible).
- **Dependency Range Width**:
  - Use wide, permissive dependency ranges rather than tight, pinned versions.
  - Prefer compound ranges when upstream major versions retain source compatibility (e.g., `meta: ">=1.8.0 <3.0.0"` or `lints: ">=4.0.0 <7.0.0"`).
  - When upgrading dependencies, do not unnecessarily increase the lower bound if the existing lower bound still compiles and tests cleanly. This prevents "dependency hell" for downstream apps.
  - Validate minimum constraint compatibility by testing with `dart pub downgrade` during audits.

## 4. Zero Breaking Changes / Soft Deprecation Policy
- **Backwards Compatibility First**:
  - Target **zero breaking changes** across package updates.
  - Never delete or rename existing public classes, mixins, enums, functions, methods, or fields.
  - Never alter existing positional parameters or convert optional parameters into required parameters.
  - Any newly introduced parameters must be **optional named parameters with backwards-compatible defaults**.
- **Soft Deprecation**:
  - When replacing an API or refactoring, always preserve the existing symbol and annotate it with `@Deprecated('Use <replacement> instead. Will be removed in next major release.')`.
  - Maintain an internal forwarding implementation so legacy consumer code continues to compile and work identically without interruption.
- **Breaking Change Gate**:
  - If a breaking change is strictly unavoidable, it must be flagged by the SemVer Gatekeeper (`dart_apitool`), require human approval, and be scheduled for a SemVer Major version bump documented in `CHANGELOG.md`.

## 5. Testing & Verification Requirements
- Every new feature or bug fix must include corresponding tests under the package's `test/` directory.
- For bug reports, always write a reproduction test case first before applying a fix.
- Verify tests using `dart test` (or `flutter test` for Flutter plugins).

## 6. Conventional Commits & Versioning
- All commit messages must follow the Conventional Commits specification:
  - `feat(<package>): <description>` (triggers Minor bump)
  - `fix(<package>): <description>` (triggers Patch bump)
  - `docs(<package>): <description>`
  - `chore(<package>): <description>`
  - `BREAKING CHANGE: <explanation>` in commit footer (triggers Major bump)
- Keep `CHANGELOG.md` in sync with all package modifications under the upcoming unreleased version header.

## 7. Pub.dev / Pana Score Hygiene
- Maintain a 140/140 score on Pana.
- Ensure package `pubspec.yaml` has:
  - Concise `description` (between 60 and 180 characters).
  - Valid `homepage` or `repository` URL.
  - Valid `issue_tracker` URL.
  - Specified `topics`.
- Ensure an `example/` project exists and builds cleanly for all supported platforms.

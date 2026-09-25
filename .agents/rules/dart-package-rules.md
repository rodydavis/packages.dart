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
- Preserve backward compatibility on public APIs. If a breaking change is strictly unavoidable, it must be flagged for SemVer Major bump and documented in `CHANGELOG.md`.

## 3. Testing & Verification Requirements
- Every new feature or bug fix must include corresponding tests under the package's `test/` directory.
- For bug reports, always write a reproduction test case first before applying a fix.
- Verify tests using `dart test` (or `flutter test` for Flutter plugins).

## 4. Conventional Commits & Versioning
- All commit messages must follow the Conventional Commits specification:
  - `feat(<package>): <description>` (triggers Minor bump)
  - `fix(<package>): <description>` (triggers Patch bump)
  - `docs(<package>): <description>`
  - `chore(<package>): <description>`
  - `BREAKING CHANGE: <explanation>` in commit footer (triggers Major bump)
- Keep `CHANGELOG.md` in sync with all package modifications under the upcoming unreleased version header.

## 5. Pub.dev / Pana Score Hygiene
- Maintain a 140/140 score on Pana.
- Ensure package `pubspec.yaml` has:
  - Concise `description` (between 60 and 180 characters).
  - Valid `homepage` or `repository` URL.
  - Valid `issue_tracker` URL.
  - Specified `topics`.
- Ensure an `example/` project exists and builds cleanly for all supported platforms.

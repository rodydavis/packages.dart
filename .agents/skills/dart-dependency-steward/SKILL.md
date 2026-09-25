---
name: dart-dependency-steward
description: Automated dependency manager for Dart and Flutter packages. Audits pubspec dependencies, identifies outdated packages, upgrades constraints safely, maximizes supported SDK/package target ranges, avoids unnecessary lower-bound bumps, runs tests, and fixes breaking API updates. Use when bumping dependencies, resolving pub conflicts, or updating outdated packages.
---

# Dart Dependency Steward

Responsible for maintaining fresh, secure, and widely compatible dependencies across Dart and Flutter packages without introducing breaking changes or narrowing consumer target ranges.

## Guiding Principles: Wide Target Ranges & Minimal Breaking Changes

1. **Widen, Don't Restrict**:
   - When bumping a dependency to allow newer versions, prefer widening the upper bound or using compound ranges (e.g. `meta: ">=1.8.0 <3.0.0"`) instead of bumping the lower bound to the latest version.
   - Do NOT needlessly bump `sdk: ^3.0.0` to `sdk: ^3.7.0` if the code works on earlier SDKs. Keep the SDK lower bound as low as viable.
2. **Conservative Lower Bounds**:
   - Raising a lower bound forces all downstream consumers to upgrade their dependencies, potentially causing dependency hell in large client apps.
   - Only raise a dependency lower bound if a critical security vulnerability exists or a newly used feature strictly demands it.
3. **Verify with Minimum Bounds**:
   - Run `dart pub downgrade` periodically to verify that code still builds with the declared minimum dependency versions.

## Procedure

### 1. Identify Outdated Dependencies
Run `dart pub outdated` in JSON mode for each package:

```bash
dart pub outdated --json
```

Analyze the version matrix:
- **Current**: Version currently resolved in `pubspec.lock`.
- **Upgradable**: Highest version matching current constraints.
- **Resolvable**: Highest version resolvable by modifying `pubspec.yaml`.
- **Latest**: Absolute newest version on pub.dev.

### 2. Update Constraints (Preserving Wide Ranges)
1. If **Upgradable** != **Current**, run `dart pub upgrade` to test the newest compatible version without changing `pubspec.yaml`.
2. If **Resolvable** requires changing constraints:
   - Check if the new version is a major bump (e.g. `1.x` -> `2.x`).
   - If the package API changes were minor or backwards-compatible, consider a compound range:
     `dependency: ">=1.5.0 <3.0.0"`
   - If a breaking change occurred upstream, update the constraint carefully and adapt calling code while preserving backwards compatibility on the package's *own* public API.

### 3. Test & Fix Breakages
1. Run `dart analyze --fatal-infos`.
   - If an upgraded dependency deprecated an API, update internal implementation to the modern API while preserving all existing public methods via `@Deprecated` delegates.
2. Run test suites:
   ```bash
   dart test
   # Or for Flutter packages:
   flutter test
   ```
3. Test minimum resolution:
   ```bash
   dart pub downgrade
   dart analyze --fatal-infos
   dart test
   # Restore latest resolved
   dart pub upgrade
   ```

### 4. Update Changelog & Commit
1. Add an entry to the package's `CHANGELOG.md`:
   ```markdown
   ## Unreleased
   - chore(deps): widen support for <package_name> up to ^<version>
   ```
2. Commit with conventional commit:
   `chore(deps): widen dependency constraints in <package_name>`

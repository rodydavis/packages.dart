---
name: dart-dependency-steward
description: Automated dependency manager for Dart and Flutter packages. Audits pubspec dependencies, identifies outdated packages, upgrades constraints safely, runs tests, and fixes breaking API updates. Use when bumping dependencies, resolving pub conflicts, or updating outdated packages.
---

# Dart Dependency Steward

Responsible for maintaining fresh, secure, and compatible dependencies across Dart and Flutter packages without introducing regressions.

## Procedure

### 1. Identify Outdated Dependencies
Run `dart pub outdated` in JSON mode for each package:

```bash
dart pub outdated --json
```

Classify outdated packages into two categories:
- **Upgradable (Minor / Patch)**: Safe to bump without breaking API contracts.
- **Resolvable (Major breaking)**: Requires code review and potential refactoring of calling code.

### 2. Update Constraints
For each eligible dependency:
1. Update `pubspec.yaml` with the target version constraint (e.g. `^x.y.z`).
2. Run `dart pub get` to resolve the updated dependency graph.

### 3. Test & Fix Breakages
1. Run `dart analyze --fatal-infos`.
   - If deprecated API warnings or signature changes appear due to the upgraded dependency, inspect the changes using LSP or package release notes and refactor the package code to support the new API.
2. Run the test suite:
   ```bash
   dart test
   # Or for Flutter packages:
   flutter test
   ```
3. If tests fail and cannot be cleanly fixed within this pass, revert that specific package bump and log the conflict.

### 4. Update Changelog & Commit
1. Add an entry to the package's `CHANGELOG.md`:
   ```markdown
   ## Unreleased
   - chore(deps): upgrade <package_name> to ^<version>
   ```
2. Commit with conventional commit:
   `chore(deps): upgrade dependencies in <package_name>`

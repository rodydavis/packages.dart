---
name: dart-factory-orchestrator
description: Master assembly line orchestrator for Dart and Flutter package maintenance. Discovers workspace packages, audits repository health, runs dependency and quality sweeps, and coordinates specialist subagents. Use when running a full maintenance cycle, periodic health sweep, or headless factory run.
---

# Dart Package Factory Orchestrator

The orchestrator inspects the repository, discovers all Dart and Flutter packages (standalone or within a Dart workspace / Melos monorepo), schedules specialist maintenance tasks, and aggregates results.

## Orchestration Flow

```
1. Discover Packages -> 2. Run Health Baseline -> 3. Dispatch Tasks -> 4. Quality Gate -> 5. Summary Report
```

### Step 1: Package Discovery
1. Check the root `pubspec.yaml` for a `workspace:` key.
   - If present, parse the listed workspace paths (e.g. `packages/*`).
   - If not present, find all subdirectories containing a `pubspec.yaml` (excluding hidden dirs, build caches, and `.dart_tool`).
2. List the detected packages, their current versions, and package types (Dart package vs Flutter plugin).

### Step 2: Establish Baseline Health
1. Run `dart pub get` from the root (or in each package).
2. Run `dart analyze` across the repository to detect any pre-existing issues.
3. Run `dart test` or relevant test commands to ensure baseline tests pass.

### Step 3: Dispatch Specialist Workstations
Depending on the requested task (or full maintenance sweep):

- **Dependency Upgrades**:
  Invoke the `dart-dependency-steward` skill.
  Checks for outdated packages, bumps non-breaking constraints, runs tests, and applies any required API migration fixes.

- **Pana & Quality Audit**:
  Invoke the `dart-pana-auditor` skill.
  Audits pub.dev score factors (140/140 points target), verifies README, license, platform support, and doc comments.

- **API & SemVer Verification**:
  Invoke the `dart-semver-gatekeeper` skill.
  Diffs public APIs against published versions to ensure semantic versioning compliance and updates `CHANGELOG.md`.

- **Release Preparation**:
  Invoke the `dart-release-manager` skill.
  Validates release readiness with `dart pub publish --dry-run` and stages tags/PRs.

### Step 4: Verification and Quality Gate
1. Run `dart format .` across all touched files.
2. Run `dart analyze --fatal-infos` across the entire workspace.
3. Run all unit tests: `dart test` (or `flutter test`).

### Step 5: Output Report
Generate a summary markdown report with:
- Packages audited and updated.
- Dependencies bumped.
- Score improvements and resolved issues.
- Git status (modified files, proposed branch name, and commit message).

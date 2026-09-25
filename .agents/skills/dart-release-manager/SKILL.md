---
name: dart-release-manager
description: Release management and pub.dev publication preparation skill for Dart and Flutter packages. Performs publication dry-runs, validates release assets, formats changelogs, and stages release tags. Use when preparing, validating, or cutting a new package release.
---

# Dart Release Manager

Orchestrates the safe preparation and validation of package releases to pub.dev.

## Safety Directive
**NEVER run `dart pub publish` without the `--dry-run` flag.**
Actual publishing to pub.dev is completed via automated CI (using Gitea Actions / GitHub Actions with trusted OIDC credentials) upon PR merge or tag push.

## Release Checklist

### 1. Pre-Release Verification
In the target package directory:
1. Ensure git working directory is clean.
2. Run `dart pub get`.
3. Run `dart analyze --fatal-infos`.
4. Run `dart test` (or `flutter test`).

### 2. Publication Dry Run
Run:
```bash
dart pub publish --dry-run
```
Inspect the output:
- **Package size**: Verify unnecessary files (`.DS_Store`, build caches, large test data) are not included.
- **Analysis results**: Zero warnings or errors.
- **License / Readme / Changelog**: Verified by the pub client.

If any issues are reported by `--dry-run`, resolve them before proceeding.

### 3. Stage Release Artifacts
1. Ensure the version in `pubspec.yaml` matches the unreleased entry in `CHANGELOG.md`.
2. Commit with conventional commit:
   ```bash
   git commit -m "chore(release): prepare <package_name> v<version>"
   ```
3. Prepare the tag name: `<package_name>-v<version>` (or `v<version>` for standalone repos).

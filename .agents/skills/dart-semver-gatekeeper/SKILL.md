---
name: dart-semver-gatekeeper
description: API difference analyzer and Semantic Versioning gatekeeper for Dart and Flutter packages. Detects breaking changes using dart_apitool or git history, verifies SemVer compliance, and generates changelogs. Use before releases or after significant API changes to determine version bump requirements.
---

# Dart SemVer Gatekeeper

Protects consumers from unintentional breaking changes by analyzing public API signatures and enforcing Semantic Versioning (SemVer 2.0.0).

## SemVer Rules Reference
- **MAJOR (`x.0.0`)**: Incompatible API changes (removed public functions/classes/fields, changed parameter types, added non-nullable required parameters, altered inheritance hierarchy).
- **MINOR (`x.y.0`)**: Backwards-compatible new functionality (added classes, added methods with defaults, new optional parameters).
- **PATCH (`x.y.z`)**: Backwards-compatible bug fixes, documentation, internal optimizations.

## Procedure

### 1. Extract and Diff API Signature
Using `dart_apitool`:

```bash
dart pub global activate dart_apitool
dart pub global run dart_apitool extract --input <package_path> --output current_api.json
```

Compare against the previous tag or published version:
```bash
dart pub global run dart_apitool diff --old <previous_api.json> --new current_api.json
```

### 2. Determine Required Version Bump
- If breaking changes are found:
  - If a breaking change was intended, the next version must bump **MAJOR**.
  - If a breaking change was unintentional, refactor the code to restore backwards compatibility (e.g. deprecate rather than delete, add optional parameters rather than changing existing ones).
- If only new additions are present, bump **MINOR**.
- If only internal fixes or documentation are present, bump **PATCH**.

### 3. Update Package Files
1. Update `version:` in `pubspec.yaml`.
2. Format `CHANGELOG.md` with standard headers:
   ```markdown
   ## [x.y.z] - YYYY-MM-DD
   ### Added
   - New feature details...
   ### Changed
   - Details...
   ### Fixed
   - Bug fix details...
   ```

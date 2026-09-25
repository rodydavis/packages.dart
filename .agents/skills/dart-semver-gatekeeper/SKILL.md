---
name: dart-semver-gatekeeper
description: API difference analyzer and Semantic Versioning gatekeeper for Dart and Flutter packages. Detects breaking changes using dart_apitool or git history, verifies SemVer compliance, enforces soft deprecation over breaking changes, and generates changelogs. Use before releases or after significant API changes to determine version bump requirements.
---

# Dart SemVer Gatekeeper

Protects consumers from unintentional breaking changes by analyzing public API signatures, enforcing Semantic Versioning (SemVer 2.0.0), and enforcing **soft deprecation** over hard breaking changes.

## Zero Breaking Changes & Soft Deprecation Mandate

1. **Avoid Breaking Changes**:
   - Every public API change should strive to be backwards-compatible (Minor or Patch).
   - If an API must be redesigned or renamed:
     - **DO NOT delete or rename the existing symbol.**
     - Introduce the new symbol with the desired signature.
     - Keep the old symbol intact, mark it with `@Deprecated('Use <new_symbol> instead. Will be removed in next major release.')`, and delegate to the new implementation.
2. **Parameter Evolution**:
   - Never change a positional parameter or change parameter types.
   - Any new capability must be added via **optional named parameters with backwards-compatible defaults**.
3. **SDK Lower Bound Guard**:
   - Ensure the minimum `sdk:` constraint is not increased unless strictly required by new language features that cannot be polyfilled.

## Procedure

### 1. Extract and Diff API Signature
Using `dart_apitool`:

```bash
dart pub global activate dart_apitool
dart pub global run dart_apitool extract --input <package_path> --output current_api.json
```

Compare against the previous tag or published pub.dev version:
```bash
dart pub global run dart_apitool diff --old <previous_api.json> --new current_api.json
```

### 2. Remediate Breaking Changes
If `dart_apitool` flags any breaking change:
1. **Analyze the diff**:
   - Was a method, class, or parameter removed?
   - Was a parameter type made narrower?
   - Was a non-optional parameter added?
2. **Apply Soft Deprecation**:
   - Restore the removed symbol.
   - Add `@Deprecated(...)` annotation.
   - Forward the call to the new API.
3. **Re-run `dart_apitool diff`**:
   - Confirm that the change is now classified as **MINOR** (backwards compatible addition) or **PATCH**, rather than **MAJOR**.

### 3. Determine Required Version Bump
- If breaking changes are unavoidable and explicitly authorized by the maintainer: Bump **MAJOR** (`x.0.0`).
- If backwards-compatible new features, deprecations, or additions were made: Bump **MINOR** (`x.y.0`).
- If only internal fixes, docs, or test improvements were made: Bump **PATCH** (`x.y.z`).

### 4. Update Package Files
1. Update `version:` in `pubspec.yaml`.
2. Format `CHANGELOG.md` with standard headers and clear deprecation notices:
   ```markdown
   ## [x.y.z] - YYYY-MM-DD
   ### Added
   - Added `newFeature()` with backwards-compatible defaults.
   ### Deprecated
   - `oldFeature()` is deprecated in favor of `newFeature()`.
   ### Fixed
   - Fixed bug in ...
   ```

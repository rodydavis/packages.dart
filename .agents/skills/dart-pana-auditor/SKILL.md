---
name: dart-pana-auditor
description: Package health auditor and score optimizer for Dart and Flutter pub.dev packages. Inspects packages using pana, diagnoses score deductions, fixes documentation, missing platforms, licenses, and ensures 140/140 score compliance. Use when auditing package quality or preparing packages for pub.dev.
---

# Dart Pana Auditor

Ensures packages meet the highest quality standards expected by pub.dev and community users (targeting 140/140 points).

## Prerequisites
Ensure `pana` is available:
```bash
dart pub global activate pana
```

## Audit Categories

Pana scores packages based on five core criteria:

1. **Follow Dart file conventions (30/30 pts)**:
   - Proper directory layout (`lib/`, `test/`, `example/`).
   - `dart format` compliance.
   - Valid `pubspec.yaml` with required fields (`name`, `description`, `version`, `homepage` or `repository`, `issue_tracker`, `topics`).

2. **Provide documentation (20/20 pts)**:
   - `README.md` (detailed overview, installation, code snippets).
   - `CHANGELOG.md` (chronological version history).
   - `LICENSE` file.
   - 100% doc comment coverage (`///`) on public API members.

3. **Support sound null safety (20/20 pts)**:
   - Sound null safety enabled with compatible SDK constraint (e.g. `sdk: ^3.5.0`).

4. **Support multiple platforms (20/20 pts)**:
   - For Dart packages: Support for Web and Native (Linux, macOS, Windows, Android, iOS).
   - Avoid unintentional platform-specific imports (e.g., `dart:io` in web-capable libraries, or `dart:html` in pure Dart). Use conditional imports where needed.

5. **Pass static analysis (50/50 pts)**:
   - Zero errors, warnings, or hints from `dart analyze`.

## Execution Workflow

1. **Run Pana**:
   ```bash
   dart pub global run pana --json --no-warning <package_dir> > /tmp/pana_report.json
   ```

2. **Inspect Deductions**:
   Parse `/tmp/pana_report.json` for any category scoring below maximum points.

3. **Apply Automatic Fixes**:
   - **Formatting**: Run `dart format .` in the package root.
   - **Pubspec metadata**: Add missing `repository`, `issue_tracker`, or `topics`.
   - **Missing doc comments**: Scan exported symbols and add descriptive `///` doc comments.
   - **Example app**: If missing, create `example/lib/main.dart` demonstrating standard library usage.

4. **Re-evaluate Score**:
   Rerun `pana` to confirm all 140 points are attained.

---
name: dart-issue-triager
description: Automated issue triage and classification specialist for Dart and Flutter packages. Analyzes incoming bug reports, stack traces, and feature requests, maps them to target packages and source files, writes reproduction test cases, and posts structured triage assessments. Use when triaging new issues or assessing bug reports.
---

# Dart Issue Triager

Specialist workstation responsible for ingesting incoming Gitea/GitHub issues, analyzing technical content, identifying target packages, verifying reproducibility, and posting helpful triage summaries.

## Triage Procedure

### 1. Ingest & Classify Issue
1. Retrieve issue details using `./scripts/gitea_api.sh get-issue <ISSUE_NUMBER>`.
2. Parse the issue title, body, and attached stack traces or logs:
   - **Target Package Identification**:
     Determine which workspace package under `packages/*` is affected (e.g., `packages/flutter_vibrate`, `packages/app_review`, etc.).
   - **Issue Categorization**:
     - `bug`: Runtime crash, exception, build failure, unexpected behavior.
     - `feature`: Request for new API or platform capability.
     - `dependency`: Outdated dependency constraint or conflict.
     - `documentation`: Unclear examples, missing doc comments, or broken links.
     - `question`: General usage or configuration inquiry.

### 2. Codebase Impact & Reproduction Analysis
1. Inspect the relevant source files in the target package using LSP or search tools.
2. Locate the specific functions, classes, or build files referenced in the issue.
3. Check if a reproduction unit test can be constructed under `packages/<target>/test/`.
4. If the issue is an SDK/platform incompatibility (e.g. Android Gradle plugin or iOS simulator build error), examine the plugin configuration files (`android/build.gradle`, `ios/*.podspec`).

### 3. Generate Structured Triage Comment
Post a helpful technical response via `./scripts/gitea_api.sh comment-issue <ISSUE_NUMBER>` with:

```markdown
### 🤖 Antigravity AI Factory Triage Assessment

- **Affected Package**: `packages/<name>`
- **Category**: `Bug / Feature / Dependency`
- **Initial Diagnosis**: Summary of what is causing the reported behavior.
- **Affected Files**:
  - `packages/<name>/lib/...`
- **Action Plan**:
  1. Reproduction test case proposed in `test/...`
  2. Proposed fix adhering to zero-breaking-change policy.
- **Next Step**: Automated fix can be initiated via `./scripts/factory_runner.sh issue <ISSUE_NUMBER>`.
```

### 4. Automated Fix Trigger (Optional)
If the bug is deterministic and reproduction tests pass, proceed to launch the fix phase and open a linked Pull Request (`Fixes #<ISSUE_NUMBER>`).

# Antigravity Workspace Configuration: Dart Package Factory

This workspace is configured as an autonomous **Software AI Factory** for maintaining Dart and Flutter packages.

## Workspace Guidelines
- Detailed package development and quality standards are defined in [.agents/rules/dart-package-rules.md](file:///.agents/rules/dart-package-rules.md).
- Automated hooks are declared in [.agents/hooks.json](file:///.agents/hooks.json).
- Factory assembly line skills are in [.agents/skills/](file:///.agents/skills/).

## Core Directives
1. Never compromise static analysis. Always ensure `dart analyze --fatal-infos` passes cleanly.
2. Format all Dart code (`dart format .`).
3. Maintain backwards compatibility and verify SemVer rules when modifying public API signatures.
4. Aim for 140/140 Pana score for all published packages.

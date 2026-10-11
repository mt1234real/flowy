# pfm_app

Finance Prj

## Architecture / working context

Flowy is a local-first Flutter personal finance app using Riverpod and Drift.
Read `AGENTS.md` for development rules and `docs/backup_encryption.md` for the
backup security contract. The Git repository and actual source are authoritative.

Useful architecture entry points:

- `lib/main.dart`: application entry and root setup.
- `lib/data/database.dart`: Drift schema, queries and atomic accounting operations.
- `lib/core/animation/app_animation_policy.dart`: preserved routes and Fluid Sheets.
- `lib/core/animation/flowy_navigation_motion.dart`: tab and pilot page transitions.
- `lib/screens/main_scaffold.dart`: retained tabs, floating navigation dock and FAB.
- `lib/core/feedback/app_feedback.dart`: centralized status and undo feedback.

Optional local architecture notes are kept outside the clean repository. A clone
does not require them; archived originals remain in local backups only. Google
Drive handoff documents are shared AI context, not replacements for this repository.

Development snapshots may contain motion prototypes awaiting device review.
They do not imply final visual approval or measured high-refresh performance.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# 🤖 AGENTS.md — Operational Protocols & Guardrails for Codex

> **Dự án**: PFM Vault (Flowy)  
> **Target**: Flutter 3.24+ / Dart 3.5+  
> **Mục đích**: Bản hướng dẫn kỹ thuật cưỡng chế dành riêng cho AI Coding Agents (Codex). Mọi thao tác chỉnh sửa mã nguồn BẮT BUỘC tuân thủ 100% các điều khoản dưới đây.

---

## 1. SOURCE OF TRUTH & ARCHITECTURE CONTEXT
- Trước khi thực hiện bất kỳ tác vụ nào liên quan đến CSDL, công thức tài chính hoặc cấu trúc màn hình, Agent **bắt buộc phải tham chiếu phần Architecture / working context trong `README.md`, tài liệu liên quan trong `docs/` và source thực tế**. Ghi chú kiến trúc local là tài liệu bổ sung nếu hiện diện, không bắt buộc với người clone repository. Git và working tree vẫn là source of truth.
- **Tech Stack cốt lõi**:
  - State Management: `flutter_riverpod`
  - Cơ sở dữ liệu: `drift` (SQLite cục bộ, Schema v8 Soft-Delete)
  - Kiến trúc: Local-First, Zero Server Cost, Offline-First
  - Animation Engine: Universal Animation Hardening & Fluid Sheet Engine

---

## 2. STRICT DRIFT SQLITE SCHEMA RULES (KHÔNG PHÁ VỠ DATABASE)
Khi viết câu truy vấn hoặc thao tác Entity Drift trong `lib/data/database.dart`:
1. **`Categories`**: Tuyệt đối **KHÔNG** truy xuất cột `isActive` (bảng này không tồn tại cột này).
2. **`Budgets`**: Tuyệt đối **KHÔNG** truy xuất `startDate`, `endDate`, `periodType`. Dải ngày chu kỳ luôn được tính toán động qua helper `resolveBudgetWindow()`.
3. **`DebtContacts`**: Bảng CHỈ CÓ 7 cột: `id`, `name`, `phone`, `avatarUrl`, `netBalance`, `createdAt`, `updatedAt`. Tuyệt đối **KHÔNG** truy xuất các cột ảo: `phoneNumber`, `bankName`, `bankAccount`, `note`, `avatarType`, `avatarValue`, `colorHex`, `isArchived`.
4. **Khởi tạo Wallet thủ công**: Khi mock hoặc fallback `Wallet(...)`, bắt buộc truyền đủ 4 trường non-nullable: `isDefault: false`, `isArchived: false`, `sortOrder: 0`, `updatedAt: DateTime.now()`.
5. **Toàn vẹn số dư (ACID Transactions)**:
   - Sửa giao dịch chuẩn: Dùng `updateTransactionAtomically()` (in-place update, không soft-delete rồi insert lại).
   - Chuyển giao dịch chuẩn sang nợ: Dùng `convertTransactionToDebtAtomically()`.
   - Cập nhật nợ: Dùng `updateDebtTransaction()` (rollback delta cũ và apply delta mới trong 1 khối `db.transaction`).
   - Xóa giao dịch: Luôn dùng Soft-Delete (`softDeleteTransaction`, `softDeleteDebtTransaction`), không xóa cứng trực tiếp từ UI thông thường.

---

## 3. FLUID SHEET ENGINE & NAVIGATION CONTRACT
Dự án đã chuẩn hóa 100% Bottom Sheet lên hạ tầng **Fluid Sheet Engine**:
1. **Quy tắc Launcher**:
   - Tuyệt đối **KHÔNG** gọi `showModalBottomSheet()` trực tiếp trong bất kỳ màn hình nào.
   - Tuyệt đối **KHÔNG** dùng `AppAnimationPolicy.showPreservedSheet()`.
   - **BẮT BUỘC** dùng: `AppAnimationPolicy.showFluidSheet()`.
2. **QuickEntrySheet Law**:
   - `QuickEntrySheet` sở hữu constructor private: `QuickEntrySheet._`.
   - Tuyệt đối không gọi `const QuickEntrySheet()` hoặc gọi trực tiếp constructor.
   - **BẮT BUỘC** mở qua static launcher: `QuickEntrySheet.show(context, ...)`.
3. **Physics bên trong Bottom Sheet**:
   - Khi cuộn dọc trong Fluid Sheet (`mode: FluidSheetMode.scrollable`), bắt buộc dùng `physics: const ClampingScrollPhysics()` và gắn `scrollController` do engine cấp. Tuyệt đối không dùng `BouncingScrollPhysics` bên trong Sheet vì gây xung đột cử chỉ kéo hạ (drag-to-dismiss).
4. **Tránh Double Blur**:
   - Đối với các modal con/lồng nhau (ví dụ: modal chọn ví bên trong `QuickEntrySheet`), bắt buộc đặt cờ `enableBlur: false`.

---

## 4. HYPEROS / ANDROID ANIMATION HARDENING RULES
Để miễn nhiễm 100% trước tình trạng thiết bị bật chế độ Tiết kiệm pin hoặc Developer Options chỉnh Animator duration scale về 0x:
1. Mọi `AnimationController` đều **BẮT BUỘC** khởi tạo qua helper:
   ```dart
   _controller = AppAnimationPolicy.createController(
     vsync: this,
     duration: ...,
     debugLabel: '...',
   );
   ```
   (Helper này tự động gán `animationBehavior: AnimationBehavior.preserve`).
2. Tuyệt đối không dùng `AnimationController(...)` trần trụi nếu không có cờ `preserve`.
3. Khi viết custom PageRoute hoặc DialogRoute, bắt buộc override `createAnimationController()` trả về controller có `AnimationBehavior.preserve`.

---

## 5. UNIVERSAL FEEDBACK & NOTIFICATION ARCHITECTURE
Dự án không dùng SnackBar tùy tiện:
1. **Thông báo trạng thái (Success / Info / Error)**:
   - Dùng: `AppFeedback.showSuccess(context, ...)` hoặc `AppFeedback.showInfo(context, ...)`.
   - Hiển thị dạng Top Banner Pill sát mép Status Bar trên root Overlay.
   - Tuyệt đối **KHÔNG** gọi `ScaffoldMessenger.of(context).showSnackBar()` rải rác.
2. **Lỗi nhập liệu trong Form / Bottom Sheet**:
   - Dùng cơ chế **In-Situ Shake**: Rung lắc tại chỗ qua `AppValidationFeedback` và rung `HapticFeedback.heavyImpact()`.
   - Tuyệt đối không bật SnackBar/Toast che khuất phía sau modal.
3. **Hoàn tác xóa (Undo)**:
   - Dùng: `AppFeedback.showUndo(context, message: ..., onUndo: ...)`.
   - Dock nổi thích ứng tự động né thanh BottomBar/FAB 12px với thời gian đếm lùi 3.0s.

---

## 6. CODING & REFACTORING PROTOCOLS CHO AGENT
Khi nhận lệnh sửa mã nguồn:
1. **No Code Truncation**: Tuyệt đối không xóa logic phụ, không để lại comment kiểu `// TODO: giữ nguyên code cũ...`. Xuất đầy đủ ngữ cảnh để tệp tin biên dịch được ngay.
2. **Import Cleanliness**:
   - Import database singleton: `import '../data/database.dart';` (trỏ vào `databaseProvider`).
   - Khi import Drift trong tệp có widget `Column` của Material:
     ```dart
     import 'package:drift/drift.dart' hide Column;
     ```
   - Khi dùng toán học: `import 'dart:math' as math;`.
3. **Null-Safety Guardrails**:
   - Khi đọc các provider tính toán tài chính (`fastRecoveryTotalDays`, `amortizedDailyDeduction`, v.v.), luôn có giá trị fallback tường minh (`?? 0`, `?? 0.0`) trước khi tính toán.
4. **Tự Động Kiểm Tra (Self-Verification)**:
   Sau khi chỉnh sửa xong các file, Agent phải chủ động chạy kiểm tra:
   - Phân tích cú pháp: `flutter analyze`
   - Nếu có thay đổi Schema Drift: `dart run build_runner build --delete-conflicting-outputs`
### 5. Testing & Scope Boundaries (Non-negotiable)
- **STRICT PROHIBITION ON SPECULATIVE TESTS**:
   - Tuyệt đối KHÔNG tự ý tạo mới, sinh thêm hay sửa đổi các tệp kiểm thử trong thư mục `test/*` trừ khi người dùng có yêu cầu bằng văn bản rõ ràng: *"Hãy viết test cho tính năng này"*.
   - Mọi nhiệm vụ liên quan đến UI/UX, Refactoring hoặc Copywriting chỉ được phép can thiệp trực tiếp vào danh sách các tệp mã nguồn (`lib/*`) được chỉ định trong phạm vi yêu cầu.
   - Sau khi chỉnh sửa, chỉ chạy kiểm tra phân tích tĩnh (`flutter analyze`), không tự ý chạy hoặc sinh suite test tốn thời gian.

---

## ChatGPT / Google Drive Handoff

### Source of truth

- The Git repository and actual working tree are the source of truth for source code and project implementation.
- Google Drive is shared context/handoff between Codex and ChatGPT, which is used as a separate architecture, debugging, and review assistant. Drive does not replace Git.
- The primary handoff document is `Flowy/FLOWY_HANDOFF.md`.

### Mandatory end-of-task handoff

After each task that meaningfully changes source code, architecture, navigation, animations, behavior, dependencies, configuration, tests, or performance, Codex must update `Flowy/FLOWY_HANDOFF.md` through the connected Google Drive plugin.

Do this at the END of the task, after inspecting the final diff and completing all practical validation. Do not wait for the user to request the handoff update.

Before writing the handoff:

1. Read the current version of `Flowy/FLOWY_HANDOFF.md`.
2. Inspect the actual repository state and relevant source code.
3. Check `git status`, `git diff`, `git diff --stat`, `git diff --name-only`, the current branch, and the HEAD commit.
4. Record only facts confirmed by the repository, source code, and actual validation. Clearly identify uncertainty and unverified claims.

### Required handoff contents

Keep the document concise but sufficient for another AI that has not seen the current Codex conversation. It must always contain these sections:

- **Current state**: Current implementation and architecture.
- **Changes made**: What changed, why it changed, and important implementation details for each meaningful change.
- **Files changed**: The relevant files actually modified in the current task.
- **Architecture / decisions**: Technical decisions and invariants future work must preserve.
- **Validation**: Clearly separate **PASS**, **FAIL**, **NOT RUN**, and **DEVICE VALIDATION PENDING**. Never record PASS unless the check was actually performed and passed.
- **Known issues**: Unresolved bugs, uncertainty, performance concerns, or relevant technical debt.
- **Next recommended step**: The most logical next action.
- **Git state**: When available, include the branch, HEAD commit/hash, working tree state (including uncommitted changes), and a concise diff summary.

The handoff is a living CURRENT-STATE document, not a chronological chat transcript. Do not append raw conversation history or create a long journal. Preserve still-valid decisions and known issues; update or remove information that is no longer true.

### Google Drive organization

- `Flowy/builds/`: APKs and build outputs.
- `Flowy/screenshots/`: Screenshots and reference frames.
- `Flowy/test-results/`: Test logs, benchmarks, and profiling results.
- `Flowy/patches/`: Diffs or patches that need to be shared.
- `Flowy/code/`: Code snapshots for AI context when needed.

Do not upload the entire Git repository to Drive as a replacement for Git. Do not create an additional complex documentation system without a demonstrated need. `FLOWY_HANDOFF.md` remains the primary handoff.

If Google Drive is temporarily unavailable, finish the coding task normally and explicitly tell the user that the handoff document could not be updated.

### Delta-first AI context rule

The handoff must optimize for incremental context transfer.

After a coding task:

- Do NOT regenerate or upload a full-project code snapshot by default.
- Do NOT copy large source files into `FLOWY_HANDOFF.md`.
- Summarize only the meaningful delta from the completed task.
- Record the exact changed files and relevant implementation symbols/functions/classes.
- Prefer a concise diff/patch in `Flowy/patches/` when another AI may need implementation-level review.
- `Flowy/code/` full or broad code snapshots are optional fallback context only and must be created/refreshed only when explicitly useful.

ChatGPT should normally be able to continue from `FLOWY_HANDOFF.md` alone.

If implementation-level inspection is required, provide the smallest sufficient context in this order:

1. Relevant section of `FLOWY_HANDOFF.md`.
2. Task-specific diff/patch.
3. Specific changed source file(s).
4. Broader code snapshot only as a last resort.

Never require another AI to reread the whole repository merely because a new task changed a small part of the codebase.

### Code snapshot freshness policy

the broad XML code snapshot in `Flowy/code/` is a broad AI-readable repository snapshot.

It is NOT:

- The source of truth.
- The primary handoff.
- Something that must be regenerated after every task.

The Git repository and working tree remain the source of truth.
`FLOWY_HANDOFF.md` remains the primary incremental context source.
`PROJECT_BASELINE.md` remains the stable architecture map.

#### When to regenerate the XML snapshot

Do NOT regenerate the broad XML code snapshot after every code change.

Regenerate or replace it only when one or more of these conditions are true:

- A major architecture or navigation structure changed.
- Important classes, functions, providers, routes, services, or files were added, removed, renamed, or moved.
- A new subsystem or major feature area was introduced.
- A cross-cutting refactor materially changed several related modules.
- The current XML snapshot would cause another AI to reason from materially stale implementation.
- The user explicitly requests a fresh full-project snapshot.

Do NOT regenerate it for ordinary isolated changes such as:

- Small bug fixes.
- Copy/text changes.
- Styling-only changes.
- Small animation tuning.
- One-file implementation changes already sufficiently described in `FLOWY_HANDOFF.md`.
- Formatting-only diffs.

#### Snapshot status in FLOWY_HANDOFF.md

After every meaningful coding task, Codex must record the snapshot status in `Flowy/FLOWY_HANDOFF.md`.

Use exactly one of:

`Code snapshot: FRESH`

or

`Code snapshot: STALE`

If STALE, include a short reason.

Example:

```text
Code snapshot: STALE
Reason:
- N3.4 changed navigation implementation after snapshot generation.
- Use handoff/diff for current state.
```

#### Metadata required after generating a fresh snapshot

Whenever Codex generates or replaces the broad XML code snapshot in `Flowy/code/`, `FLOWY_HANDOFF.md` must record:

- Code snapshot: FRESH
- Snapshot path
- Generation time
- Branch
- HEAD commit/hash
- Whether uncommitted working-tree changes are included
- Which task/change the snapshot was generated after

Example:

```text
Code snapshot: FRESH
Snapshot: Flowy/code/ (broad XML snapshot)
Generated at: 2026-10-06 16:50 +07
Branch: main
HEAD: 3b8fe42...
Includes working tree: YES
Generated after: N3R
```

### Delta-first context rule

The default AI workflow must be delta-first.

For normal continuation:

1. Read `PROJECT_BASELINE.md`.
2. Read `FLOWY_HANDOFF.md`.
3. If implementation detail is required, inspect the smallest sufficient context:
   - Task-specific diff/patch.
   - Specific changed file(s).
   - Specific symbol/function/class.
4. Use the broad XML code snapshot only when broader implementation context is actually needed.

Do not require another AI to reread the whole repository merely because a small task changed a limited part of the codebase.

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
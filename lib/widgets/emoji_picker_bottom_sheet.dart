// ==============================================================================
// File: lib/widgets/emoji_picker_bottom_sheet.dart
// Architecture: Full-Featured Theme-Adaptive Emoji Picker Modal BottomSheet
// Stack: flutter, emoji_picker_flutter (v4.5+)
// Features: Dynamic Dark/Light Theme Adapting, Drag Handle Header,
//           Built-in Keyword Search View, Curated Category Tabs,
//           Instant Selection Click Haptic Feedback & Return
// ==============================================================================

import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hàm tiện ích mở Modal BottomSheet chọn Emoji toàn năng
Future<String?> showAppEmojiPicker(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final sheetHeight = MediaQuery.of(context).size.height * 0.58;

  return AppAnimationPolicy.showFluidSheet<String>(
    context: context,
    mode: FluidSheetMode.nestedScrollable,
    backgroundColor: Colors.transparent,
    builder: (ctx, __) {
      return AppFeedbackDismissRegion(
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Container(
            height: sheetHeight,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151C28) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // Drag Handle Bar
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Tiêu đề & Nút đóng
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kho Biểu Tượng Emoji',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: isDark ? Colors.white70 : Colors.black54,
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, thickness: 0.5),

                  // Trình chọn Emoji
                  Expanded(
                    child: EmojiPicker(
                      onEmojiSelected: (category, emoji) {
                        HapticFeedback.selectionClick();
                        Navigator.of(ctx).pop(emoji.emoji);
                      },
                      config: Config(
                        height: 256,
                        checkPlatformCompatibility: true,
                        emojiViewConfig: EmojiViewConfig(
                          columns: 7,
                          emojiSizeMax: 28 * (defaultTargetPlatform == TargetPlatform.iOS ? 1.20 : 1.0),
                          backgroundColor: isDark ? const Color(0xFF151C28) : Colors.white,
                          loadingIndicator: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        categoryViewConfig: CategoryViewConfig(
                          backgroundColor: isDark ? const Color(0xFF111722) : const Color(0xFFF1F5F9),
                          indicatorColor: const Color(0xFF10B981),
                          iconColor: isDark ? Colors.white54 : Colors.black45,
                          iconColorSelected: const Color(0xFF10B981),
                          backspaceColor: const Color(0xFF10B981),
                          tabIndicatorAnimDuration: kTabScrollDuration,
                        ),
                        searchViewConfig: SearchViewConfig(
                          backgroundColor: isDark ? const Color(0xFF151C28) : Colors.white,
                          buttonIconColor: isDark ? Colors.white70 : Colors.black87,
                          hintText: 'Tìm kiếm biểu tượng...',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
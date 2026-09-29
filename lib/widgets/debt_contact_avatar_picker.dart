// ==============================================================================
// File: lib/widgets/debt_contact_avatar_picker.dart
// Architecture: Independent Debt Contact Avatar & Identification Swatch Picker
// Stack: flutter (Flutter 3.24+, Dart 3.5+)
// Features: 3-Tier Layered Design:
//           Tier 1: 68x68 dp Live Preview Squircle (Dynamic Initials vs Emoji)
//           Tier 2: 7 Curated Theme-Safe Color Palette Swatches with Active Ring
//           Tier 3: Curated Icons Bar (Quick [Abc] toggle, 8 Contextual Entity Emojis,
//                   and [😊▾] Launching Full-Fledged showAppEmojiPicker)
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/feedback/app_feedback.dart';

import 'emoji_picker_bottom_sheet.dart';
import 'icon_color_picker_sheet.dart';
import '../theme/app_icons.dart';

typedef OnAvatarChanged = void Function({
required String avatarType, // 'INITIALS' | 'EMOJI'
required String avatarValue, // Emoji character or empty
required String colorHex, // Hex color code (e.g. '#10B981')
});

class DebtContactAvatarPicker extends StatelessWidget {
  final String avatarType;
  final String avatarValue;
  final String colorHex;
  final String contactName;
  final OnAvatarChanged onChanged;

  const DebtContactAvatarPicker({
    super.key,
    required this.avatarType,
    required this.avatarValue,
    required this.colorHex,
    required this.contactName,
    required this.onChanged,
  });

  static const List<Map<String, String>> colorSwatches = [
    {'hex': '#10B981', 'name': 'Xanh ngọc'},
    {'hex': '#3B82F6', 'name': 'Xanh dương pastel'},
    {'hex': '#06B6D4', 'name': 'Xanh da trời'},
    {'hex': '#F59E0B', 'name': 'Vàng nghệ'},
    {'hex': '#F43F5E', 'name': 'Đỏ san hô'},
    {'hex': '#8B5CF6', 'name': 'Tím thạch anh'},
    {'hex': '#64748B', 'name': 'Xám titan'},
  ];

  static const List<String> curatedEmojis = [
    '👤', // Bạn bè
    '🧑💻', // Đồng nghiệp
    '👩', // Cá nhân / Nữ
    '🏠', // Gia đình / Tiền trọ
    '💼', // Sếp / Công ty
    '🎓', // Bạn học / Học phí
    '🏦', // Ngân hàng / Tín dụng
    '🏪', // Chủ nợ / Cửa hàng
  ];

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  String _extractInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  Future<void> _openFullEmojiPicker(BuildContext context) async {
    HapticFeedback.selectionClick();
    final selectedEmoji = await showAppEmojiPicker(context);
    if (selectedEmoji != null && selectedEmoji.isNotEmpty) {
      onChanged(
        avatarType: 'EMOJI',
        avatarValue: selectedEmoji,
        colorHex: colorHex,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = _parseColor(colorHex);
    final isInitials = avatarType == 'INITIALS';

    return AppFeedbackDismissRegion(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // =====================================================================
          // TẦNG 1: KHUNG XEM TRƯỚC TRỰC TIẾP (LIVE PREVIEW BOX)
          // =====================================================================
          Center(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                // Chạm vào khung xem trước để reset về chế độ Chữ cái đầu
                onChanged(
                  avatarType: 'INITIALS',
                  avatarValue: '',
                  colorHex: colorHex,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: isDark ? 0.24 : 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: primaryColor,
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: avatarType == 'ICON'
                      ? Icon(AppIcons.resolve(avatarValue), size: 30, color: primaryColor)
                      : isInitials
                      ? Text(
                    _extractInitials(contactName),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                    ),
                  )
                      : Text(
                    avatarValue.isNotEmpty ? avatarValue : '👤',
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // =====================================================================
          // TẦNG 2: DẢI MÀU NHẬN DIỆN (COLOR PALETTE SWATCHES)
          // =====================================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: colorSwatches.map((item) {
              final hex = item['hex']!;
              final swatchColor = _parseColor(hex);
              final isSelected = colorHex.toUpperCase() == hex.toUpperCase();

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5.0),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(
                      avatarType: avatarType,
                      avatarValue: avatarValue,
                      colorHex: hex,
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: swatchColor,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                        color: isDark ? Colors.white : Colors.black,
                        width: 2.5,
                      )
                          : Border.all(
                        color: Colors.transparent,
                        width: 2.0,
                      ),
                      boxShadow: isSelected
                          ? [
                        BoxShadow(
                          color: swatchColor.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                          : null,
                    ),
                    child: isSelected
                        ? const Center(
                      child: Icon(Icons.check_rounded, size: 16, color: Colors.white),
                    )
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // =====================================================================
          // TẦNG 3: DẢI GỢI Ý BIỂU TƯỢNG & MỞ RỘNG (CURATED ICONS BAR)
          // =====================================================================
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // Nút [ Abc ] (Chữ cái đầu)
                InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(
                      avatarType: 'INITIALS',
                      avatarValue: '',
                      colorHex: colorHex,
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isInitials
                          ? primaryColor.withValues(alpha: 0.2)
                          : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isInitials ? primaryColor : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.text_fields_rounded,
                          size: 15,
                          color: isInitials ? primaryColor : (isDark ? Colors.white70 : Colors.black54),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Abc',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isInitials ? FontWeight.w800 : FontWeight.w600,
                            color: isInitials ? primaryColor : (isDark ? Colors.white70 : Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                TextButton.icon(
                  onPressed: () async {
                    final result = await IconColorPickerSheet.show(context,
                      initialIconName: avatarType == 'ICON' ? avatarValue : 'person',
                      initialHexColor: colorHex,
                      title: 'Biểu tượng đối tác',
                      confirmLabel: 'Áp dụng cho đối tác');
                    if (!context.mounted || result == null) return;
                    onChanged(avatarType: 'ICON', avatarValue: result.iconName, colorHex: result.hexColor);
                  },
                  icon: const Icon(Icons.category_rounded, size: 18),
                  label: const Text('Biểu tượng'),
                ),

                // 8 Emoji Ngữ Cảnh Nhanh
                ...curatedEmojis.map((em) {
                  final isSelected = avatarType == 'EMOJI' && avatarValue == em;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onChanged(
                          avatarType: 'EMOJI',
                          avatarValue: em,
                          colorHex: colorHex,
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor.withValues(alpha: 0.2)
                              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? primaryColor : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Text(em, style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                  );
                }),

                // Nút mở rộng [ 😊▾ ] kết nối với emoji_picker_flutter
                InkWell(
                  onTap: () => _openFullEmojiPicker(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('😊', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 16,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

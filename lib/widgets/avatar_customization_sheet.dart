// ==============================================================================
// File: lib/widgets/avatar_customization_sheet.dart
// Architecture: Independent User Avatar Customization Sheet (Phase 2)
// Stack: flutter, flutter_riverpod, image_picker
// Features:
// 1. Live Squircle Preview (80x80) with dynamic background colors & shapes
// 2. 4-Tier Customization Segments:
//    - Tab 0: [ Đồng bộ Google ] (High-res =s256-c OAuth sync with fallback prompt)
//    - Tab 1: [ Thư viện ảnh ] (Picks local device image via ImagePicker)
//    - Tab 2: [ Mascot / Emoji ] (8 Financial Mascots x 8 Squircle Color Palettes)
//    - Tab 3: [ Ký tự Initials ] (Single/Double letter generator x Accent Colors)
// 3. Seamless Dark/Light Design Token compliance with Fluid Sheet Engine
// 4. Safe failure recovery & instant reactive sync via userProfileNotifierProvider
// ==============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'sliding_segmented_bar.dart';
import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import '../services/auth_profile_service.dart';
import '../theme/app_theme.dart';

class AvatarCustomizationSheet extends ConsumerStatefulWidget {
  const AvatarCustomizationSheet({super.key});

  /// Static helper mở Modal BottomSheet từ bất kỳ màn hình nào
  static Future<void> show(BuildContext context) {
    HapticFeedback.selectionClick();
    return AppAnimationPolicy.showFluidSheet<void>(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      backgroundColor: Colors.transparent,
      builder: (_, __) => const AvatarCustomizationSheet(),
    );
  }

  @override
  ConsumerState<AvatarCustomizationSheet> createState() =>
      _AvatarCustomizationSheetState();
}

class _AvatarCustomizationSheetState
    extends ConsumerState<AvatarCustomizationSheet> {
  late UserAvatarType _selectedType;
  late String _avatarValue;
  late String _selectedColorHex;
  int _selectedTabIndex = 0;
  bool _isPickingImage = false;
  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();

  // 8 Mascot / Emoji mang phong cách tài chính & bảo mật
  static const List<String> _kMascotEmojis = [
    '🛡️',
    '🦊',
    '🦉',
    '⚡',
    '💎',
    '🚀',
    '💰',
    '🎯',
  ];

  // 8 Mã màu Squircle Palette cao cấp
  static const List<String> _kColorSwatches = [
    '#10B981', // Emerald
    '#0EA5E9', // Ocean
    '#6366F1', // Indigo
    '#F59E0B', // Amber
    '#F43F5E', // Rose
    '#8B5CF6', // Purple
    '#14B8A6', // Teal
    '#64748B', // Slate
  ];

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentUserProfileProvider);
    _selectedType = profile.avatarType;
    _avatarValue = profile.avatarValue;
    _selectedColorHex = profile.avatarColorHex;

    switch (_selectedType) {
      case UserAvatarType.google:
        _selectedTabIndex = 0;
        break;
      case UserAvatarType.customImage:
        _selectedTabIndex = 1;
        break;
      case UserAvatarType.emoji:
        _selectedTabIndex = 2;
        break;
      case UserAvatarType.initials:
        _selectedTabIndex = 3;
        break;
    }
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  Future<void> _pickImageFromGallery() async {
    HapticFeedback.selectionClick();
    setState(() => _isPickingImage = true);

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        setState(() {
          _selectedType = UserAvatarType.customImage;
          _avatarValue = image.path;
          _selectedTabIndex = 1;
        });
      }
    } catch (e) {
      debugPrint('AvatarCustomizationSheet: Error picking image: $e');
      if (mounted) {
        AppFeedback.showError(
          context,
          'Không thể chọn ảnh từ thư viện thiết bị.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  Future<void> _saveAvatarChanges() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      await ref.read(userProfileNotifierProvider.notifier).updateCustomAvatar(
        type: _selectedType,
        value: _avatarValue,
        colorHex: _selectedColorHex,
      );

      if (mounted) {
        AppFeedback.showSuccess(
          context,
          '✓ Đã cập nhật ảnh đại diện thành công!',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(
          context,
          'Lỗi lưu ảnh đại diện: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildLiveAvatarPreview(UserProfile profile) {
    final color = _parseColor(_selectedColorHex);

    switch (_selectedType) {
      case UserAvatarType.google:
        if (profile.isSignedIn && _avatarValue.startsWith('http')) {
          return Image.network(
            _avatarValue,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackInitials(profile, color),
          );
        }
        return _buildFallbackInitials(profile, color);

      case UserAvatarType.customImage:
        final file = File(_avatarValue);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackInitials(profile, color),
          );
        }
        return _buildFallbackInitials(profile, color);

      case UserAvatarType.emoji:
        return Center(
          child: Text(
            _avatarValue,
            style: const TextStyle(fontSize: 36),
          ),
        );

      case UserAvatarType.initials:
      default:
        return Center(
          child: Text(
            _avatarValue.isNotEmpty ? _avatarValue : 'K',
            style: TextStyle(
              fontSize: _avatarValue.length > 1 ? 26 : 30,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              color: color,
            ),
          ),
        );
    }
  }

  Widget _buildFallbackInitials(UserProfile profile, Color color) {
    final char = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()[0].toUpperCase()
        : 'K';
    return Center(
      child: Text(
        char,
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);
    final profile = ref.watch(currentUserProfileProvider);

    return AppFeedbackDismissRegion(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151C28) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Thanh Drag Handle
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tiêu đề Sheet
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tùy Biến Ảnh Đại Diện',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppTokens.darkText : AppTokens.lightText,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // =========================================================
                  // KHU VỰC PREVIEW TRỰC TIẾP (SQUIRCLE 80x80)
                  // =========================================================
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _parseColor(_selectedColorHex).withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _parseColor(_selectedColorHex),
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _parseColor(_selectedColorHex)
                              .withValues(alpha: isDark ? 0.35 : 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: _buildLiveAvatarPreview(profile),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Tên & Email người dùng
                  Text(
                    profile.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppTokens.darkText : AppTokens.lightText,
                    ),
                  ),
                  if (profile.email != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      profile.email!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // =========================================================
                  // SEGMENTED SWITCHER 4 TABS
                  // =========================================================
                  SlidingSegmentedBar<int>(
                    height: 44,
                    fontSize: 11,
                    selectedValue: _selectedTabIndex,
                    onValueChanged: (index) {
                      setState(() {
                        _selectedTabIndex = index;
                        if (index == 2 && _selectedType != UserAvatarType.emoji) {
                          _selectedType = UserAvatarType.emoji;
                          _avatarValue = _kMascotEmojis.first;
                        } else if (index == 3 && _selectedType != UserAvatarType.initials) {
                          _selectedType = UserAvatarType.initials;
                          final name = ref.read(currentUserProfileProvider).displayName;
                          _avatarValue = name.isNotEmpty ? name[0].toUpperCase() : 'K';
                        }
                      });
                    },
                    items: const [
                      SlidingSegmentedItem<int>(
                        value: 0,
                        label: 'Google',
                        icon: Icons.g_mobiledata_rounded,
                      ),
                      SlidingSegmentedItem<int>(
                        value: 1,
                        label: 'Bộ sưu tập',
                        icon: Icons.photo_library_outlined,
                      ),
                      SlidingSegmentedItem<int>(
                        value: 2,
                        label: 'Mascot',
                        icon: Icons.emoji_emotions_outlined,
                      ),
                      SlidingSegmentedItem<int>(
                        value: 3,
                        label: 'Ký tự',
                        icon: Icons.text_fields_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // =========================================================
                  // NỘI DUNG TỪNG TAB
                  // =========================================================
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _buildActiveTabContent(profile, isDark, accent),
                  ),
                  const SizedBox(height: 20),

                  // =========================================================
                  // DẢI MÃ MÀU NỀN SQUIRCLE PALETTE (8 MÃ MÀU)
                  // =========================================================
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Màu nền nhận diện:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _kColorSwatches.map((hex) {
                        final isSelected =
                            _selectedColorHex.toLowerCase() == hex.toLowerCase();
                        final color = _parseColor(hex);

                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedColorHex = hex);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 3.0)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.6),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 16)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // =========================================================
                  // NÚT LƯU THAY ĐỔI
                  // =========================================================
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent.primary,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _isSaving ? null : _saveAvatarChanges,
                      child: _isSaving
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Text(
                        '✓ LƯU THAY ĐỔI',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(
      UserProfile profile,
      bool isDark,
      AppAccentPreset accent,
      ) {
    switch (_selectedTabIndex) {
    // TAB 0: ĐỒNG BỘ GOOGLE
      case 0:
        return Container(
          key: const ValueKey('tab_google_sync'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
            ),
          ),
          child: profile.isSignedIn
              ? Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.primary, width: 1.5),
                ),
                child: ClipOval(
                  child: profile.avatarValue.startsWith('http')
                      ? Image.network(
                    profile.avatarValue,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.account_circle,
                        size: 28),
                  )
                      : const Icon(Icons.account_circle, size: 28),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ảnh đại diện tài khoản Google',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppTokens.darkText
                            : AppTokens.lightText,
                      ),
                    ),
                    Text(
                      'Chất lượng phân giải cao =s256-c',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTokens.darkMuted
                            : AppTokens.lightMuted,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent.primary.withValues(alpha: 0.15),
                  foregroundColor: accent.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedType = UserAvatarType.google;
                    _avatarValue = profile.avatarValue;
                  });
                },
                child: const Text('Áp dụng',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          )
              : Column(
            children: [
              const Icon(Icons.cloud_sync_outlined,
                  size: 32, color: Colors.amber),
              const SizedBox(height: 6),
              Text(
                'Chưa kết nối tài khoản Google',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTokens.darkText : AppTokens.lightText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Đăng nhập tài khoản Google để tự động đồng bộ ảnh hồ sơ.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent.primary,
                  side: BorderSide(
                      color: accent.primary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  try {
                    await ref
                        .read(userProfileNotifierProvider.notifier)
                        .signInWithGoogle();
                    if (mounted) {
                      final updated =
                      ref.read(currentUserProfileProvider);
                      setState(() {
                        _selectedType = UserAvatarType.google;
                        _avatarValue = updated.avatarValue;
                      });
                    }
                  } catch (_) {}
                },
                icon: const Icon(Icons.login_rounded, size: 16),
                label: const Text('Đăng nhập Google ngay',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

    // TAB 1: BỘ SƯU TẬP ẢNH MÁY
      case 1:
        return Container(
          key: const ValueKey('tab_custom_gallery'),
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  size: 34, color: accent.primary),
              const SizedBox(height: 6),
              Text(
                'Tải ảnh từ điện thoại',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTokens.darkText : AppTokens.lightText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Hỗ trợ định dạng JPG, PNG, WEBP (Lưu an toàn trên máy).',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: _isPickingImage ? null : _pickImageFromGallery,
                icon: const Icon(Icons.photo_library_rounded, size: 16),
                label: Text(
                  _isPickingImage ? 'Đang mở...' : 'Chọn ảnh từ thư viện',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );

    // TAB 2: MASCOT / EMOJI
      case 2:
        return Container(
          key: const ValueKey('tab_mascot_grid'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Biểu tượng linh vật may mắn:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: _kMascotEmojis.map((emoji) {
                  final isSelected = _selectedType == UserAvatarType.emoji &&
                      _avatarValue == emoji;
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedType = UserAvatarType.emoji;
                        _avatarValue = emoji;
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accent.primary.withValues(alpha: 0.2)
                            : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? accent.primary : Colors.transparent,
                          width: 2.0,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );

    // TAB 3: KÝ TỰ INITIALS
      case 3:
      default:
        final name = profile.displayName.trim();
        final firstChar = name.isNotEmpty ? name[0].toUpperCase() : 'K';
        final secondChar = name.contains(' ')
            ? name.split(' ').last[0].toUpperCase()
            : (name.length > 1 ? name[1].toUpperCase() : '');

        return Container(
          key: const ValueKey('tab_initials_style'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mẫu chữ cái viết tắt:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildInitialsChip(firstChar, '1 Ký tự ($firstChar)', isDark, accent),
                  if (secondChar.isNotEmpty) ...[
                    const SizedBox(width: 14),
                    _buildInitialsChip(
                      '$firstChar$secondChar',
                      '2 Ký tự ($firstChar$secondChar)',
                      isDark,
                      accent,
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
    }
  }

  Widget _buildInitialsChip(
      String val,
      String label,
      bool isDark,
      AppAccentPreset accent,
      ) {
    final isSelected =
        _selectedType == UserAvatarType.initials && _avatarValue == val;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedType = UserAvatarType.initials;
          _avatarValue = val;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.primary.withValues(alpha: 0.16)
              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? accent.primary : Colors.transparent,
            width: 1.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              val,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                color: isSelected
                    ? accent.primary
                    : (isDark ? AppTokens.darkText : AppTokens.lightText),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? accent.primary
                    : (isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

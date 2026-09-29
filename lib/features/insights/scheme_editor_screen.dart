import '../../theme/app_icons.dart';
import '../../widgets/flowy_selection_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/feedback/app_feedback.dart';
import '../../data/database.dart';
import 'insights_data.dart';

class SchemeEditorScreen extends ConsumerStatefulWidget {
  final ClassificationScheme? scheme;
  final List<Category> categories;
  const SchemeEditorScreen({super.key, this.scheme, required this.categories});
  @override
  ConsumerState<SchemeEditorScreen> createState() => _SchemeEditorScreenState();
}

class _SchemeEditorScreenState extends ConsumerState<SchemeEditorScreen> {
  late final TextEditingController _name;
  late final String _id;
  late List<ClassificationGroup> _groups;
  late Map<String, String> _assignments;
  final _feedback = AppValidationFeedbackController();
  bool _mapping = false, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _id =
        widget.scheme?.id ?? 'scheme_${DateTime.now().microsecondsSinceEpoch}';
    _name = TextEditingController(text: widget.scheme?.name ?? '');
    _groups = [...?widget.scheme?.groups];
    _assignments = {...?widget.scheme?.assignments};
  }

  @override
  void dispose() {
    _name.dispose();
    _feedback.dispose();
    super.dispose();
  }

  void _invalid(String text) {
    setState(() => _error = text);
    _feedback.reject();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(classificationSchemesProvider.notifier).save(
          ClassificationScheme(
              id: _id,
              name: _name.text.trim(),
              groups: _groups,
              assignments: _assignments,
              isSystemPreset: widget.scheme?.isSystemPreset ?? false));
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.pop(context, _id);
    } catch (error) {
      debugPrint('Scheme save failed: $error');
      if (mounted) _invalid('Chưa lưu được góc nhìn. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = [...widget.categories]
      ..sort((a, b) => a.name.compareTo(b.name));
    return Scaffold(
      appBar: AppBar(
          title: Text(_mapping ? 'Gán danh mục' : 'Tạo góc nhìn mới'),
          leading: BackButton(onPressed: () {
            if (_saving) return;
            if (_mapping) {
              setState(() => _mapping = false);
            } else {
              Navigator.pop(context);
            }
          })),
      body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
        if (!_mapping) ...[
          AppValidationFeedback(
              controller: _feedback,
              builder: (context, visual) => TextField(
                  controller: _name,
                  maxLength: 60,
                  decoration:
                      const InputDecoration(labelText: 'Tên góc nhìn'))),
          const SizedBox(height: 20),
          const Text('Các nhóm',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (var i = 0; i < _groups.length; i++)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(children: [
                  Row(children: [
                    Icon(Icons.circle,
                        color: Color(_groups[i].color), size: 14),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextFormField(
                            key: ValueKey(_groups[i].id),
                            initialValue: _groups[i].name,
                            maxLength: 40,
                            decoration: InputDecoration(
                                labelText: 'Nhóm ${i + 1}', counterText: ''),
                            onChanged: (value) {
                              _groups[i] = ClassificationGroup(
                                  _groups[i].id, value, _groups[i].color);
                            })),
                    IconButton(
                        tooltip: 'Xóa nhóm (danh mục sẽ chưa phân loại)',
                        onPressed: () => setState(() {
                              final id = _groups.removeAt(i).id;
                              _assignments
                                  .removeWhere((key, value) => value == id);
                            }),
                        icon: const Icon(Icons.close_rounded)),
                  ]),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    IconButton(
                        tooltip: 'Chuyển lên',
                        onPressed: i == 0
                            ? null
                            : () => setState(() {
                                  final group = _groups.removeAt(i);
                                  _groups.insert(i - 1, group);
                                }),
                        icon: const Icon(Icons.arrow_upward_rounded, size: 18)),
                    IconButton(
                        tooltip: 'Chuyển xuống',
                        onPressed: i == _groups.length - 1
                            ? null
                            : () => setState(() {
                                  final group = _groups.removeAt(i);
                                  _groups.insert(i + 1, group);
                                }),
                        icon:
                            const Icon(Icons.arrow_downward_rounded, size: 18)),
                  ]),
                ])),
          TextButton.icon(
              onPressed: () => setState(() {
                    _groups.add(ClassificationGroup(
                        'group_${DateTime.now().microsecondsSinceEpoch}',
                        '',
                        insightsColors[
                            _groups.length % insightsColors.length]));
                  }),
              icon: const Icon(Icons.add),
              label: const Text('Thêm nhóm')),
          if (_error != null)
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          FilledButton(
              onPressed: () {
                if (_name.text.trim().isEmpty ||
                    _groups.isEmpty ||
                    _groups.any((g) => g.name.trim().isEmpty)) {
                  _invalid('Nhập tên góc nhìn và tên của ít nhất một nhóm.');
                  return;
                }
                if (_groups
                        .map((g) => g.name.trim().toLowerCase())
                        .toSet()
                        .length !=
                    _groups.length) {
                  _invalid('Tên các nhóm cần khác nhau.');
                  return;
                }
                setState(() {
                  _mapping = true;
                  _error = null;
                });
              },
              child: const Text('Tiếp tục')),
        ] else ...[
          const Text(
              'Mỗi danh mục thuộc tối đa một nhóm. Bạn có thể để trống và phân loại sau.'),
          const SizedBox(height: 12),
          for (final category in categories)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FlowyDropdown<String>(
                  title: 'Phân loại chi tiêu',
                  initialValue: _assignments[category.id] ?? '',
                  isExpanded: true,
                  decoration: InputDecoration(
                      labelText: category.name,
                      prefixIcon: Icon(AppIcons.resolve(category.icon))),
                  items: [
                    const DropdownMenuItem(
                        value: '', child: Text('Chưa phân loại')),
                    ..._groups.map((g) =>
                        DropdownMenuItem(value: g.id, child: Text(g.name)))
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                            if (value == null || value.isEmpty) {
                              _assignments.remove(category.id);
                            } else {
                              _assignments[category.id] = value;
                            }
                          }),
                )),
          if (_error != null)
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Đang lưu…' : 'Hoàn tất')),
          TextButton(
              onPressed: _saving ? null : _save,
              child: const Text('Bỏ qua các danh mục còn trống')),
        ],
      ])),
    );
  }
}

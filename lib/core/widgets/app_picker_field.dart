import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// حقل اختيار من قائمة (مع بحث) — يُستخدم لأنواع الطائرات وفصول ATA والصفحات الأصل.
///
/// اعتمدناه بدل القوائم المنسدلة الجاهزة لأنه:
///  • يعمل بنفس السلوك على كل إصدارات Flutter دون APIs مُهملة.
///  • يسمح بالبحث داخل عشرات الخيارات (39 فصل ATA مثلًا).
///  • يدعم المسح (اختيار «بدون») بشكل صريح.
class AppPickerField<T> extends StatefulWidget {
  const AppPickerField({
    super.key,
    required this.label,
    required this.options,
    required this.optionLabel,
    required this.onSelected,
    this.value,
    this.hint,
    this.helperText,
    this.searchHint,
    this.clearLabel,
    this.prefixIcon,
    this.enabled = true,
    this.sheetTitle,
  });

  final String label;
  final List<T> options;
  final String Function(T option) optionLabel;
  final ValueChanged<T?> onSelected;
  final T? value;
  final String? hint;
  final String? helperText;
  final String? searchHint;
  final String? clearLabel;
  final IconData? prefixIcon;
  final bool enabled;
  final String? sheetTitle;

  @override
  State<AppPickerField<T>> createState() => _AppPickerFieldState<T>();
}

class _AppPickerFieldState<T> extends State<AppPickerField<T>> {
  late final TextEditingController _controller =
      TextEditingController(text: _displayText);

  String get _displayText => widget.value == null
      ? ''
      : widget.optionLabel(widget.value as T);

  @override
  void didUpdateWidget(covariant AppPickerField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String text = _displayText;
    if (_controller.text != text) {
      _controller.text = text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final Object? selected = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) => _PickerSheet<T>(
        title: widget.sheetTitle ?? widget.label,
        options: widget.options,
        optionLabel: widget.optionLabel,
        current: widget.value,
        searchHint: widget.searchHint,
        clearLabel: widget.clearLabel,
      ),
    );

    // إغلاق الورقة بلا اختيار (سحب/ضغط خارجها) لا يغيّر القيمة الحالية.
    if (selected == null) {
      return;
    }
    if (selected is _ClearSelection) {
      widget.onSelected(null);
      return;
    }
    if (selected is T) {
      widget.onSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      readOnly: true,
      enabled: widget.enabled,
      onTap: widget.enabled ? _open : null,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helperText,
        helperMaxLines: 2,
        prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
        suffixIcon: const Icon(Icons.expand_more_rounded),
      ),
    );
  }
}

/// قيمة خاصة تعني «امسح الاختيار» — نُميّزها عن إغلاق الورقة دون اختيار
/// حتى لا يُمسح الاختيار الحالي عند السحب لأسفل أو الضغط خارج الورقة.
class _ClearSelection {
  const _ClearSelection();
}

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.optionLabel,
    required this.current,
    this.searchHint,
    this.clearLabel,
  });

  final String title;
  final List<T> options;
  final String Function(T option) optionLabel;
  final T? current;
  final String? searchHint;
  final String? clearLabel;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  late List<T> _filtered;
  final TextEditingController _searchController = TextEditingController();
  bool _withSearch = false;

  @override
  void initState() {
    super.initState();
    _filtered = widget.options;
    _withSearch = widget.options.length > 8;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final String needle = query.trim().toLowerCase();
    setState(() {
      if (needle.isEmpty) {
        _filtered = widget.options;
      } else {
        _filtered = widget.options
            .where((T option) =>
                widget.optionLabel(option).toLowerCase().contains(needle))
            .toList(growable: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppL10n l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                widget.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_withSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filter,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: widget.searchHint ?? l10n.commonSearch,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _filtered.length + (widget.clearLabel == null ? 0 : 1),
                separatorBuilder: (BuildContext context, int index) =>
                    const Divider(height: 1),
                itemBuilder: (BuildContext context, int index) {
                  if (widget.clearLabel != null && index == 0) {
                    return ListTile(
                      leading: const Icon(Icons.close_rounded),
                      title: Text(widget.clearLabel!),
                      onTap: () =>
                          Navigator.of(context).pop(const _ClearSelection()),
                    );
                  }
                  final int optionIndex =
                      widget.clearLabel == null ? index : index - 1;
                  final T option = _filtered[optionIndex];
                  final bool isSelected = option == widget.current;
                  return ListTile(
                    title: Text(widget.optionLabel(option)),
                    trailing: isSelected
                        ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                        : null,
                    selected: isSelected,
                    onTap: () => Navigator.of(context).pop(option),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

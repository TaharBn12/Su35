import 'package:flutter/material.dart';

/// اختيار رمز (إيموجي) من قائمة جاهزة — يُستخدم في الدفاتر والصفحات.
class AppIconPicker extends StatelessWidget {
  const AppIconPicker({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((String icon) {
        final bool isSelected = icon == selected;
        return InkWell(
          onTap: () => onChanged(icon),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 20)),
          ),
        );
      }).toList(),
    );
  }
}

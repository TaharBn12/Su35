import 'package:flutter/material.dart';

import '../constants/aviation_data.dart';

/// اختيار لون من لوحة محدّدة (تُخزَّن كقيمة HEX في قاعدة البيانات).
class AppColorPicker extends StatelessWidget {
  const AppColorPicker({
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
      spacing: 10,
      runSpacing: 10,
      children: options.map((String hex) {
        final Color color = AviationData.colorFromHex(hex);
        final bool isSelected = hex.toUpperCase() == (selected ?? '').toUpperCase();
        return InkWell(
          onTap: () => onChanged(hex),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.outlineVariant,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

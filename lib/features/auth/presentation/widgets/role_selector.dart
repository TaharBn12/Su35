import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../domain/user_role.dart';

/// تسمية الصفة المهنية حسب لغة الواجهة.
String roleLabel(UserRole role, AppL10n l10n) {
  if (role == UserRole.pilot) {
    return l10n.rolePilot;
  }
  if (role == UserRole.engineer) {
    return l10n.roleEngineer;
  }
  if (role == UserRole.student) {
    return l10n.roleStudent;
  }
  if (role == UserRole.instructor) {
    return l10n.roleInstructor;
  }
  return l10n.roleOther;
}

/// اختيار الصفة المهنية (تُستخدم في إنشاء الحساب وفي الإعدادات).
class RoleSelector extends StatelessWidget {
  const RoleSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final UserRole selected;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppL10n l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: UserRole.values.map((UserRole role) {
        return ChoiceChip(
          label: Text(roleLabel(role, l10n)),
          selected: role == selected,
          onSelected: (bool isSelected) {
            if (isSelected) {
              onChanged(role);
            }
          },
        );
      }).toList(),
    );
  }
}

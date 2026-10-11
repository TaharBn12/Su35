import 'package:flutter/material.dart';

import '../../../../core/constants/aviation_data.dart';
import '../../../../core/utils/app_date.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/note_page.dart';

/// شرائح معلومات الطيران لصفحة: النوع، التسجيل، فصل ATA، المطار، التاريخ.
class AviationMetaChips extends StatelessWidget {
  const AviationMetaChips({
    super.key,
    required this.page,
    this.showEmptyLabel = false,
    this.wrap = true,
  });

  final NotePage page;

  /// عند عدم وجود أي حقل جوي يُعرض «غير محدد».
  final bool showEmptyLabel;

  /// true: Wrap (داخل البطاقات) — false: Row أفقي قابل للتمرير (داخل القوائم).
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final AppL10n l10n = context.l10n;
    final bool isArabic = context.isArabic;

    final List<Widget> chips = <Widget>[
      if ((page.aircraftType ?? '').trim().isNotEmpty)
        _Chip(
          icon: Icons.flight_rounded,
          label: page.aircraftType!.trim(),
        ),
      if ((page.tailNumber ?? '').trim().isNotEmpty)
        _Chip(
          icon: Icons.confirmation_number_outlined,
          label: page.tailNumber!.trim(),
        ),
      if ((page.ataChapter ?? '').trim().isNotEmpty)
        _Chip(
          icon: Icons.build_outlined,
          label: AviationData.ataLabel(page.ataChapter, arabic: isArabic),
        ),
      if ((page.airportIcao ?? '').trim().isNotEmpty)
        _Chip(
          icon: Icons.public_rounded,
          label: page.airportIcao!.trim(),
        ),
      if (page.flightDate != null)
        _Chip(
          icon: Icons.event_rounded,
          label: AppDate.display(page.flightDate!, arabic: isArabic),
        ),
    ];

    if (chips.isEmpty) {
      if (!showEmptyLabel) {
        return const SizedBox.shrink();
      }
      return _Chip(icon: Icons.remove_circle_outline, label: l10n.stateNotSet);
    }

    if (wrap) {
      return Wrap(spacing: 6, runSpacing: 4, children: chips);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (int index = 0; index < chips.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: 6),
            chips[index],
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

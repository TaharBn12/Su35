import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../domain/block.dart';
import '../../domain/block_content.dart';

/// مجموعات أنواع الكتل في ورقة «إضافة كتلة».
enum BlockTypeGroup { basic, media, advanced }

extension BlockTypeGroupX on BlockTypeGroup {
  List<BlockType> get types => switch (this) {
        BlockTypeGroup.basic => const <BlockType>[
            BlockType.text,
            BlockType.heading,
            BlockType.checklist,
            BlockType.table,
          ],
        BlockTypeGroup.media => const <BlockType>[
            BlockType.image,
            BlockType.pdf,
          ],
        BlockTypeGroup.advanced => const <BlockType>[
            BlockType.code,
            BlockType.quote,
            BlockType.callout,
            BlockType.divider,
          ],
      };

  String label(AppL10n l10n) => switch (this) {
        BlockTypeGroup.basic => l10n.blockTypeGroupBasic,
        BlockTypeGroup.media => l10n.blockTypeGroupMedia,
        BlockTypeGroup.advanced => l10n.blockTypeGroupAdvanced,
      };
}

/// اسم النوع بالعربية/الإنجليزية حسب لغة الواجهة.
String blockTypeLabel(BlockType type, AppL10n l10n) => switch (type) {
      BlockType.text => l10n.blockTypeText,
      BlockType.heading => l10n.blockTypeHeading,
      BlockType.checklist => l10n.blockTypeChecklist,
      BlockType.table => l10n.blockTypeTable,
      BlockType.image => l10n.blockTypeImage,
      BlockType.pdf => l10n.blockTypePdf,
      BlockType.code => l10n.blockTypeCode,
      BlockType.divider => l10n.blockTypeDivider,
      BlockType.quote => l10n.blockTypeQuote,
      BlockType.callout => l10n.blockTypeCallout,
    };

/// لون مميّز لكل نوع (يُستخدم في الشرائح وحدود الكتلة النشطة).
Color blockTypeColor(BlockType type) => switch (type) {
      BlockType.text => const Color(0xFF4FA3E3),
      BlockType.heading => const Color(0xFF0B3D91),
      BlockType.checklist => const Color(0xFF2E9E6B),
      BlockType.table => const Color(0xFF7A5AF8),
      BlockType.image => const Color(0xFFE07A5F),
      BlockType.pdf => const Color(0xFFC2185B),
      BlockType.code => const Color(0xFF455A64),
      BlockType.divider => const Color(0xFF90A4AE),
      BlockType.quote => const Color(0xFFF0A02A),
      BlockType.callout => const Color(0xFF0288D1),
    };

/// لون خلفية نبرة التنبيه (فاتح).
Color calloutToneBackground(CalloutTone tone) => switch (tone) {
      CalloutTone.info => const Color(0xFFE3F2FD),
      CalloutTone.warning => const Color(0xFFFFF3E0),
      CalloutTone.danger => const Color(0xFFFFEBEE),
    };

/// لون حدّ نبرة التنبيه.
Color calloutToneBorder(CalloutTone tone) => switch (tone) {
      CalloutTone.info => const Color(0xFF4FA3E3),
      CalloutTone.warning => const Color(0xFFF0A02A),
      CalloutTone.danger => const Color(0xFFC2185B),
    };

/// أيقونة نبرة التنبيه.
IconData calloutToneIcon(CalloutTone tone) => switch (tone) {
      CalloutTone.info => Icons.info_outline_rounded,
      CalloutTone.warning => Icons.warning_amber_rounded,
      CalloutTone.danger => Icons.dangerous_outlined,
    };

/// اسم نبرة التنبيه حسب لغة الواجهة.
String calloutToneLabel(CalloutTone tone, AppL10n l10n) => switch (tone) {
      CalloutTone.info => l10n.blockCalloutToneInfo,
      CalloutTone.warning => l10n.blockCalloutToneWarning,
      CalloutTone.danger => l10n.blockCalloutToneDanger,
    };

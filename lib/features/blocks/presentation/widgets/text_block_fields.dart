import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../domain/block.dart';
import '../../domain/block_content.dart';
import 'auto_saving_text_field.dart';
import 'block_style.dart';
import 'block_type_sheet.dart';

/// كتلة «عنوان» — نص + اختيار المستوى (1..3).
class HeadingBlockField extends StatelessWidget {
  const HeadingBlockField({
    super.key,
    required this.data,
    required this.onChanged,
  });

  final HeadingData data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  double get _fontSize => switch (data.level) {
        1 => 22,
        2 => 19,
        _ => 17,
      };

  @override
  Widget build(BuildContext context) {
    final AppL10n l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: AutoSavingTextField(
            value: data.text,
            hintText: l10n.blockHeadingHint,
            maxLines: 2,
            textStyle: theme.textTheme.titleLarge!.copyWith(
              fontSize: _fontSize,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
              height: 1.3,
            ),
            onChanged: (String value) =>
                onChanged(data.copyWith(text: value).toJson()),
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: l10n.blockHeadingLevel,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              final int? level = await showHeadingLevelSheet(context, data.level);
              if (level != null && level != data.level) {
                onChanged(data.copyWith(level: level).toJson());
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: blockTypeColor(BlockType.heading).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'H${data.level}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: blockTypeColor(BlockType.heading),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// كتلة «اقتباس».
class QuoteBlockField extends StatelessWidget {
  const QuoteBlockField({
    super.key,
    required this.data,
    required this.onChanged,
  });

  final QuoteData data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 12),
      decoration: const BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(color: Color(0xFFF0A02A), width: 3),
        ),
      ),
      child: AutoSavingTextField(
        value: data.text,
        hintText: context.l10n.blockQuoteHint,
        maxLines: 6,
        filled: false,
        textStyle: theme.textTheme.bodyLarge!.copyWith(
          fontStyle: FontStyle.italic,
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.6,
        ),
        onChanged: (String value) =>
            onChanged(data.copyWith(text: value).toJson()),
      ),
    );
  }
}

/// كتلة «تنبيه» — عنوان + نص + نبرة (معلومة/تحذير/خطر).
class CalloutBlockField extends StatelessWidget {
  const CalloutBlockField({
    super.key,
    required this.data,
    required this.onChanged,
  });

  final CalloutData data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppL10n l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Color background = calloutToneBackground(data.tone);
    final Color border = calloutToneBorder(data.tone);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: BorderDirectional(start: BorderSide(color: border, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(calloutToneIcon(data.tone), size: 18, color: border),
              const SizedBox(width: 8),
              Expanded(
                child: AutoSavingTextField(
                  value: data.title,
                  hintText: l10n.blockCalloutTitleHint,
                  filled: false,
                  textStyle: theme.textTheme.titleSmall!.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  onChanged: (String value) =>
                      onChanged(data.copyWith(title: value).toJson()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          AutoSavingTextField(
            value: data.text,
            hintText: l10n.blockCalloutTextHint,
            maxLines: 5,
            filled: false,
            onChanged: (String value) =>
                onChanged(data.copyWith(text: value).toJson()),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: <Widget>[
              for (final CalloutTone tone in CalloutTone.values)
                ChoiceChip(
                  label: Text(calloutToneLabel(tone, l10n)),
                  avatar: Icon(calloutToneIcon(tone), size: 16),
                  selected: tone == data.tone,
                  onSelected: (bool selected) {
                    if (selected) {
                      onChanged(data.copyWith(tone: tone).toJson());
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// كتلة «كود» — لغة اختيارية + نص بخط ثابت العرض.
class CodeBlockField extends StatelessWidget {
  const CodeBlockField({
    super.key,
    required this.data,
    required this.onChanged,
  });

  final CodeData data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppL10n l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AutoSavingTextField(
            value: data.language ?? '',
            hintText: l10n.blockCodeLanguageHint,
            filled: false,
            isDense: true,
            textDirection: TextDirection.ltr,
            textCapitalization: TextCapitalization.none,
            textStyle: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
            onChanged: (String value) =>
                onChanged(data.copyWith(language: value).toJson()),
          ),
          const Divider(height: 12),
          AutoSavingTextField(
            value: data.code,
            hintText: l10n.blockCodeHint,
            maxLines: 12,
            filled: false,
            monospace: true,
            textDirection: TextDirection.ltr,
            textCapitalization: TextCapitalization.none,
            onChanged: (String value) =>
                onChanged(data.copyWith(code: value).toJson()),
          ),
        ],
      ),
    );
  }
}

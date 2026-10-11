import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/aviation_data.dart';
import '../../../../core/utils/app_date.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_icon_picker.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/app_picker_field.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/l10n.dart';
import '../../application/pages_providers.dart';
import '../../domain/note_page.dart';

/// يفتح ورقة إنشاء/تعديل صفحة. تعيد true إذا حُفظ التغيير.
Future<bool> showPageFormSheet(
  BuildContext context, {
  required String notebookId,
  NotePage? existing,
  String? parentPageId,
  String? parentTitle,
}) async {
  final bool? result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) => PageFormSheet(
      notebookId: notebookId,
      existing: existing,
      parentPageId: parentPageId,
      parentTitle: parentTitle,
    ),
  );
  return result ?? false;
}

/// نموذج الصفحة: العنوان، الملخص، الرمز، وحقول الطيران المخصّصة.
class PageFormSheet extends ConsumerStatefulWidget {
  const PageFormSheet({
    super.key,
    required this.notebookId,
    this.existing,
    this.parentPageId,
    this.parentTitle,
  });

  final String notebookId;
  final NotePage? existing;
  final String? parentPageId;
  final String? parentTitle;

  @override
  ConsumerState<PageFormSheet> createState() => _PageFormSheetState();
}

class _PageFormSheetState extends ConsumerState<PageFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _summaryController =
      TextEditingController(text: widget.existing?.summary ?? '');
  late final TextEditingController _tailController =
      TextEditingController(text: widget.existing?.tailNumber ?? '');
  late final TextEditingController _icaoController =
      TextEditingController(text: widget.existing?.airportIcao ?? '');

  late String _icon = widget.existing?.displayIcon ?? AviationData.defaultPageIcon;
  late String? _aircraftType = widget.existing?.aircraftType;
  late String? _ataChapter = widget.existing?.ataChapter;
  late DateTime? _flightDate = widget.existing?.flightDate;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _tailController.dispose();
    _icaoController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime initial = _flightDate ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _flightDate = picked);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final PageActions actions = ref.read(pageActionsProvider);

      if (_isEditing) {
        await actions.updatePage(
          page: widget.existing!,
          title: _titleController.text.trim(),
          icon: _icon,
          summary: _summaryController.text.trim(),
          aircraftType: Validators.nullable(_aircraftType),
          tailNumber: Validators.upper(Validators.nullable(_tailController.text)),
          ataChapter: Validators.nullable(_ataChapter),
          airportIcao: Validators.upper(Validators.nullable(_icaoController.text)),
          flightDate: _flightDate,
          isFavorite: widget.existing!.isFavorite,
        );
      } else {
        await actions.createPage(
          notebookId: widget.notebookId,
          title: _titleController.text.trim(),
          parentPageId: widget.parentPageId,
          icon: _icon,
          summary: _summaryController.text.trim(),
          aircraftType: Validators.nullable(_aircraftType),
          tailNumber: Validators.upper(Validators.nullable(_tailController.text)),
          ataChapter: Validators.nullable(_ataChapter),
          airportIcao: Validators.upper(Validators.nullable(_icaoController.text)),
          flightDate: _flightDate,
        );
      }

      if (!mounted) {
        return;
      }
      showAppSnack(
        context,
        _isEditing ? context.l10n.pagesUpdated : context.l10n.pagesCreated,
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppFailureSnack(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppL10n l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool isArabic = context.isArabic;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  _isEditing ? l10n.pagesEditTitle : l10n.pagesNewTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (widget.parentTitle != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.pagesParentLabel}: ${widget.parentTitle}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                AppTextField(
                  controller: _titleController,
                  label: l10n.pagesTitleLabel,
                  hint: l10n.pagesTitleHint,
                  prefixIcon: Icons.title_rounded,
                  textCapitalization: TextCapitalization.sentences,
                  enabled: !_isSaving,
                  maxLength: 300,
                  validator: (String? value) =>
                      Validators.title(value, l10n, maxLength: 300),
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: _summaryController,
                  label: l10n.pagesSummaryLabel,
                  hint: l10n.pagesSummaryHint,
                  prefixIcon: Icons.notes_rounded,
                  maxLines: 2,
                  enabled: !_isSaving,
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.pagesMetadataSectionTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.pagesMetadataSectionSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                AppPickerField<String>(
                  label: l10n.fieldAircraftType,
                  hint: l10n.fieldAircraftTypeHint,
                  value: _aircraftType,
                  options: AviationData.aircraftTypes,
                  optionLabel: (String value) => value,
                  clearLabel: l10n.fieldAnyAircraft,
                  searchHint: l10n.commonSearch,
                  prefixIcon: Icons.flight_rounded,
                  enabled: !_isSaving,
                  onSelected: (String? value) =>
                      setState(() => _aircraftType = value),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _tailController,
                  label: l10n.fieldTailNumber,
                  hint: l10n.fieldTailNumberHint,
                  prefixIcon: Icons.confirmation_number_outlined,
                  textCapitalization: TextCapitalization.characters,
                  textDirection: TextDirection.ltr,
                  enabled: !_isSaving,
                  validator: (String? value) => Validators.tailNumber(value, l10n),
                ),
                const SizedBox(height: 14),
                AppPickerField<String>(
                  label: l10n.fieldAtaChapter,
                  hint: l10n.fieldAtaChapterHint,
                  value: _ataChapter,
                  options: AviationData.ataChapters
                      .map((AtaChapter chapter) => chapter.code)
                      .toList(growable: false),
                  optionLabel: (String code) =>
                      AviationData.ataLabel(code, arabic: isArabic),
                  clearLabel: l10n.fieldAnyAta,
                  searchHint: l10n.commonSearch,
                  prefixIcon: Icons.build_outlined,
                  enabled: !_isSaving,
                  onSelected: (String? value) =>
                      setState(() => _ataChapter = value),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _icaoController,
                  label: l10n.fieldAirport,
                  hint: l10n.fieldAirportHint,
                  prefixIcon: Icons.public_rounded,
                  textCapitalization: TextCapitalization.characters,
                  textDirection: TextDirection.ltr,
                  enabled: !_isSaving,
                  validator: (String? value) => Validators.icao(value, l10n),
                ),
                const SizedBox(height: 14),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.fieldFlightDate,
                    helperText: l10n.fieldFlightDateHint,
                    prefixIcon: const Icon(Icons.event_rounded),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _flightDate == null
                              ? l10n.stateNotSet
                              : AppDate.display(_flightDate!, arabic: isArabic),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      if (_flightDate != null)
                        IconButton(
                          tooltip: l10n.fieldClearDate,
                          onPressed: _isSaving
                              ? null
                              : () => setState(() => _flightDate = null),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      TextButton.icon(
                        onPressed: _isSaving ? null : _pickDate,
                        icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                        label: Text(l10n.fieldPickDate),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.pagesIconLabel,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                AppIconPicker(
                  options: AviationData.pageIcons,
                  selected: _icon,
                  onChanged: (String icon) => setState(() => _icon = icon),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const AppButtonProgress()
                      : Text(l10n.actionSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

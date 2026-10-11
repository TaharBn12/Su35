import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/validators.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/page.dart';
import '../../../shared/widgets/app_snackbars.dart';
import '../../../shared/widgets/app_text_field.dart';

/// Values collected by the page sheet.
class PageDraft {
  const PageDraft({
    required this.title,
    this.templateKey,
    this.aircraftType,
    this.registration,
    this.ataChapter,
    this.departureIcao,
    this.arrivalIcao,
    this.airportIcao,
    this.flightDate,
  });

  final String title;
  final String? templateKey;
  final String? aircraftType;
  final String? registration;
  final String? ataChapter;
  final String? departureIcao;
  final String? arrivalIcao;
  final String? airportIcao;
  final DateTime? flightDate;

  /// Creates a copy that only carries the title (used by "rename").
  PageDraft titleOnly() => PageDraft(title: title);
}

/// Bottom sheet for creating a page (with optional aviation metadata) or for
/// renaming an existing one.
Future<PageDraft?> showPageSheet(
  BuildContext context, {
  NotePage? existing,
  String? parentPageTitle,
  bool fullMetadata = true,
}) {
  return showModalBottomSheet<PageDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: _PageSheet(
          existing: existing,
          parentPageTitle: parentPageTitle,
          fullMetadata: fullMetadata,
        ),
      );
    },
  );
}

/// Creates a page and reports the result with a SnackBar.
Future<NotePage?> createPageFromSheet(
  BuildContext context,
  WidgetRef ref, {
  required String notebookId,
  String? parentPageId,
  String? parentPageTitle,
}) async {
  final t = context.t;
  final draft = await showPageSheet(context, parentPageTitle: parentPageTitle);
  if (draft == null || !context.mounted) return null;

  final mutations = ref.read(collectionMutationsProvider.notifier);
  final created = await mutations.createPage(
    notebookId: notebookId,
    title: draft.title,
    parentPageId: parentPageId,
    templateKey: draft.templateKey,
    aircraftType: draft.aircraftType,
    registration: draft.registration,
    ataChapter: draft.ataChapter,
    airportIcao: draft.airportIcao,
    departureIcao: draft.departureIcao,
    arrivalIcao: draft.arrivalIcao,
    flightDate: draft.flightDate,
  );

  if (!context.mounted) return null;
  if (created == null) {
    final failure = mutations.lastFailure;
    if (failure != null) AppSnackbars.failure(context, failure);
    return null;
  }
  AppSnackbars.success(context, t.get('pages.createdOk'));
  return created;
}

/// Renames a page (title only) and reports the result.
Future<NotePage?> renamePageFromSheet(
  BuildContext context,
  WidgetRef ref,
  NotePage page,
) async {
  final t = context.t;
  final draft = await showPageSheet(context, existing: page);
  if (draft == null || !context.mounted) return null;

  final mutations = ref.read(collectionMutationsProvider.notifier);
  final updated = await mutations.updatePage(page.id, title: draft.title);

  if (!context.mounted) return null;
  if (updated == null) {
    final failure = mutations.lastFailure;
    if (failure != null) AppSnackbars.failure(context, failure);
    return null;
  }
  AppSnackbars.success(context, t.get('pages.renamedOk'));
  return updated;
}

/// Updates the aviation metadata of an existing page.
Future<NotePage?> editPageMetadataFromSheet(
  BuildContext context,
  WidgetRef ref,
  NotePage page, {
  bool full = true,
}) async {
  final t = context.t;
  final draft = await showPageSheet(context, existing: page, fullMetadata: full);
  if (draft == null || !context.mounted) return null;

  final mutations = ref.read(collectionMutationsProvider.notifier);
  // `null` here means "clear the value": `CollectionMutations.updatePage`
  // forwards nulls to the repository which writes SQL NULL.
  final updated = await mutations.updatePage(
    page.id,
    title: draft.title,
    aircraftType: draft.aircraftType,
    registration: draft.registration,
    ataChapter: draft.ataChapter,
    airportIcao: draft.airportIcao,
    departureIcao: draft.departureIcao,
    arrivalIcao: draft.arrivalIcao,
    flightDate: draft.flightDate,
    clearNulls: true,
  );

  if (!context.mounted) return null;
  if (updated == null) {
    final failure = mutations.lastFailure;
    if (failure != null) AppSnackbars.failure(context, failure);
    return null;
  }
  AppSnackbars.success(context, t.get('settings.savedOk'));
  return updated;
}

class _PageSheet extends StatefulWidget {
  const _PageSheet({
    this.existing,
    this.parentPageTitle,
    this.fullMetadata = true,
  });

  final NotePage? existing;
  final String? parentPageTitle;
  final bool fullMetadata;

  @override
  State<_PageSheet> createState() => _PageSheetState();
}

class _PageSheetState extends State<_PageSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _aircraftController =
      TextEditingController(text: widget.existing?.aircraftType ?? '');
  late final TextEditingController _registrationController =
      TextEditingController(text: widget.existing?.registration ?? '');
  late final TextEditingController _departureController =
      TextEditingController(text: widget.existing?.departureIcao ?? '');
  late final TextEditingController _arrivalController =
      TextEditingController(text: widget.existing?.arrivalIcao ?? '');
  late final TextEditingController _airportController =
      TextEditingController(text: widget.existing?.airportIcao ?? '');

  late String? _ataChapter = widget.existing?.ataChapter;
  late String? _templateKey = widget.existing?.templateKey;
  late DateTime? _flightDate = widget.existing?.flightDate;
  bool _showAviationFields = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    // Open the aviation section automatically when editing a page that already
    // carries metadata, or when a template was pre-selected.
    final existing = widget.existing;
    _showAviationFields = !_isEdit ||
        (existing != null &&
            (existing.aircraftType != null ||
                existing.registration != null ||
                existing.ataChapter != null ||
                existing.airportIcao != null ||
                existing.departureIcao != null));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _aircraftController.dispose();
    _registrationController.dispose();
    _departureController.dispose();
    _arrivalController.dispose();
    _airportController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final l10n = context.l10n;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _flightDate ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 5),
      locale: l10n.locale,
      helpText: context.t.get('pages.flightDate'),
    );
    if (picked != null) setState(() => _flightDate = picked);
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    Navigator.of(context).pop(
      PageDraft(
        title: _titleController.text.trim(),
        templateKey: _isEdit ? null : _templateKey,
        aircraftType: _clean(_aircraftController.text.toUpperCase()),
        registration: _clean(_registrationController.text.toUpperCase()),
        ataChapter: _ataChapter,
        departureIcao: _clean(_departureController.text.toUpperCase()),
        arrivalIcao: _clean(_arrivalController.text.toUpperCase()),
        airportIcao: _clean(_airportController.text.toUpperCase()),
        flightDate: _flightDate,
      ),
    );
  }

  static String? _clean(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _isEdit
                    ? t.get('pages.renamePage')
                    : (widget.parentPageTitle == null
                        ? t.get('pages.newPage')
                        : '${t.get('pages.newSubPage')} · ${widget.parentPageTitle}'),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              AppTextField(
                label: t.get('pages.pageTitle'),
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 120,
                validatorKey: Validators.requiredText,
                onSubmitted: (_) => _submit(),
              ),
              if (!_isEdit) ...<Widget>[
                const SizedBox(height: 16),
                Text(t.get('pages.template'), style: theme.textTheme.titleSmall),
                const SizedBox(height: 10),
                _TemplatePicker(
                  selected: _templateKey,
                  onChanged: (key) => setState(() => _templateKey = key),
                ),
              ],
              if (widget.fullMetadata) ...<Widget>[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => setState(
                    () => _showAviationFields = !_showAviationFields,
                  ),
                  icon: Icon(
                    _showAviationFields
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                  label: Text(t.get('pages.advancedFields')),
                ),
                if (_showAviationFields) ...<Widget>[
                  const SizedBox(height: 6),
                  _AviationFields(
                    aircraftController: _aircraftController,
                    registrationController: _registrationController,
                    departureController: _departureController,
                    arrivalController: _arrivalController,
                    airportController: _airportController,
                    ataChapter: _ataChapter,
                    onAtaChanged: (value) =>
                        setState(() => _ataChapter = value),
                    flightDate: _flightDate,
                    onPickDate: _pickDate,
                    onClearDate: () => setState(() => _flightDate = null),
                    dateLabel: _flightDate == null
                        ? t.get('pages.flightDate')
                        : l10n.formatDate(_flightDate),
                  ),
                ],
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _submit,
                child: Text(
                  _isEdit ? t.get('generic.save') : t.get('pages.createPage'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final templates = <String?>[
      null,
      TemplateKeys.flightLog,
      TemplateKeys.maintenance,
      TemplateKeys.preflightChecklist,
      TemplateKeys.theoryLesson,
      TemplateKeys.defectReport,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: templates.map((key) {
        final isSelected = key == selected;
        final label = key == null
            ? t.get('pages.noTemplate')
            : t.get('template.$key');
        return ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (_) => onChanged(key),
          labelStyle: theme.textTheme.labelLarge?.copyWith(
            color: isSelected
                ? theme.colorScheme.onSecondaryContainer
                : theme.colorScheme.onSurfaceVariant,
          ),
          selectedColor: theme.colorScheme.secondaryContainer,
        );
      }).toList(growable: false),
    );
  }
}

class _AviationFields extends StatelessWidget {
  const _AviationFields({
    required this.aircraftController,
    required this.registrationController,
    required this.departureController,
    required this.arrivalController,
    required this.airportController,
    required this.ataChapter,
    required this.onAtaChanged,
    required this.flightDate,
    required this.onPickDate,
    required this.onClearDate,
    required this.dateLabel,
  });

  final TextEditingController aircraftController;
  final TextEditingController registrationController;
  final TextEditingController departureController;
  final TextEditingController arrivalController;
  final TextEditingController airportController;
  final String? ataChapter;
  final ValueChanged<String?> onAtaChanged;
  final DateTime? flightDate;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextField(
            label: t.get('pages.aircraftType'),
            controller: aircraftController,
            hint: 'A320',
            textCapitalization: TextCapitalization.characters,
            maxLength: 24,
            textDirection: TextDirection.ltr,
            prefixIcon: Icons.flight_rounded,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: AircraftTypes.common.take(8).map((type) {
              return ActionChip(
                label: Text(type),
                visualDensity: VisualDensity.compact,
                onPressed: () => aircraftController.text = type,
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: t.get('pages.registration'),
            controller: registrationController,
            hint: 'A6-EOV',
            textCapitalization: TextCapitalization.characters,
            maxLength: 12,
            textDirection: TextDirection.ltr,
            prefixIcon: Icons.confirmation_number_outlined,
            validatorKey: Validators.optionalRegistration,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String?>(
            initialValue: ataChapter,
            decoration: InputDecoration(
              labelText: t.get('pages.ataChapter'),
              prefixIcon: const Icon(Icons.category_outlined, size: 20),
            ),
            isExpanded: true,
            items: <DropdownMenuItem<String?>>[
              DropdownMenuItem<String?>(
                value: null,
                child: Text(t.get('generic.optional')),
              ),
              ...AtaChapters.codes.map(
                (code) => DropdownMenuItem<String?>(
                  value: code,
                  child: Text(
                    'ATA $code · ${AtaChapters.label(code)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: onAtaChanged,
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: AppTextField(
                  label: t.get('pages.departure'),
                  controller: departureController,
                  hint: 'OMDB',
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 4,
                  textDirection: TextDirection.ltr,
                  validatorKey: Validators.optionalIcao,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: AppTextField(
                  label: t.get('pages.arrival'),
                  controller: arrivalController,
                  hint: 'OJAI',
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 4,
                  textDirection: TextDirection.ltr,
                  validatorKey: Validators.optionalIcao,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: t.get('pages.airport'),
            controller: airportController,
            hint: 'OEJN',
            textCapitalization: TextCapitalization.characters,
            maxLength: 4,
            textDirection: TextDirection.ltr,
            prefixIcon: Icons.location_on_outlined,
            validatorKey: Validators.optionalIcao,
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickDate,
                  style: OutlinedButton.styleFrom(
                    alignment: AlignmentDirectional.centerStart,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  icon: const Icon(Icons.event_rounded, size: 20),
                  label: Text(dateLabel),
                ),
              ),
              if (flightDate != null)
                IconButton(
                  tooltip: t.get('generic.delete'),
                  onPressed: onClearDate,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

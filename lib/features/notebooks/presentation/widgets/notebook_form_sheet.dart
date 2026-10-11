import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/aviation_data.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_color_picker.dart';
import '../../../../core/widgets/app_icon_picker.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/app_picker_field.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/l10n.dart';
import '../../application/notebooks_controller.dart';
import '../../domain/notebook.dart';

/// يفتح ورقة إنشاء/تعديل دفتر. تعيد true إذا حُفظ التغيير.
Future<bool> showNotebookFormSheet(
  BuildContext context, {
  Notebook? existing,
}) async {
  final bool? result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) =>
        NotebookFormSheet(existing: existing),
  );
  return result ?? false;
}

/// نموذج دفتر: العنوان، الوصف، الرمز، اللون، نوع الطائرة، والتثبيت.
class NotebookFormSheet extends ConsumerStatefulWidget {
  const NotebookFormSheet({super.key, this.existing});

  final Notebook? existing;

  @override
  ConsumerState<NotebookFormSheet> createState() => _NotebookFormSheetState();
}

class _NotebookFormSheetState extends ConsumerState<NotebookFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.existing?.description ?? '');

  late String _icon = widget.existing?.displayIcon ??
      AviationData.defaultNotebookIcon;
  late String _color =
      widget.existing?.color ?? AviationData.defaultNotebookColor;
  late String? _aircraftType = widget.existing?.aircraftType;
  late bool _isFavorite = widget.existing?.isFavorite ?? false;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
      final NotebooksController controller =
          ref.read(notebooksControllerProvider.notifier);

      if (_isEditing) {
        final Notebook updated = widget.existing!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          icon: _icon,
          color: _color,
          aircraftType: (_aircraftType ?? '').trim(),
          isFavorite: _isFavorite,
        );
        await controller.update(updated);
      } else {
        await controller.create(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          icon: _icon,
          color: _color,
          aircraftType: _aircraftType,
          isFavorite: _isFavorite,
        );
      }

      if (!mounted) {
        return;
      }
      showAppSnack(
        context,
        _isEditing
            ? context.l10n.notebooksUpdated
            : context.l10n.notebooksCreated,
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

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  _isEditing ? l10n.notebooksEditTitle : l10n.notebooksNewTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _titleController,
                  label: l10n.notebooksTitleLabel,
                  hint: l10n.notebooksTitleHint,
                  prefixIcon: Icons.menu_book_outlined,
                  textCapitalization: TextCapitalization.sentences,
                  enabled: !_isSaving,
                  validator: (String? value) => Validators.title(value, l10n),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _descriptionController,
                  label: l10n.notebooksDescriptionLabel,
                  hint: l10n.notebooksDescriptionHint,
                  prefixIcon: Icons.notes_rounded,
                  maxLines: 2,
                  enabled: !_isSaving,
                ),
                const SizedBox(height: 14),
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
                const SizedBox(height: 18),
                Text(
                  l10n.notebooksIconLabel,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                AppIconPicker(
                  options: AviationData.notebookIcons,
                  selected: _icon,
                  onChanged: (String icon) => setState(() => _icon = icon),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.notebooksColorLabel,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                AppColorPicker(
                  options: AviationData.notebookColors,
                  selected: _color,
                  onChanged: (String color) => setState(() => _color = color),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isFavorite,
                  onChanged: _isSaving
                      ? null
                      : (bool value) => setState(() => _isFavorite = value),
                  title: Text(l10n.notebooksFavoriteLabel),
                  subtitle: Text(l10n.notebooksFavoriteHint),
                  secondary: const Icon(Icons.star_rounded),
                ),
                const SizedBox(height: 16),
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

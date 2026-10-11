import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/notebook.dart';
import '../../../shared/widgets/app_snackbars.dart';
import '../../../shared/widgets/app_text_field.dart';

/// Values collected by the create/edit notebook sheet.
class NotebookDraft {
  const NotebookDraft({
    required this.name,
    required this.icon,
    required this.color,
    this.description,
  });

  final String name;
  final String icon;
  final String color;
  final String? description;
}

/// Bottom sheet used both to create and to edit a notebook.
///
/// Returns `null` when dismissed without saving.
Future<NotebookDraft?> showNotebookSheet(
  BuildContext context, {
  Notebook? existing,
}) {
  return showModalBottomSheet<NotebookDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: _NotebookSheet(existing: existing),
      );
    },
  );
}

/// Creates or updates a notebook through [collectionMutationsProvider] and
/// reports the outcome with a SnackBar. Returns `true` on success.
Future<bool> submitNotebookSheet(
  BuildContext context,
  WidgetRef ref, {
  Notebook? existing,
}) async {
  final t = context.t;
  final draft = await showNotebookSheet(context, existing: existing);
  if (draft == null || !context.mounted) return false;

  final mutations = ref.read(collectionMutationsProvider.notifier);

  final Notebook? saved = existing == null
      ? await mutations.createNotebook(
          name: draft.name,
          icon: draft.icon,
          color: draft.color,
          description: draft.description,
        )
      : await mutations.updateNotebookMeta(
          existing.id,
          name: draft.name,
          icon: draft.icon,
          color: draft.color,
          description: draft.description,
        );

  if (!context.mounted) return false;

  if (saved == null) {
    final failure = mutations.lastFailure;
    if (failure != null) {
      AppSnackbars.failure(context, failure);
    } else {
      AppSnackbars.error(context, const AppFailurePlaceholder());
    }
    return false;
  }

  AppSnackbars.success(
    context,
    existing == null ? t.get('home.createdOk') : t.get('home.renamedOk'),
  );
  return true;
}

/// Sentinel used only when a mutation failed without producing an
/// [AppFailure] (should not happen - `_run` always sets `lastFailure`).
class AppFailurePlaceholder implements Exception {
  const AppFailurePlaceholder();

  @override
  String toString() => 'Operation failed';
}

class _NotebookSheet extends StatefulWidget {
  const _NotebookSheet({this.existing});

  final Notebook? existing;

  @override
  State<_NotebookSheet> createState() => _NotebookSheetState();
}

class _NotebookSheetState extends State<_NotebookSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.existing?.description ?? '');

  late String _icon = widget.existing?.icon ?? AppConstants.defaultNotebookIcon;
  late String _color =
      widget.existing?.color ?? AppConstants.defaultNotebookColor;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final description = _descriptionController.text.trim();
    Navigator.of(context).pop(
      NotebookDraft(
        name: _nameController.text.trim(),
        icon: _icon,
        color: _color,
        description: description.isEmpty ? null : description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final isEdit = widget.existing != null;

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
                isEdit
                    ? t.get('home.renameNotebook')
                    : t.get('home.newNotebook'),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              AppTextField(
                label: t.get('home.notebookName'),
                controller: _nameController,
                autofocus: !isEdit,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 60,
                validatorKey: Validators.requiredText,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Description (${t.get('generic.optional')})',
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 180,
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              Text(
                t.get('home.notebookIcon'),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: AppTheme.notebookIcons.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final icon = AppTheme.notebookIcons[index];
                    return _PickerChip(
                      label: icon,
                      selected: icon == _icon,
                      onTap: () => setState(() => _icon = icon),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Text(
                t.get('home.notebookColor'),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AppTheme.notebookColors.map((color) {
                  final hex = colorToHex(color);
                  final selected =
                      hex.toUpperCase() == _color.toUpperCase();
                  return InkWell(
                    onTap: () => setState(() => _color = hex),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? theme.colorScheme.onSurface
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                }).toList(growable: false),
              ),
              const SizedBox(height: 26),
              FilledButton(
                onPressed: _save,
                child: Text(
                  isEdit
                      ? t.get('generic.save')
                      : t.get('home.createNotebook'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerChip extends StatelessWidget {
  const _PickerChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.6,
                ),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            width: 1.6,
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}

/// `Color` -> `#RRGGBB` (alpha dropped, matching the DB `color` column).
String colorToHex(Color color) {
  final argb = color.toARGB32().toRadixString(16).padLeft(8, '0');
  return '#${argb.substring(2).toUpperCase()}';
}

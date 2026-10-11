import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/l10n.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/domain/app_user.dart';
import '../../../auth/domain/user_role.dart';
import '../../../auth/presentation/widgets/role_selector.dart';

/// يفتح ورقة تعديل الملف الشخصي. تعيد true إذا حُفظ التغيير.
Future<bool> showProfileEditSheet(BuildContext context, AppUser user) async {
  final bool? result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) => ProfileEditSheet(user: user),
  );
  return result ?? false;
}

/// تعديل الاسم والصفة المهنية ورقم الرخصة والقاعدة الرئيسية.
class ProfileEditSheet extends ConsumerStatefulWidget {
  const ProfileEditSheet({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<ProfileEditSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController =
      TextEditingController(text: widget.user.displayName ?? '');
  late final TextEditingController _licenseController =
      TextEditingController(text: widget.user.licenseNumber ?? '');
  late final TextEditingController _baseController =
      TextEditingController(text: widget.user.homeBaseIcao ?? '');

  late UserRole _role = widget.user.role;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _licenseController.dispose();
    _baseController.dispose();
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
      await ref.read(profileRepositoryProvider).updateProfile(
            current: widget.user,
            displayName: _nameController.text.trim(),
            role: _role,
            licenseNumber: _licenseController.text.trim(),
            homeBaseIcao: _baseController.text.trim(),
          );
      await ref.read(authControllerProvider.notifier).refreshProfile();

      if (!mounted) {
        return;
      }
      showAppSnack(context, context.l10n.settingsProfileSaved);
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.settingsEditProfile,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _nameController,
                label: l10n.authDisplayNameLabel,
                hint: l10n.authDisplayNameHint,
                prefixIcon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.words,
                enabled: !_isSaving,
                validator: (String? value) => Validators.requiredName(value, l10n),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _licenseController,
                label: l10n.authRoleLabel,
                prefixIcon: Icons.badge_outlined,
                textDirection: TextDirection.ltr,
                enabled: !_isSaving,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _baseController,
                label: l10n.fieldAirport,
                hint: l10n.fieldAirportHint,
                prefixIcon: Icons.home_work_outlined,
                textCapitalization: TextCapitalization.characters,
                textDirection: TextDirection.ltr,
                enabled: !_isSaving,
                validator: (String? value) => Validators.icao(value, l10n),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.authRoleLabel,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              RoleSelector(
                selected: _role,
                onChanged: _isSaving
                    ? (UserRole _) {}
                    : (UserRole role) => setState(() => _role = role),
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
    );
  }
}

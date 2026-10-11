import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/failures/app_failure.dart';
import '../../../../core/failures/error_mapper.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/l10n.dart';
import '../../application/auth_controller.dart';
import '../../domain/sign_up_result.dart';
import '../../domain/user_role.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/role_selector.dart';

/// شاشة إنشاء حساب جديد.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  UserRole _role = UserRole.pilot;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    try {
      final SignUpResult result =
          await ref.read(authControllerProvider.notifier).signUp(
                email: _emailController.text,
                password: _passwordController.text,
                displayName: _nameController.text,
                role: _role,
              );

      if (!mounted) {
        return;
      }

      if (result.needsEmailConfirmation) {
        showAppSnack(context, context.l10n.authAccountCreatedCheckEmail);
        context.go(AppRoutes.signIn);
      }
      // إذا لم يلزم تأكيد البريد فالراوتر ينقل المستخدم تلقائيًا للدفاتر.
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      setState(() {
        _failure = ErrorMapper.map(error, stackTrace);
      });
      showAppFailureSnack(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppL10n l10n = context.l10n;

    return AuthScaffold(
      appName: l10n.appName,
      tagline: l10n.appTagline,
      title: l10n.authSignUpTitle,
      subtitle: l10n.authSignUpSubtitle,
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(l10n.authHaveAccountPrompt),
          TextButton(
            onPressed:
                _isSubmitting ? null : () => context.go(AppRoutes.signIn),
            child: Text(l10n.authSignInButton),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTextField(
              controller: _nameController,
              label: l10n.authDisplayNameLabel,
              hint: l10n.authDisplayNameHint,
              prefixIcon: Icons.person_outline_rounded,
              textCapitalization: TextCapitalization.words,
              enabled: !_isSubmitting,
              validator: (String? value) => Validators.requiredName(value, l10n),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _emailController,
              label: l10n.authEmailLabel,
              hint: l10n.authEmailHint,
              prefixIcon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const <String>[AutofillHints.email],
              enabled: !_isSubmitting,
              validator: (String? value) => Validators.email(value, l10n),
            ),
            const SizedBox(height: 14),
            AppPasswordField(
              controller: _passwordController,
              label: l10n.authPasswordLabel,
              hint: l10n.authPasswordHint,
              autofillHints: const <String>[AutofillHints.newPassword],
              validator: (String? value) => Validators.password(value, l10n),
            ),
            const SizedBox(height: 14),
            AppPasswordField(
              controller: _confirmController,
              label: l10n.authConfirmPasswordLabel,
              textInputAction: TextInputAction.done,
              validator: (String? value) => Validators.confirmPassword(
                value,
                _passwordController.text,
                l10n,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.authRoleLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            RoleSelector(
              selected: _role,
              onChanged: _isSubmitting
                  ? (UserRole _) {}
                  : (UserRole role) => setState(() => _role = role),
            ),
            const SizedBox(height: 18),
            if (_failure != null) ...<Widget>[
              AppInlineErrorCard(failure: _failure!),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const AppButtonProgress()
                  : Text(l10n.authSignUpButton),
            ),
          ],
        ),
      ),
    );
  }
}

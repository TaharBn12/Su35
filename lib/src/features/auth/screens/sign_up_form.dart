import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_dialogs.dart';
import '../../../shared/widgets/app_snackbars.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../providers/auth_providers.dart';

/// Account creation form (rendered inside `AuthScreen`).
///
/// When the Supabase project requires email confirmation, [signUp] returns
/// `false`; we explain the next step and hand the email back to the sign-in
/// form through [onSwitchToSignIn].
class SignUpForm extends ConsumerStatefulWidget {
  const SignUpForm({
    required this.onSwitchToSignIn,
    super.key,
  });

  /// `email` is pre-filled in the sign-in form after a confirmation email was
  /// sent (null when the user simply switched tabs).
  final void Function(String? email) onSwitchToSignIn;

  @override
  ConsumerState<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends ConsumerState<SignUpForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final t = context.t;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    final email = _emailController.text.trim().toLowerCase();

    try {
      final signedIn = await ref.read(authRepositoryProvider).signUp(
            email: email,
            password: _passwordController.text,
            fullName: _nameController.text,
          );

      if (!mounted) return;

      if (signedIn) {
        // A session is already active -> the router redirects to /home.
        return;
      }

      await showInfoDialog(
        context,
        title: t.get('auth.signedUpTitle'),
        message: t.get('auth.signedUpBody').replaceFirst('{email}', email),
      );
      if (!mounted) return;
      widget.onSwitchToSignIn(email);
    } catch (error) {
      if (mounted) AppSnackbars.error(context, error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextField(
            label: t.get('auth.fullName'),
            controller: _nameController,
            prefixIcon: Icons.badge_outlined,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validatorKey: Validators.displayName,
            enabled: !_submitting,
            autofocus: true,
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: t.get('auth.email'),
            controller: _emailController,
            hint: 'captain@aeronotes.app',
            prefixIcon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            textDirection: TextDirection.ltr,
            validatorKey: Validators.email,
            enabled: !_submitting,
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: t.get('auth.password'),
            controller: _passwordController,
            prefixIcon: Icons.lock_outline_rounded,
            obscure: true,
            textInputAction: TextInputAction.next,
            validatorKey: Validators.password,
            enabled: !_submitting,
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: t.get('auth.confirmPassword'),
            controller: _confirmController,
            prefixIcon: Icons.lock_reset_rounded,
            obscure: true,
            textInputAction: TextInputAction.done,
            validatorKey: (value) => Validators.confirmPassword(
              value,
              _passwordController.text,
            ),
            enabled: !_submitting,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(t.get('auth.signingUp')),
                    ],
                  )
                : Text(t.get('auth.signUp')),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                t.get('auth.haveAccount'),
                style: theme.textTheme.bodyMedium,
              ),
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => widget.onSwitchToSignIn(null),
                child: Text(t.get('auth.signIn')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

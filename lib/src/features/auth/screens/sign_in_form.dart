import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_snackbars.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../providers/auth_providers.dart';
import 'auth_screen.dart';

/// Sign-in form (rendered inside [AuthScreen]).
///
/// Navigation on success is handled by the router: the auth stream flips
/// [authStatusProvider] to `AuthSignedIn` and `redirect` moves to `/home`.
class SignInForm extends ConsumerStatefulWidget {
  const SignInForm({
    required this.onSwitchToSignUp,
    super.key,
    this.initialEmail,
  });

  /// Switches [AuthScreen] to the sign-up mode (no navigation involved, so the
  /// auth redirect cannot kick the user out mid-flow).
  final VoidCallback onSwitchToSignUp;

  /// Pre-filled after a signup that required email confirmation.
  final String? initialEmail;

  @override
  ConsumerState<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends ConsumerState<SignInForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController =
      TextEditingController(text: widget.initialEmail ?? '');
  final TextEditingController _passwordController = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _emailController.text,
            password: _passwordController.text,
          );
      // Success: the router reacts to the auth stream, nothing to push here.
    } catch (error) {
      if (mounted) AppSnackbars.error(context, error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _forgotPassword() async {
    final t = context.t;
    final controller = TextEditingController(text: _emailController.text.trim());
    final formKey = GlobalKey<FormState>();

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t.get('auth.forgotPassword')),
          content: Form(
            key: formKey,
            child: AppTextField(
              label: t.get('auth.email'),
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              prefixIcon: Icons.alternate_email_rounded,
              validatorKey: Validators.email,
              autofocus: true,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t.get('generic.cancel')),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(controller.text.trim());
                }
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size(120, 44),
              ),
              child: Text(t.get('auth.resetPassword')),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (email == null || email.isEmpty || !mounted) return;

    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (mounted) {
        AppSnackbars.success(context, context.t.get('auth.resetSent'));
      }
    } catch (error) {
      if (mounted) AppSnackbars.error(context, error);
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
            label: t.get('auth.email'),
            controller: _emailController,
            hint: 'captain@aeronotes.app',
            prefixIcon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            textDirection: TextDirection.ltr,
            autofillHints: const <String>[AutofillHints.email],
            validatorKey: Validators.email,
            enabled: !_submitting,
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: t.get('auth.password'),
            controller: _passwordController,
            prefixIcon: Icons.lock_outline_rounded,
            obscure: true,
            textInputAction: TextInputAction.done,
            autofillHints: const <String>[AutofillHints.password],
            validatorKey: Validators.password,
            enabled: !_submitting,
            onSubmitted: (_) => _submit(),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: _submitting ? null : _forgotPassword,
              child: Text(t.get('auth.forgotPassword')),
            ),
          ),
          const SizedBox(height: 6),
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
                      Text(t.get('auth.signingIn')),
                    ],
                  )
                : Text(t.get('auth.signIn')),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(t.get('auth.noAccount'), style: theme.textTheme.bodyMedium),
              TextButton(
                onPressed: _submitting ? null : widget.onSwitchToSignUp,
                child: Text(t.get('auth.signUp')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

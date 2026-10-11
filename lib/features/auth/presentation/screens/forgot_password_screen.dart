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
import '../widgets/auth_scaffold.dart';

/// شاشة استعادة كلمة المرور (إرسال رابط إلى البريد).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();

  bool _isSubmitting = false;
  bool _isSent = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _emailController.dispose();
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
      await ref
          .read(authControllerProvider.notifier)
          .sendPasswordResetEmail(_emailController.text);
      if (!mounted) {
        return;
      }
      setState(() {
        _isSent = true;
      });
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
      title: _isSent ? l10n.authResetSentTitle : l10n.authForgotPasswordTitle,
      subtitle: _isSent
          ? l10n.authResetSentBody(_emailController.text.trim())
          : l10n.authForgotPasswordSubtitle,
      footer: TextButton.icon(
        onPressed: _isSubmitting ? null : () => context.go(AppRoutes.signIn),
        icon: const Icon(Icons.arrow_back_rounded, size: 18),
        label: Text(l10n.authBackToSignIn),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_isSent)
            Icon(
              Icons.mark_email_read_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            )
          else
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppTextField(
                    controller: _emailController,
                    label: l10n.authEmailLabel,
                    hint: l10n.authEmailHint,
                    prefixIcon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    enabled: !_isSubmitting,
                    validator: (String? value) => Validators.email(value, l10n),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  if (_failure != null) ...<Widget>[
                    AppInlineErrorCard(failure: _failure!),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const AppButtonProgress()
                        : Text(l10n.authForgotPasswordButton),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

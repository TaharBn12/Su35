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

/// شاشة تسجيل الدخول.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
      await ref.read(authControllerProvider.notifier).signIn(
            email: _emailController.text,
            password: _passwordController.text,
          );
      // الراوتر ينقل تلقائيًا إلى الدفاتر بعد تغيّر حالة المصادقة.
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
      title: l10n.authSignInTitle,
      subtitle: l10n.authSignInSubtitle,
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(l10n.authNoAccountPrompt),
          TextButton(
            onPressed: _isSubmitting
                ? null
                : () => context.push(AppRoutes.signUp),
            child: Text(l10n.authSignUpButton),
          ),
        ],
      ),
      child: Form(
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
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.email],
              enabled: !_isSubmitting,
              validator: (String? value) => Validators.email(value, l10n),
            ),
            const SizedBox(height: 14),
            AppPasswordField(
              controller: _passwordController,
              label: l10n.authPasswordLabel,
              hint: l10n.authPasswordHint,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.password],
              validator: (String? value) => Validators.password(value, l10n),
              onSubmitted: (_) => _submit(),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () => context.push(AppRoutes.forgotPassword),
                child: Text(l10n.authForgotPasswordLink),
              ),
            ),
            if (_failure != null) ...<Widget>[
              AppInlineErrorCard(failure: _failure!),
              const SizedBox(height: 12),
            ] else
              const SizedBox(height: 4),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const AppButtonProgress()
                  : Text(l10n.authSignInButton),
            ),
          ],
        ),
      ),
    );
  }
}

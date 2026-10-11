import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../widgets/auth_scaffold.dart';
import 'sign_in_form.dart';
import 'sign_up_form.dart';

/// Which form [AuthScreen] shows.
enum AuthMode { signIn, signUp }

/// Single authentication screen hosting both sign-in and sign-up.
///
/// Keeping both modes on one route (`/auth`) avoids a redirect fight: while the
/// user is signed out, the router sends every unauthenticated location to
/// `/auth`, so navigating between `/login` and `/signup` would be undone by the
/// guard. Switching modes is therefore local state.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.initialMode = AuthMode.signIn});

  /// Parsed from the `mode` query parameter (`/auth?mode=signup`).
  final AuthMode initialMode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late AuthMode _mode = widget.initialMode;
  String? _prefilledEmail;

  void _switchMode(AuthMode mode, {String? email}) {
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _prefilledEmail = email;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final isSignIn = _mode == AuthMode.signIn;

    return AuthScaffold(
      title: isSignIn ? t.get('auth.welcomeTitle') : t.get('auth.signUp'),
      subtitle: t.get('auth.welcomeSubtitle'),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _ModeSwitcher(
                mode: _mode,
                onChanged: (mode) => _switchMode(mode),
              ),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  final offset = Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: offset, child: child),
                  );
                },
                child: isSignIn
                    ? SignInForm(
                        key: const ValueKey<String>('sign-in'),
                        initialEmail: _prefilledEmail,
                        onSwitchToSignUp: () =>
                            _switchMode(AuthMode.signUp),
                      )
                    : SignUpForm(
                        key: const ValueKey<String>('sign-up'),
                        onSwitchToSignIn: (email) =>
                            _switchMode(AuthMode.signIn, email: email),
                      ),
              ),
            ],
          ),
        ),
      ),
      footer: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          t.get('app.tagline'),
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium,
        ),
      ),
    );
  }
}

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({required this.mode, required this.onChanged});

  final AuthMode mode;
  final ValueChanged<AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return SegmentedButton<AuthMode>(
      segments: <ButtonSegment<AuthMode>>[
        ButtonSegment<AuthMode>(
          value: AuthMode.signIn,
          label: Text(t.get('auth.signIn')),
          icon: const Icon(Icons.login_rounded, size: 18),
        ),
        ButtonSegment<AuthMode>(
          value: AuthMode.signUp,
          label: Text(t.get('auth.signUp')),
          icon: const Icon(Icons.person_add_alt_rounded, size: 18),
        ),
      ],
      selected: <AuthMode>{mode},
      onSelectionChanged: (selection) => onChanged(selection.first),
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll<TextStyle?>(
          Theme.of(context).textTheme.labelLarge,
        ),
      ),
    );
  }
}

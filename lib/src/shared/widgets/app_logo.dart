import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';

/// The AeroNotes mark: a rounded "radar" tile with a paper-plane glyph.
///
/// Drawn with primitives (no image asset) so it stays crisp in RTL, dark mode
/// and any density.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 56, this.showTagline = false});

  final double size;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t;

    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.65),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.28),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Icon(
        Icons.flight_takeoff_rounded,
        size: size * 0.52,
        color: theme.colorScheme.onPrimary,
      ),
    );

    if (!showTagline) return badge;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        badge,
        SizedBox(height: size * 0.28),
        Text(
          t.get('app.name'),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          t.get('app.tagline'),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Small "v0.1.0" caption used on the auth screens and in settings.
class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      '${AppConstants.appName} ${AppConstants.appVersion}',
      style: Theme.of(context).textTheme.labelSmall,
    );
  }
}

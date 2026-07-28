import 'package:flutter/widgets.dart';
import 'package:c_template_app/l10n/gen/app_localizations.dart';

export 'package:c_template_app/l10n/gen/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

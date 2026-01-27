import 'package:flutter/material.dart';
import 'app_localizations.dart';

extension LocalizationHelper on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String tr(String key) => l10n.translate(key);
}

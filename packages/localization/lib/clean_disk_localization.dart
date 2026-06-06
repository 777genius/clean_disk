library;

import 'package:flutter/widgets.dart';

import 'src/generated/clean_disk_localizations.dart';

export 'src/generated/clean_disk_localizations.dart';

extension CleanDiskLocalizationsBuildContext on BuildContext {
  CleanDiskLocalizations get cleanDiskL10n => CleanDiskLocalizations.of(this);
}

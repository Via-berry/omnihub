// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get fetchMediaserverLibraryStatus =>
      'Query media library status when searching';

  @override
  String get backgroundImageUseServer => 'Use server image';

  @override
  String get backgroundImageServerUrl => 'Server image URL';
}

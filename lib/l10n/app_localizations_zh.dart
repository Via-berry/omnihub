// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get fetchMediaserverLibraryStatus => '搜索时查询媒体入库状态';

  @override
  String get backgroundImageUseServer => '使用服务器图片';

  @override
  String get backgroundImageServerUrl => '服务器图片地址';
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppLocale {
  AppLocale._();

  static final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);

  static Future<void> restore() async {
    final saved = Supabase
        .instance
        .client
        .auth
        .currentUser
        ?.userMetadata?['preferred_language']
        ?.toString();
    if (saved == 'fr' || saved == 'en') locale.value = Locale(saved!);
  }

  static Future<void> setLanguage(String languageCode) async {
    if (languageCode != 'fr' && languageCode != 'en') return;
    locale.value = Locale(languageCode);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(data: {'preferred_language': languageCode}),
    );
  }

  static bool isEnglish(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'en';

  static String text(BuildContext context, String french, String english) =>
      isEnglish(context) ? english : french;
}

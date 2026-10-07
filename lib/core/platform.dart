import 'package:flutter/foundation.dart';

/// La version web est la **console d'administration** ; les espaces client,
/// vendeur et livreur sont dans l'application mobile.
///
/// Pour tester l'app complète dans le navigateur :
/// `flutter run -d chrome --dart-define=WEB_FULL_APP=true`
const bool kAdminConsole = kIsWeb && !bool.fromEnvironment('WEB_FULL_APP');

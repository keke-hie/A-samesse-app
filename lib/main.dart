import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/deep_links/deep_link_service.dart';
import 'core/routes/app_router.dart';
import 'core/services/session_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Clé publique (anon) : sans danger côté client, l'accès aux données est
  // contrôlé par les règles RLS de Supabase.
  await Supabase.initialize(
    url: 'https://kfnonbssmbblayxifoha.supabase.co',
    publishableKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtmbm9uYnNzbWJibGF5eGlmb2hhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg1MTE4MzgsImV4cCI6MjEwNDA4NzgzOH0.p5Y2NVMLiYza3Pa51vEB3rG5Nfxv3VNIuSTLOyd0wOI',
  );
  // Chargement du profil (rôle, statut) en parallèle de l'affichage du splash.
  unawaited(SessionService.instance.init());

  runApp(const AsamesseApp());

  // Démarre l'écoute des deep links (App Links Android / Universal Links iOS).
  await DeepLinkService.instance.init();
}

class AsamesseApp extends StatelessWidget {
  const AsamesseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: "A'samesse",
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/routes/app_router.dart';
import 'core/constants/app_color.dart'; // N'oubliez pas d'importer vos couleurs

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://kfnonbssmbblayxifoha.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtmbm9uYnNzbWJibGF5eGlmb2hhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg1MTE4MzgsImV4cCI6MjEwNDA4NzgzOH0.p5Y2NVMLiYza3Pa51vEB3rG5Nfxv3VNIuSTLOyd0wOI',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: "A'samesse",
      debugShowCheckedModeBanner: false,
      // Application globale du thème et de la couleur de fond
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColor.background,
        primaryColor: AppColor.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColor.primary,
          surface: AppColor.background,
        ),
      ),
      routerConfig: appRouter,
    );
  }
}
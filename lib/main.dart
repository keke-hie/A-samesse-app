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
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColor.primary,
          brightness: Brightness.light,
          primary: AppColor.primary,
          secondary: AppColor.gold,
          surface: AppColor.background,
          error: const Color(0xFFB42332),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColor.background,
          foregroundColor: AppColor.textPrimary,
          elevation: 0,
          centerTitle: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColor.inputBackground,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColor.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColor.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColor.primary, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColor.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColor.primary,
            side: const BorderSide(color: AppColor.border),
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColor.textPrimary,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      routerConfig: appRouter,
    );
  }
}
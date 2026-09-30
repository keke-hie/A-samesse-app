import 'package:flutter/material.dart';
import '../../../core/constants/app_color.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColor.textPrimary),
        title: Text(
          "A'samesse",
          style: TextStyle(color: AppColor.primary, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insights_outlined, size: 42, color: AppColor.primary),
              const SizedBox(height: 14),
              const Text('Analyses marketing', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColor.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                'Les indicateurs apparaîtront lorsque les comptes des réseaux sociaux seront connectés et transmettront leurs statistiques.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColor.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
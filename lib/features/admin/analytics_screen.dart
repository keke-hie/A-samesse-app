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
        leading: const Icon(Icons.menu, color: Colors.black),
        title: Text(
          "A'samesse",
          style: TextStyle(color: AppColor.primary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Colors.black), onPressed: () {}),
          const CircleAvatar(
            radius: 14,
            backgroundImage: NetworkImage('https://i.pravatar.cc/100'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Analytics", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text("Performance metrics for AI-generated posts over the last 30 days.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),

            // Métriques Clés (Grid)
            _buildMetricCard(icon: Icons.remove_red_eye_outlined, title: "Total Reach", value: "1.2M", growth: "+15% vs last month"),
            const SizedBox(height: 12),
            _buildMetricCard(icon: Icons.touch_app_outlined, title: "Engagement Rate", value: "8.4%", growth: "+2.1% vs last month"),
            const SizedBox(height: 12),
            _buildMetricCard(icon: Icons.shopping_bag_outlined, title: "Conversion Rate", value: "3.2%", growth: "+0.3% vs last month"),

            const SizedBox(height: 20),

            // Section Progression de Campagne
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Campaign Goal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: CircularProgressIndicator(
                            value: 0.75,
                            strokeWidth: 10,
                            backgroundColor: Colors.grey[200],
                            color: AppColor.primary,
                          ),
                        ),
                        const Text("75%", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(child: Text("On track to hit Q3 targets.", style: TextStyle(color: Colors.grey, fontSize: 12))),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Recommendation IA (AI Insight)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: AppColor.primary),
                      const SizedBox(width: 8),
                      const Text("AI Insight", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Based on recent engagement data, your optimal posting window has shifted.",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColor.cardBackground, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        const Text("Best time to post:", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text("Thu, 4:00 PM", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColor.primary)),
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({required IconData icon, required String title, required String value, required String growth}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Icon(icon, color: AppColor.primary, size: 28),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(growth, style: TextStyle(color: AppColor.primary, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
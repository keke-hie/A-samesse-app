import 'package:flutter/material.dart';
import '../../../core/constants/app_color.dart';
import '../../../core/widgets/apple_button.dart';

class MarketingiaScreen extends StatefulWidget {
  const MarketingiaScreen({super.key});

  @override
  State<MarketingiaScreen> createState() => _MarketingiaScreenState();
}

class _MarketingiaScreenState extends State<MarketingiaScreen> {
  int selectedPlatform = 0; // 0: Instagram, 1: TikTok, 2: Facebook

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("A'samesse", style: TextStyle(color: AppColor.primary, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Marketing IA", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text("Créez des campagnes exceptionnelles en un instant.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),

            // Étape 1 : Choix Produit
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("1. CHOISIR LE PRODUIT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 12),
                  ListTile(
                    tileColor: AppColor.cardBackground,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    title: const Text("A'samesse Pro Max", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text("Lancement Collection Été", style: TextStyle(fontSize: 11)),
                    trailing: TextButton(onPressed: () {}, child: const Text("Changer")),
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Étape 2 : Réseaux Sociaux
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("2. RÉSEAUX SOCIAUX", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildSocialBtn(0, "Instagram", Icons.camera_alt_outlined),
                      const SizedBox(width: 8),
                      _buildSocialBtn(1, "TikTok", Icons.videocam_outlined),
                      const SizedBox(width: 8),
                      _buildSocialBtn(2, "Facebook", Icons.public),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),

            AppleButton(
              text: "Générer avec l'IA",
              icon: Icons.bolt,
              onPressed: () {},
            ),

            const SizedBox(height: 24),
            const Text("Prévisualisation des posts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Rendu Post Généré
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      CircleAvatar(radius: 12, backgroundColor: Colors.grey),
                      SizedBox(width: 8),
                      Text("asamesse_official", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network('https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=500', height: 180, width: double.infinity, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Redécouvrez le silence avec la nouvelle collection A'samesse Pro Max. Un design épuré pour une immersion...",
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSocialBtn(int index, String label, IconData icon) {
    final isSelected = selectedPlatform == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedPlatform = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColor.cardBackground : Colors.grey[100],
            border: Border.all(color: isSelected ? AppColor.primary : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppColor.primary : Colors.grey),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }
}
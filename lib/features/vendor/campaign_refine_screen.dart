import 'package:flutter/material.dart';
import '../../../core/constants/app_color.dart';

class CampaignRefineScreen extends StatelessWidget {
  const CampaignRefineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("AI Editor", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColor.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () {},
              child: const Text("Save Post", style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Message IA Initial
                  _buildChatBubble(
                    isAi: true,
                    text: "Hello! I'm ready to help you perfect this post. You can ask me to change the image, rewrite the text, or adjust the mood.",
                    chips: ["Make it punchy", "Change background"],
                  ),
                  const SizedBox(height: 12),

                  // Message Utilisateur
                  _buildChatBubble(
                    isAi: false,
                    text: "Change the background to a sunset beach and make the headline more catchy.",
                  ),
                  const SizedBox(height: 12),

                  // Réponse IA en génération
                  _buildChatBubble(
                    isAi: true,
                    text: "Generating new sunset background & rewriting headline...",
                    isLoading: true,
                  ),
                  const SizedBox(height: 20),

                  // Prévisualisation du rendu généré
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500',
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text("Chase the Sunset, Track the Moments.", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text(
                          "Experience timeless elegance matched with cutting-edge technology. Whether you're unwinding on the shore or pushing your limits, stay connected in style.",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),

          // Champ de Saisie Prompt IA
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Ask AI to modify the post...",
                      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                      filled: true,
                      fillColor: AppColor.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send_rounded, color: AppColor.primary),
                  onPressed: () {},
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChatBubble({required bool isAi, required String text, List<String>? chips, bool isLoading = false}) {
    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isAi ? Colors.white : Colors.brown[700],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isLoading) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                if (isLoading) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(color: isAi ? Colors.black : Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
            if (chips != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: chips.map((c) => Chip(label: Text(c, style: const TextStyle(fontSize: 10)), backgroundColor: AppColor.background)).toList(),
              )
            ]
          ],
        ),
      ),
    );
  }
}
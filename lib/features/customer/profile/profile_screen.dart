import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_color.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoadingImage = false;

  // --- Récupérer les données depuis la table 'utilisateurs' ---
  Future<Map<String, dynamic>?> _getProfilUtilisateur() async {
    final userAuth = _supabase.auth.currentUser;
    if (userAuth == null) return null;

    final response = await _supabase
        .from('utilisateurs')
        .select()
        .eq('id_utilisateur', userAuth.id)
        .maybeSingle();

    if (response == null) return null;

    final buyer = await _supabase
      .from('acheteurs')
      .select('adresse_livraison')
      .eq('id_acheteur', userAuth.id)
      .maybeSingle();

    return {...response, 'adresse_livraison': buyer?['adresse_livraison']};
  }

  // --- Fonction de déconnexion ---
  Future<void> _confirmSignOut() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Déconnexion"),
        content: const Text("Êtes-vous sûr de vouloir vous déconnecter ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Déconnexion", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.auth.signOut();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  // --- Sélectionner et uploader une photo de profil ---
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile == null) return;

    setState(() => _isLoadingImage = true);

    try {
      final userAuth = _supabase.auth.currentUser;
      if (userAuth == null) return;

      final fileBytes = await pickedFile.readAsBytes();
      final fileName = '${userAuth.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'avatars/$fileName';

      // Upload vers Supabase Storage (Assure-toi d'avoir un bucket nommé 'avatars' dans Supabase)
      await _supabase.storage.from('avatars').uploadBinary(
            filePath,
            fileBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      // Récupérer l'URL publique
      final imageUrl = _supabase.storage.from('avatars').getPublicUrl(filePath);

      // Mettre à jour la table utilisateurs
      await _supabase.from('utilisateurs').update({
        'avatar_url': imageUrl,
      }).eq('id_utilisateur', userAuth.id);

      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Photo de profil mise à jour avec succès !")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'upload : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingImage = false);
    }
  }

  // --- Formulaire complet de modification du profil ---
  void _showEditProfileDialog(Map<String, dynamic>? data) {
    final nameController = TextEditingController(text: data?['nom'] ?? '');
    final phoneController = TextEditingController(text: data?['telephone'] ?? '');
    final adresseController = TextEditingController(text: data?['adresse_livraison'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Modifier mon profil complet"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Nom complet",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "Numéro de téléphone",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: adresseController,
                decoration: InputDecoration(
                  labelText: "Adresse de livraison",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColor.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final userAuth = _supabase.auth.currentUser;
              if (userAuth != null) {
                try {
                  // 1. Mise à jour dans Supabase
                  await _supabase.from('utilisateurs').update({
                    'nom': nameController.text.trim(),
                    'telephone': phoneController.text.trim(),
                  }).eq('id_utilisateur', userAuth.id);
                  await _supabase.from('acheteurs').update({
                    'adresse_livraison': adresseController.text.trim(),
                  }).eq('id_acheteur', userAuth.id);

                  // 2. Fermer la boîte de dialogue proprement
                  if (mounted) Navigator.pop(context);

                  // 3. Rafraîchir l'écran pour recharger le FutureBuilder
                  setState(() {});

                  // 4. Afficher le message de succès
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Profil mis à jour avec succès !")),
                    );
                  }
                } catch (e) {
                  // En cas d'erreur (ex: problème de RLS ou de connexion)
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            child: const Text("Enregistrer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- Modal Moyens de Paiement (Mobile Money + Carte Bancaire) ---
  void _showPaymentMethodsModal(String phone) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Moyens de Paiement Enregistrés",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.phone_android, color: Colors.orange),
              title: const Text("Mobile Money (Orange & MTN)"),
              subtitle: Text(phone.isNotEmpty ? phone : "Aucun numéro lié"),
              trailing: const Icon(Icons.check_circle, color: Colors.green),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.credit_card, color: Colors.blue),
              title: const Text("Carte Bancaire / Compte Bancaire"),
              subtitle: const Text("Ajouter une carte ou un compte"),
              trailing: IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.black),
                onPressed: () {
                  Navigator.pop(context);
                  _showAddCardDialog();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Dialogue d'ajout de carte bancaire ---
  void _showAddCardDialog() {
    final cardController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ajouter une Carte Bancaire"),
        content: TextField(
          controller: cardController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Numéro de carte",
            hintText: "XXXX XXXX XXXX XXXX",
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColor.primary),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Carte bancaire enregistrée avec succès !")),
              );
            },
            child: const Text("Ajouter", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- Modal Paramètres & Notifications ---
  void _showSettingsModal() {
    bool notifEnabled = true;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Paramètres de l'application",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text("Notifications de commande"),
                subtitle: const Text("Activer le suivi en temps réel"),
                value: notifEnabled,
                activeThumbColor: AppColor.primary,
                onChanged: (val) {
                  setModalState(() => notifEnabled = val);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text("Langue"),
                trailing: const Text(
                  "Français",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("L'application est configurée en Français.")),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Modal Signaler un Litige ---
  Future<void> _showDisputeModal() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    List<Map<String, dynamic>> orders;
    try {
      final response = await _supabase
          .from('commandes')
          .select('id_commande, montant_total, date_commande')
          .eq('id_acheteur', user.id)
          .order('date_commande', ascending: false);
      orders = List<Map<String, dynamic>>.from(response);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chargement des commandes impossible : $error')),
        );
      }
      return;
    }

    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune commande à associer au litige.')),
      );
      return;
    }

    final descriptionController = TextEditingController();
    final reasons = ['Commande non reçue', 'Article endommagé', 'Article non conforme', 'Problème de paiement', 'Autre'];
    String selectedOrderId = orders.first['id_commande'].toString();
    String selectedReason = reasons.first;
    XFile? evidence;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Signaler un litige'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedOrderId,
                  decoration: const InputDecoration(labelText: 'Commande'),
                  items: orders.map((order) {
                    final orderId = order['id_commande'].toString();
                    return DropdownMenuItem(
                      value: orderId,
                      child: Text('Commande ${orderId.substring(0, 8).toUpperCase()}'),
                    );
                  }).toList(),
                  onChanged: isSubmitting ? null : (value) {
                    if (value != null) setDialogState(() => selectedOrderId = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  decoration: const InputDecoration(labelText: 'Motif'),
                  items: reasons.map((reason) => DropdownMenuItem(value: reason, child: Text(reason))).toList(),
                  onChanged: isSubmitting ? null : (value) {
                    if (value != null) setDialogState(() => selectedReason = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Détails',
                    hintText: 'Explique le problème rencontré.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: isSubmitting ? null : () async {
                    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75);
                    if (picked != null) setDialogState(() => evidence = picked);
                  },
                  icon: const Icon(Icons.attach_file),
                  label: Text(evidence?.name ?? 'Joindre une preuve (image)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: isSubmitting ? null : () async {
                final description = descriptionController.text.trim();
                if (description.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Décris le problème avant d’envoyer le dossier.')),
                  );
                  return;
                }

                setDialogState(() => isSubmitting = true);
                try {
                  final dispute = await _supabase.from('litiges').insert({
                    'id_commande': selectedOrderId,
                    'id_acheteur': user.id,
                    'motif': selectedReason,
                    'description': description,
                  }).select('id_litige').single();

                  if (evidence != null) {
                    final extension = evidence!.name.split('.').last.toLowerCase();
                    final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';
                    final path = '${user.id}/${dispute['id_litige']}/${DateTime.now().millisecondsSinceEpoch}.$extension';
                    await _supabase.storage.from('preuves-litiges').uploadBinary(
                      path,
                      await evidence!.readAsBytes(),
                      fileOptions: FileOptions(contentType: contentType),
                    );
                    await _supabase.from('litiges').update({'preuves': [path]}).eq('id_litige', dispute['id_litige']);
                  }

                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Le litige est enregistré pour examen par l’administration.')),
                  );
                } catch (error) {
                  if (dialogContext.mounted) {
                    setDialogState(() => isSubmitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Envoi du litige impossible : $error')),
                    );
                  }
                }
              },
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Envoyer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ],
      ),
    );
    descriptionController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAuth = _supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: AppColor.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Mon Profil",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black),
            onPressed: _showSettingsModal,
          )
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getProfilUtilisateur(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data;
          final String nom = data?['nom'] ?? 'Acheteur';
          final String email = data?['email'] ?? userAuth?.email ?? '';
          final String telephone = data?['telephone'] ?? '';
          final String role = data?['role'] ?? 'acheteur';
          final String? avatarUrl = data?['avatar_url'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // En-tête Profil avec avatar cliquable
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: _pickAndUploadImage,
                            child: CircleAvatar(
                              radius: 32,
                              backgroundColor: AppColor.primary.withValues(alpha: 0.1),
                              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: avatarUrl == null || avatarUrl.isEmpty
                                  ? Text(
                                      nom.isNotEmpty ? nom[0].toUpperCase() : 'A',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: AppColor.primary,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColor.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  nom,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColor.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    role.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColor.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            if (telephone.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                telephone,
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: AppColor.primary, size: 20),
                        onPressed: () => _showEditProfileDialog(data),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Section Mon Compte
                _buildSectionHeader("Mon Compte"),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildProfileMenuItem(
                        icon: Icons.shopping_bag_outlined,
                        title: "Mes Commandes",
                        subtitle: "Suivi et historique de vos achats",
                        onTap: () => context.push('/orders'),
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildProfileMenuItem(
                        icon: Icons.favorite_border,
                        title: "Liste de souhaits",
                        subtitle: "Articles enregistrés avec le cœur",
                        onTap: () => context.push('/home'), // Redirection vers le catalogue
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildProfileMenuItem(
                        icon: Icons.phone_android_outlined,
                        title: "Moyens de paiement",
                        subtitle: "Mobile Money & Carte Bancaire",
                        onTap: () => _showPaymentMethodsModal(telephone),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Section Préférences & Support
                _buildSectionHeader("Préférences & Support"),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildProfileMenuItem(
                        icon: Icons.notifications_none_outlined,
                        title: "Notifications",
                        subtitle: "Suivi des commandes activé",
                        onTap: _showSettingsModal,
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildProfileMenuItem(
                        icon: Icons.report_problem_outlined,
                        title: "Signaler un litige",
                        subtitle: "Réclamations et assistance",
                        onTap: _showDisputeModal,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Bouton Déconnexion
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFD1D1)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _confirmSignOut,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.power_settings_new_rounded,
                            color: Colors.redAccent,
                            size: 22,
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Se déconnecter",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }
}
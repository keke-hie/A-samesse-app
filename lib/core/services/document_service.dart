import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'session_service.dart';

enum DocumentType {
  idCard('cni', 'Carte nationale d’identité'),
  activityProof('preuve_activite', 'Photo de la boutique ou du stock'),
  license('permis', 'Permis de conduire'),
  taxCertificate('contribuable', 'Attestation de contribuable');

  const DocumentType(this.value, this.label);

  final String value;
  final String label;

  static DocumentType? parse(String? value) {
    for (final type in values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

class RequiredDocument {
  const RequiredDocument(this.type, {this.optional = false, this.label});

  final DocumentType type;
  final bool optional;
  final String? label;

  String get displayLabel => label ?? type.label;
}

/// Pièces justificatives stockées dans le bucket privé `documents`,
/// toujours sous `<id utilisateur>/…` (voir la migration de validation des comptes).
class DocumentService {
  DocumentService([SupabaseClient? client])
    : _supabase = client ?? Supabase.instance.client;

  static const _bucket = 'documents';
  final SupabaseClient _supabase;

  List<RequiredDocument> requiredFor(SessionService session) {
    if (session.isCourier) {
      return const [
        RequiredDocument(DocumentType.idCard),
        RequiredDocument(DocumentType.license),
      ];
    }
    final saleType = session.user?.userMetadata?['type_vente']?.toString();
    final isShop = saleType != 'occasionnel';
    return [
      const RequiredDocument(DocumentType.idCard),
      RequiredDocument(
        DocumentType.activityProof,
        label: isShop ? 'Photo de la boutique' : 'Photo du stock',
      ),
      if (isShop)
        const RequiredDocument(DocumentType.taxCertificate, optional: true),
    ];
  }

  /// Pièces déjà envoyées par l'utilisateur courant (ou par [userId] pour un admin).
  Future<Map<DocumentType, Map<String, dynamic>>> fetchDocuments({
    String? userId,
  }) async {
    final id = userId ?? _supabase.auth.currentUser?.id;
    if (id == null) return {};
    final rows = await _supabase
        .from('pieces_justificatives')
        .select()
        .eq('id_utilisateur', id);
    return {
      for (final row in rows)
        ?DocumentType.parse(row['type_piece']?.toString()): row,
    };
  }

  Future<void> upload(DocumentType type, XFile file) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Connecte-toi pour envoyer tes pièces.');
    }

    final extension = file.name.split('.').last.toLowerCase();
    final contentType = switch (extension) {
      'png' => 'image/png',
      'pdf' => 'application/pdf',
      _ => 'image/jpeg',
    };
    final path =
        '$userId/${type.value}_${DateTime.now().millisecondsSinceEpoch}.$extension';

    await _supabase.storage
        .from(_bucket)
        .uploadBinary(
          path,
          await file.readAsBytes(),
          fileOptions: FileOptions(contentType: contentType),
        );
    await _supabase.from('pieces_justificatives').upsert({
      'id_utilisateur': userId,
      'type_piece': type.value,
      'chemin': path,
      'date_envoi': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'id_utilisateur,type_piece');
  }

  /// Lien temporaire (10 min) : le bucket est privé.
  Future<String> signedUrl(String path) =>
      _supabase.storage.from(_bucket).createSignedUrl(path, 600);
}

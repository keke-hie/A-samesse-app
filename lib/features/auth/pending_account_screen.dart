import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_color.dart';
import '../../core/services/document_service.dart';
import '../../core/services/session_service.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/formatters.dart';

/// Écran des comptes vendeur / livreur non encore validés : dépôt des pièces
/// justificatives et suivi de la validation par un administrateur.
class PendingAccountScreen extends StatefulWidget {
  const PendingAccountScreen({super.key});

  @override
  State<PendingAccountScreen> createState() => _PendingAccountScreenState();
}

class _PendingAccountScreenState extends State<PendingAccountScreen> {
  final _session = SessionService.instance;
  final _documentService = DocumentService();
  late Future<Map<DocumentType, Map<String, dynamic>>> _documentsFuture =
      _documentService.fetchDocuments();
  DocumentType? _uploading;
  bool _refreshing = false;

  Future<void> _upload(DocumentType type) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 2000,
    );
    if (file == null) return;
    setState(() => _uploading = type);
    try {
      await _documentService.upload(type, file);
      if (!mounted) return;
      setState(() => _documentsFuture = _documentService.fetchDocuments());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pièce envoyée.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  Future<void> _checkStatus() async {
    setState(() => _refreshing = true);
    // Si le compte est validé, le routeur redirige automatiquement vers l'espace pro.
    await _session.refresh();
    if (!mounted) return;
    setState(() => _refreshing = false);
    if (!_session.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ton compte n’est pas encore validé.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final refused = _session.status == AccountStatus.refused;
    final suspended = _session.status == AccountStatus.suspended;
    final required = _documentService.requiredFor(_session);

    return Scaffold(
      appBar: AppBar(
        title: Text(_session.isCourier ? 'Compte livreur' : 'Compte vendeur'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _session.signOut,
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Icon(
            refused || suspended
                ? Icons.report_gmailerrorred_rounded
                : Icons.hourglass_top_rounded,
            size: 48,
            color: refused || suspended ? AppColor.danger : AppColor.primary,
          ),
          const SizedBox(height: 14),
          Text(
            refused
                ? 'Ton inscription a été refusée'
                : suspended
                ? 'Ton compte est suspendu'
                : 'Ton compte est en cours de validation',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            refused || suspended
                ? (_session.refusalReason?.isNotEmpty ?? false)
                      ? 'Motif : ${_session.refusalReason}'
                      : 'Contacte le support A’samesse pour en savoir plus.'
                : 'Envoie les pièces ci-dessous. Un administrateur les vérifiera '
                      'puis activera ton espace.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColor.textSecondary),
          ),
          const SizedBox(height: 24),
          Text(
            'Pièces justificatives',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Elles restent privées : seuls les administrateurs y ont accès.',
            style: TextStyle(fontSize: 12, color: AppColor.textSecondary),
          ),
          const SizedBox(height: 12),
          FutureBuilder<Map<DocumentType, Map<String, dynamic>>>(
            future: _documentsFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(friendlyError(snapshot.error!));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final sent = snapshot.data!;
              return Column(
                children: [
                  for (final document in required)
                    _DocumentTile(
                      document: document,
                      sentAt: sent[document.type]?['date_envoi'],
                      isUploading: _uploading == document.type,
                      onUpload: _uploading == null
                          ? () => _upload(document.type)
                          : null,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _refreshing ? null : _checkStatus,
            icon: _refreshing
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            label: const Text('Vérifier mon statut'),
          ),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.document,
    required this.sentAt,
    required this.isUploading,
    required this.onUpload,
  });

  final RequiredDocument document;
  final dynamic sentAt;
  final bool isUploading;
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    final isSent = sentAt != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          isSent ? Icons.check_circle_rounded : Icons.upload_file_rounded,
          color: isSent ? AppColor.success : AppColor.primary,
        ),
        title: Text(
          document.optional
              ? '${document.displayLabel} (facultatif)'
              : document.displayLabel,
        ),
        subtitle: Text(
          isSent ? 'Envoyée le ${formatDate(sentAt)}' : 'À envoyer',
        ),
        trailing: isUploading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: onUpload,
                child: Text(isSent ? 'Remplacer' : 'Ajouter'),
              ),
      ),
    );
  }
}

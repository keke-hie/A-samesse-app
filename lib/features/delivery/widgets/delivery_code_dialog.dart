import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/delivery_service.dart';
import '../../../core/utils/error_message.dart';

/// Saisie du code à 6 chiffres donné par le client à la remise du colis.
/// Renvoie `true` si la livraison est confirmée.
Future<bool?> showDeliveryCodeDialog(BuildContext context, String deliveryId) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _DeliveryCodeDialog(deliveryId: deliveryId),
  );
}

class _DeliveryCodeDialog extends StatefulWidget {
  const _DeliveryCodeDialog({required this.deliveryId});

  final String deliveryId;

  @override
  State<_DeliveryCodeDialog> createState() => _DeliveryCodeDialogState();
}

class _DeliveryCodeDialogState extends State<_DeliveryCodeDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Le code contient 6 chiffres.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final ok = await DeliveryService().confirmWithCode(
        widget.deliveryId,
        code,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _submitting = false;
          _error = 'Code incorrect. Après 5 erreurs, la livraison est bloquée.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = friendlyError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmer la remise'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Demande au client le code affiché dans son application.'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 8,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(counterText: '', errorText: _error),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Valider'),
        ),
      ],
    );
  }
}

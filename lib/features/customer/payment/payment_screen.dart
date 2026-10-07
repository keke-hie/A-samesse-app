import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_color.dart';
import '../../../core/models/order_status.dart';
import '../../../core/services/order_service.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';

enum PaymentMethod {
  orangeMoney(
    'orange_money',
    'Orange Money',
    Icons.phone_android_rounded,
    Color(0xFFFF7900),
  ),
  mobileMoney(
    'mobile_money',
    'MTN MoMo',
    Icons.phone_android_rounded,
    Color(0xFFE0A800),
  ),
  card(
    'card',
    'Carte bancaire',
    Icons.credit_card_rounded,
    AppColor.textPrimary,
  );

  const PaymentMethod(this.value, this.label, this.icon, this.color);

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  bool get isMobileMoney => this != card;

  static PaymentMethod parse(dynamic value) => values.firstWhere(
    (method) => method.value == value,
    orElse: () => orangeMoney,
  );
}

/// Paiement **simulé** d'une commande (démonstration) : reproduit le parcours
/// Mobile Money / carte sans débiter d'argent, puis passe la commande à
/// « payée » via la fonction SQL `simulate_payment`.
///
/// Aucune donnée saisie (numéro, code, carte) n'est envoyée ni enregistrée.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

enum _Step { form, processing, success }

class _PaymentScreenState extends State<PaymentScreen> {
  /// Code secret qui simule un paiement refusé (pour montrer le cas d'erreur).
  static const _declineCode = '0000';

  final _orderService = OrderService();
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _cardController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();

  late Future<Map<String, dynamic>?> _orderFuture = _orderService.fetchOrder(
    widget.orderId,
  );
  PaymentMethod? _method;
  _Step _step = _Step.form;
  String _processingLabel = '';
  String? _reference;

  @override
  void dispose() {
    _phoneController.dispose();
    _cardController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    super.dispose();
  }

  Future<void> _pay(num amount) async {
    if (!_formKey.currentState!.validate()) return;
    final method = _method!;

    if (method.isMobileMoney) {
      final pin = await _askPin(method, amount);
      if (pin == null) return;
      await _process([
        'Connexion à ${method.label}…',
        'Demande envoyée au ${_phoneController.text.trim()}…',
        'Validation du paiement…',
      ], declined: pin == _declineCode);
    } else {
      await _process([
        'Connexion à la banque…',
        'Vérification 3-D Secure…',
        'Autorisation du paiement…',
      ], declined: _cvcController.text == '000');
    }
  }

  Future<void> _process(List<String> steps, {required bool declined}) async {
    setState(() => _step = _Step.processing);
    for (final label in steps) {
      if (!mounted) return;
      setState(() => _processingLabel = label);
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
    if (!mounted) return;

    if (declined) {
      setState(() => _step = _Step.form);
      _showMessage(
        'Paiement refusé (simulation). Réessaie avec un autre code.',
      );
      return;
    }

    try {
      final reference = await _orderService.simulatePayment(
        widget.orderId,
        _method!.value,
      );
      if (!mounted) return;
      setState(() {
        _reference = reference;
        _step = _Step.success;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _step = _Step.form);
      _showMessage(friendlyError(error));
      setState(() => _orderFuture = _orderService.fetchOrder(widget.orderId));
    }
  }

  Future<String?> _askPin(PaymentMethod method, num amount) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.lock_rounded, color: method.color),
        title: Text('Confirmation ${method.label}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Paiement de ${formatPrice(amount)} à A’samesse.\n'
              'Saisis ton code secret pour valider.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              maxLength: 4,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 24, letterSpacing: 10),
              decoration: const InputDecoration(
                counterText: '',
                hintText: '••••',
              ),
            ),
            const Text(
              'Simulation : n’importe quel code à 4 chiffres (0000 = refusé).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColor.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.length == 4) {
                Navigator.pop(dialogContext, controller.text);
              }
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step != _Step.processing,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: _step == _Step.form
              ? BackButton(onPressed: () => context.go('/orders'))
              : null,
          title: const Text('Paiement'),
        ),
        body: FutureBuilder<Map<String, dynamic>?>(
          future: _orderFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Commande introuvable',
                message: friendlyError(snapshot.error!),
                actionLabel: 'Mes commandes',
                onAction: () => context.go('/orders'),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final order = snapshot.data;
            if (order == null) {
              return EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Commande introuvable',
                actionLabel: 'Mes commandes',
                onAction: () => context.go('/orders'),
              );
            }
            _method ??= PaymentMethod.parse(order['mode_paiement']);
            final amount = parseAmount(order['montant_total']) ?? 0;

            return switch (_step) {
              _Step.success => _SuccessView(
                amount: amount,
                reference: _reference ?? '',
                method: _method!,
              ),
              _Step.processing => _ProcessingView(
                label: _processingLabel,
                method: _method!,
              ),
              _Step.form =>
                OrderStatus.parse(order['statut']) !=
                        OrderStatus.awaitingPayment
                    ? EmptyState(
                        icon: Icons.task_alt_rounded,
                        title: 'Cette commande est déjà réglée',
                        actionLabel: 'Suivre ma commande',
                        onAction: () => context.go('/orders'),
                      )
                    : _buildForm(order, amount),
            };
          },
        ),
      ),
    );
  }

  Widget _buildForm(Map<String, dynamic> order, num amount) {
    final method = _method!;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColor.goldLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColor.gold),
            ),
            child: const Row(
              children: [
                Icon(Icons.science_outlined, color: AppColor.goldDark),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mode démonstration : aucun argent n’est débité et aucune '
                    'donnée saisie n’est enregistrée.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Montant à payer',
                    style: TextStyle(color: AppColor.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatPrice(amount),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColor.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Commande ${shortOrderRef(order['id_commande'])}',
                    style: const TextStyle(color: AppColor.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Moyen de paiement',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          for (final option in PaymentMethod.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: option == method
                        ? AppColor.primary
                        : AppColor.border,
                    width: option == method ? 1.5 : 1,
                  ),
                ),
                child: ListTile(
                  leading: Icon(option.icon, color: option.color),
                  title: Text(
                    option.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: Icon(
                    option == method
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: option == method
                        ? AppColor.primary
                        : AppColor.textMuted,
                  ),
                  onTap: () => setState(() => _method = option),
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (method.isMobileMoney)
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              decoration: InputDecoration(
                labelText: 'Numéro ${method.label}',
                prefixText: '+237 ',
                hintText: '6XXXXXXXX',
              ),
              validator: (value) => RegExp(r'^6\d{8}$').hasMatch(value ?? '')
                  ? null
                  : 'Numéro camerounais à 9 chiffres commençant par 6',
            )
          else ...[
            TextFormField(
              controller: _cardController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(16),
              ],
              decoration: const InputDecoration(
                labelText: 'Numéro de carte',
                helperText: 'Carte de test : 4242 4242 4242 4242',
              ),
              validator: (value) => (value ?? '').length == 16
                  ? null
                  : 'Le numéro contient 16 chiffres',
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _expiryController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Expiration',
                      hintText: 'MMAA',
                    ),
                    validator: (value) {
                      final text = value ?? '';
                      final month = int.tryParse(
                        text.length >= 2 ? text.substring(0, 2) : '',
                      );
                      return text.length == 4 &&
                              month != null &&
                              month >= 1 &&
                              month <= 12
                          ? null
                          : 'MMAA';
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cvcController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'CVC',
                      helperText: '000 = refusé',
                    ),
                    validator: (value) =>
                        (value ?? '').length == 3 ? null : '3 chiffres',
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          PrimaryButton(
            text: 'Payer ${formatPrice(amount)}',
            icon: Icons.lock_outline_rounded,
            onPressed: () => _pay(amount),
          ),
        ],
      ),
    );
  }
}

class _ProcessingView extends StatelessWidget {
  const _ProcessingView({required this.label, required this.method});

  final String label;
  final PaymentMethod method;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 64,
              child: CircularProgressIndicator(
                strokeWidth: 5,
                color: method.color,
              ),
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                label,
                key: ValueKey(label),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ne ferme pas cette page.',
              style: TextStyle(color: AppColor.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({
    required this.amount,
    required this.reference,
    required this.method,
  });

  final num amount;
  final String reference;
  final PaymentMethod method;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColor.successSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 56,
                color: AppColor.success,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Paiement accepté',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${formatPrice(amount)} payés par ${method.label}.\n'
              'Le vendeur va préparer ta commande.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColor.textSecondary),
            ),
            const SizedBox(height: 12),
            SelectableText(
              'Référence : $reference',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              text: 'Suivre ma commande',
              onPressed: () => context.go('/orders'),
            ),
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('Continuer mes achats'),
            ),
          ],
        ),
      ),
    );
  }
}

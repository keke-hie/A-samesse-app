import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_color.dart';
import '../../../core/services/session_service.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/product_image.dart';
import 'widgets/create_deal_sheet.dart';

class DealsScreen extends StatefulWidget {
  const DealsScreen({super.key});

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  final _supabase = Supabase.instance.client;
  late final Stream<List<Map<String, dynamic>>> _dealsStream = _supabase
      .from('ventes_ephemeres')
      .stream(primaryKey: ['id_vente_ephemere'])
      .eq('statut', 'actif')
      .order('date_fin', ascending: true);

  /// Produits des ventes affichées, chargés à la demande.
  final Map<String, Map<String, dynamic>> _products = {};
  final Set<String> _loadingProducts = {};

  bool get _canCreate {
    final session = SessionService.instance;
    return session.isVendor && session.isActive;
  }

  Future<void> _loadProducts(Iterable<String> ids) async {
    final missing = ids
        .where((id) => !_products.containsKey(id) && !_loadingProducts.contains(id))
        .toList();
    if (missing.isEmpty) return;
    _loadingProducts.addAll(missing);
    try {
      final rows = await _supabase
          .from('produits')
          .select('id_produit, nom_produit, prix, image_url')
          .inFilter('id_produit', missing);
      if (!mounted) return;
      setState(() {
        for (final row in rows) {
          _products[row['id_produit'].toString()] = row;
        }
      });
    } catch (_) {
      // Les cartes restent affichées sans photo.
    } finally {
      _loadingProducts.removeAll(missing);
    }
  }

  Future<void> _createDeal() async {
    final created = await showCreateDealSheet(context);
    if (created == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vente publiée !')));
    }
  }

  void _share(Map<String, dynamic> deal) {
    final type = deal['type_vente']?.toString() ?? 'Vente flash';
    final name = deal['nom_vente']?.toString().trim();
    Share.share(
      '🔥 ${name?.isNotEmpty == true ? name : type} sur A’samesse : '
      'https://asamesse.app/produit/${deal['id_produit']}',
      subject: '$type sur A’samesse',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ventes éphémères')),
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              onPressed: _createDeal,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouvelle vente'),
            )
          : null,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _dealsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Impossible de charger les ventes',
              message: friendlyError(snapshot.error!),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          // Le flux temps réel ne filtre pas sur l'heure : on retire les ventes terminées.
          final now = DateTime.now();
          final deals = snapshot.data!.where((deal) {
            final end = DateTime.tryParse(deal['date_fin']?.toString() ?? '');
            return end != null && end.isAfter(now);
          }).toList();
          if (deals.isEmpty) {
            return const EmptyState(
              icon: Icons.bolt_outlined,
              title: 'Aucune vente en cours',
              message: 'Reviens bientôt : les ventes flash et vide-dressings apparaissent ici.',
            );
          }
          _loadProducts(deals.map((deal) => deal['id_produit'].toString()));

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            itemCount: deals.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _CountdownBanner(
                  endsAt: DateTime.parse(deals.first['date_fin'].toString()),
                  title: deals.first['nom_vente']?.toString(),
                );
              }
              final deal = deals[index - 1];
              return _DealCard(
                deal: deal,
                product: _products[deal['id_produit'].toString()],
                onShare: () => _share(deal),
              );
            },
          );
        },
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  const _DealCard({required this.deal, required this.product, required this.onShare});

  final Map<String, dynamic> deal;
  final Map<String, dynamic>? product;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final type = deal['type_vente']?.toString() ?? 'Vente Flash';
    final name = deal['nom_vente']?.toString().trim() ?? '';
    final productName = product?['nom_produit']?.toString() ?? 'Produit';
    final productId = deal['id_produit']?.toString();
    final basePrice = parseAmount(product?['prix']);
    final promoPrice = parseAmount(deal['prix_promo']);
    final discount = basePrice != null && promoPrice != null && basePrice > 0
        ? ((1 - promoPrice / basePrice) * 100).round()
        : null;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: productId == null ? null : () => context.push('/home/product/$productId'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductImage(url: product?['image_url']?.toString()),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Chip(
                      label: Text(type == 'Vide Dressing' ? 'Vide-dressing' : 'Vente flash'),
                      backgroundColor: AppColor.primary,
                      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      side: BorderSide.none,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: IconButton.filledTonal(
                      tooltip: 'Partager',
                      onPressed: onShare,
                      icon: const Icon(Icons.share_outlined),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? productName : name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (name.isNotEmpty)
                    Text(productName, style: const TextStyle(color: AppColor.textSecondary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        formatPrice(promoPrice),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColor.primary,
                        ),
                      ),
                      if (basePrice != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          formatPrice(basePrice),
                          style: const TextStyle(
                            color: AppColor.textMuted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (discount != null && discount > 0)
                        Text(
                          '-$discount %',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColor.success,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Jusqu’au ${formatDate(deal['date_fin'], withTime: true)}',
                    style: const TextStyle(fontSize: 12, color: AppColor.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Décompte de la vente qui se termine le plus tôt (seul ce widget se
/// reconstruit chaque seconde).
class _CountdownBanner extends StatefulWidget {
  const _CountdownBanner({required this.endsAt, this.title});

  final DateTime endsAt;
  final String? title;

  @override
  State<_CountdownBanner> createState() => _CountdownBannerState();
}

class _CountdownBannerState extends State<_CountdownBanner> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.endsAt.difference(DateTime.now());
    final safe = remaining.isNegative ? Duration.zero : remaining;
    String two(int value) => value.toString().padLeft(2, '0');

    return Card(
      margin: EdgeInsets.zero,
      color: AppColor.primary,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: AppColor.gold, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title?.trim().isNotEmpty == true
                        ? widget.title!.trim()
                        : 'Prochaine fin de vente',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    safe.inDays >= 1
                        ? 'Se termine dans ${safe.inDays} j ${safe.inHours % 24} h'
                        : '${two(safe.inHours)} : ${two(safe.inMinutes % 60)} : ${two(safe.inSeconds % 60)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../constants/app_color.dart';

/// Photo produit (réseau ou asset) avec placeholder homogène.
class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.url, this.fit = BoxFit.cover});

  final String? url;
  final BoxFit fit;

  static String? urlOf(Map<String, dynamic> product) =>
      (product['image_url'] ?? product['images'])?.toString();

  @override
  Widget build(BuildContext context) {
    final value = url?.trim() ?? '';
    if (value.isEmpty) return const _Placeholder();
    if (value.startsWith('assets/')) {
      return Image.asset(
        value,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => const _Placeholder(),
      );
    }
    return Image.network(
      value,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const _Placeholder(loading: true),
      errorBuilder: (_, _, _) => const _Placeholder(),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColor.primarySoft,
      child: Center(
        child: loading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(
                Icons.image_outlined,
                color: AppColor.primaryLight,
                size: 30,
              ),
      ),
    );
  }
}

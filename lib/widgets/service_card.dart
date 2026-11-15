import 'package:flutter/material.dart';

import '../models/service.dart';
import '../utils/formatters.dart';
import 'rating_widget.dart';

IconData iconForCategory(String category) {
  final c = category.toLowerCase();
  if (c.contains('football') || c.contains('turf')) return Icons.sports_soccer;
  if (c.contains('cricket')) return Icons.sports_cricket;
  if (c.contains('badminton') || c.contains('tennis')) return Icons.sports_tennis;
  if (c.contains('gaming') || c.contains('game')) return Icons.sports_esports;
  if (c.contains('swim')) return Icons.pool;
  return Icons.storefront;
}

class ServiceImage extends StatelessWidget {
  const ServiceImage({super.key, required this.service, this.height = 140});
  final Service service;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      height: height,
      width: double.infinity,
      color: scheme.primaryContainer,
      child: Icon(
        iconForCategory(service.category),
        size: height * 0.4,
        color: scheme.onPrimaryContainer,
      ),
    );
    final url = service.imageUrl;
    if (url == null || url.isEmpty) return placeholder;
    return Image.network(
      url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}

class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.service, this.onTap, this.trailing});

  final Service service;
  final VoidCallback? onTap;

  /// Shown under the details, e.g. vendor actions.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ServiceImage(service: service, height: 120),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          service.name,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      RatingSummary(average: service.averageRating, count: service.reviewCount),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 16, color: theme.colorScheme.outline),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          service.location,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(service.category, style: theme.textTheme.labelMedium),
                      const Spacer(),
                      Text(
                        '${formatPrice(service.pricePerSlot)} / slot',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  if (trailing != null) ...[const SizedBox(height: 8), trailing!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

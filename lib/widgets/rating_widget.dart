import 'package:flutter/material.dart';

/// Five stars. Pass [onChanged] to make it tappable.
class RatingWidget extends StatelessWidget {
  const RatingWidget({super.key, required this.rating, this.size = 20, this.onChanged});

  final int rating;
  final double size;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final star = Icon(
          index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          color: Colors.amber.shade700,
          size: size,
        );
        if (onChanged == null) return star;
        return Semantics(
          button: true,
          label: '${index + 1} star${index == 0 ? '' : 's'}',
          child: InkResponse(
            onTap: () => onChanged!(index + 1),
            radius: size,
            child: Padding(padding: const EdgeInsets.all(4), child: star),
          ),
        );
      }),
    );
  }
}

/// "★ 4.5 (12)" or "New".
class RatingSummary extends StatelessWidget {
  const RatingSummary({super.key, this.average, required this.count});
  final double? average;
  final int count;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    if (average == null || count == 0) {
      return Text('New', style: style?.copyWith(fontWeight: FontWeight.w600));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade700),
        const SizedBox(width: 2),
        Text(average!.toStringAsFixed(1), style: style?.copyWith(fontWeight: FontWeight.w600)),
        Text(' ($count)', style: style),
      ],
    );
  }
}

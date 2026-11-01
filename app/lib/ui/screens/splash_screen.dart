import 'package:flutter/material.dart';

import '../brand.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandMark(size: 104),
          const SizedBox(height: 22),
          const Wordmark(tagline: true),
          const SizedBox(height: 34),
          const WaitingDots(),
          const SizedBox(height: 14),
          Text(
            'Opening the door…',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Title row for Route Packs screen.
/// Displays "ROUTE PACKS" overline and "Route Packs" title.
class RoutePacksTitleWidget extends StatelessWidget {
  const RoutePacksTitleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ROUTE PACKS',
          style: AppTextStyles.overline,
        ),
        const SizedBox(height: 4),
        Text(
          'Route Packs',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.title,
        ),
      ],
    );
  }
}

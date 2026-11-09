import 'package:flutter/material.dart';

import 'service_visit_card_widget.dart';

/// Legacy alias for [ServiceVisitCardWidget].
class PitstopCardWidget extends StatelessWidget {
  const PitstopCardWidget({
    super.key,
    this.dateLabel = 'Oct 18, 10:00 AM',
    this.locationLabel = 'Peak Moto Dealership & Prep • Denver, CO',
    this.onCallDealer,
    this.onDirections,
  });

  final String dateLabel;
  final String locationLabel;
  final VoidCallback? onCallDealer;
  final VoidCallback? onDirections;

  @override
  Widget build(BuildContext context) {
    return const ServiceVisitCardWidget();
  }
}

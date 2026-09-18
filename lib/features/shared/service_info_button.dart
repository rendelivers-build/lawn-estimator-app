/// Info bubble explaining what a service is and how often it's done.
///
/// Shared by the materials screen and the pricing settings screen.
library;

import 'package:flutter/material.dart';

import 'package:lawn_estimator/core/pricing_catalog.dart';

/// Small (i) button; tapping it shows a dialog with the service's blurb
/// and typical frequency.
Future<bool> showServiceInfo(BuildContext context, String serviceId) async {
  final info = serviceInfo(serviceId);
  if (info == null) return false;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(info.label),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(info.blurb),
          const SizedBox(height: 12),
          Text(
            'How often',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(info.frequency),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
  return true;
}

/// Small (i) button; tapping it shows a dialog with the service's blurb
/// and typical frequency.
class ServiceInfoButton extends StatelessWidget {
  final String serviceId;

  const ServiceInfoButton({super.key, required this.serviceId});

  @override
  Widget build(BuildContext context) {
    final info = serviceInfo(serviceId);
    if (info == null) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.info_outline, size: 20),
      tooltip: 'About ${info.label}',
      visualDensity: VisualDensity.compact,
      onPressed: () => showServiceInfo(context, serviceId),
    );
  }
}

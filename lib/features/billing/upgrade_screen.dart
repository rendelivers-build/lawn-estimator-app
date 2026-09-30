import 'package:flutter/material.dart';
import 'package:lawn_estimator/features/billing/billing_service.dart';

/// Upgrade offer shown to free-tier users.
///
/// Launch flow: free users see this on every app start with a real choice —
/// "Continue free with ads" or "Go Pro". It is also reachable any time
/// from the upgrade entry point in the app bar, and from the monthly-limit
/// prompt when a free user hits 5 estimates in a calendar month. Nothing
/// here blocks: the free tier keeps working within its limits.
class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final billing = BillingService.instance;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: billing,
          builder: (context, _) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      size: 72,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Go Pro',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Start your $kTrialLengthText, then $kMonthlyPriceText. '
                      'Pro removes every ad, unlocks unlimited estimates, '
                      'and prints clean PDFs — no watermark.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ..._proPoints(theme),
                    const SizedBox(height: 28),
                    if (billing.purchasePending) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      const Text(
                        'Waiting for Google Play…',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'If you completed the purchase in the Play Store, '
                        'it can take a few seconds to confirm.',
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      if (billing.canPurchase) ...[
                        FilledButton(
                          onPressed: () => billing.startTrial(),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          child: const Text(
                            'Start your $kTrialLengthText',
                            style: TextStyle(fontSize: 17),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ] else ...[
                        Text(
                          billing.lastError ??
                              'The Pro subscription is not available right now.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => billing.refresh(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                        const SizedBox(height: 4),
                      ],
                      TextButton(
                        onPressed: () => billing.restore(),
                        child: const Text('Restore purchases'),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$kMonthlyPriceText after your $kTrialLengthText.\n'
                        'Cancel anytime in the Google Play Store.',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      if (billing.lastError != null && billing.canPurchase) ...[
                        const SizedBox(height: 12),
                        Text(
                          billing.lastError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => billing.dismissUpgradeOffer(),
                      child: const Text('Continue free with ads'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _proPoints(ThemeData theme) {
    const points = [
      (Icons.block, 'Zero ads — no banners, no pop-ups, ever'),
      (Icons.all_inclusive, 'Unlimited estimates (free is 5 per month)'),
      (Icons.picture_as_pdf, 'Clean PDFs — no "FREE VERSION" watermark'),
      (Icons.cancel_outlined, 'Cancel anytime in the Play Store'),
    ];
    return [
      for (final (icon, label) in points)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Flexible(child: Text(label, style: theme.textTheme.bodyMedium)),
            ],
          ),
        ),
    ];
  }
}

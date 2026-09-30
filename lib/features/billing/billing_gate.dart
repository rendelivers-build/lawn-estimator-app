import 'package:flutter/material.dart';
import 'package:lawn_estimator/features/billing/billing_service.dart';
import 'package:lawn_estimator/features/billing/upgrade_screen.dart';

/// Root gate: decides what the user sees based on the Play Billing tier.
///
///   - [BillingState.unknown] -> loading splash
///   - [BillingState.pro]     -> the app, ad-free
///   - [BillingState.free]    -> the upgrade offer on launch (dismissible
///                               per session via "Continue free with ads"),
///                               then the app with banner ads
///
/// The free tier is never blocked: full functionality with ads.
class BillingGate extends StatelessWidget {
  const BillingGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: BillingService.instance,
      builder: (context, _) {
        final billing = BillingService.instance;
        switch (billing.state) {
          case BillingState.unknown:
            return const _LoadingSplash();
          case BillingState.pro:
            return child;
          case BillingState.free:
            if (billing.upgradeDismissed) {
              return child;
            }
            return const UpgradeScreen();
        }
      },
    );
  }
}

class _LoadingSplash extends StatelessWidget {
  const _LoadingSplash();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grass, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Lawn Estimator',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lawn_estimator/theme.dart';

// Screen classes. Each is owned by its feature module; only the imports
// are declared here so the route table can reference them.
import 'package:lawn_estimator/features/estimates/estimates_screen.dart';
import 'package:lawn_estimator/features/address/address_search_screen.dart';
import 'package:lawn_estimator/features/measure/measure_screen.dart';
import 'package:lawn_estimator/features/confirm/confirm_screen.dart';
import 'package:lawn_estimator/features/materials/materials_screen.dart';
import 'package:lawn_estimator/features/materials/summary_screen.dart';
import 'package:lawn_estimator/features/pricing/pricing_settings_screen.dart';
import 'package:lawn_estimator/features/estimates/estimate_detail_screen.dart';
import 'package:lawn_estimator/features/settings/company_profile_screen.dart';

/// Root widget of the Lawn Estimator app.
class LawnEstimatorApp extends StatelessWidget {
  const LawnEstimatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lawn Estimator',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      onGenerateRoute: _onGenerateRoute,
      initialRoute: '/',
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    WidgetBuilder builder;
    switch (settings.name) {
      case '/':
        builder = (_) => const EstimatesScreen();
      case '/address':
        builder = (_) => const AddressSearchScreen();
      case '/measure':
        builder = (_) => const MeasureScreen();
      case '/confirm':
        builder = (_) => const ConfirmScreen();
      case '/materials':
        builder = (_) => const MaterialsScreen();
      case '/summary':
        builder = (_) => const SummaryScreen();
      case '/pricing':
        builder = (_) => const PricingSettingsScreen();
      case '/company':
        builder = (_) => const CompanyProfileScreen();
      case '/estimate':
        final estimateId = settings.arguments as String?;
        if (estimateId == null) {
          // Defensive: '/estimate' requires an estimate id argument.
          builder = (_) => const _MissingEstimateIdScreen();
        } else {
          builder = (_) => EstimateDetailScreen(estimateId: estimateId);
        }
      default:
        builder = (_) => const _UnknownRouteScreen();
    }
    return MaterialPageRoute<dynamic>(
      builder: builder,
      settings: settings,
    );
  }
}

/// Shown when '/estimate' is pushed without an estimate id argument.
class _MissingEstimateIdScreen extends StatelessWidget {
  const _MissingEstimateIdScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lawn Estimator')),
      body: const Center(
        child: Text('No estimate selected. Go back and choose an estimate.'),
      ),
    );
  }
}

/// Shown when an unknown route name is requested.
class _UnknownRouteScreen extends StatelessWidget {
  const _UnknownRouteScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lawn Estimator')),
      body: const Center(child: Text('Page not found.')),
    );
  }
}

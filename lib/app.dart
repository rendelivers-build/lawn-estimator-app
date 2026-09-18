import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lawn_estimator/features/measure/draft_autosave.dart';
import 'package:lawn_estimator/features/measure/draft_provider.dart';
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
import 'package:lawn_estimator/features/settings/tutorial_screen.dart';

/// Root widget of the Lawn Estimator app.
///
/// Also owns draft auto-save: the in-progress estimate is persisted
/// (debounced) on every change and immediately when the app is
/// backgrounded, so an interruption never loses the user's work.
class LawnEstimatorApp extends ConsumerStatefulWidget {
  const LawnEstimatorApp({super.key});

  @override
  ConsumerState<LawnEstimatorApp> createState() => _LawnEstimatorAppState();
}

class _LawnEstimatorAppState extends ConsumerState<LawnEstimatorApp>
    with WidgetsBindingObserver {
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Phone call, home button, app switcher: persist immediately.
    if (state == AppLifecycleState.paused) {
      _saveDebounce?.cancel();
      unawaited(saveDraft(ref.read(estimateDraftProvider)));
    }
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), () {
      unawaited(saveDraft(ref.read(estimateDraftProvider)));
    });
  }

  @override
  Widget build(BuildContext context) {
    // Debounced persist on every draft mutation (vertex taps, photo,
    // materials, notes, ...).
    ref.listen<EstimateDraft>(estimateDraftProvider, (_, __) => _scheduleSave());
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
      case '/tutorial':
        builder = (_) => const TutorialScreen();
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

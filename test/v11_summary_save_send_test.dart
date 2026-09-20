import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:lawn_estimator/data/estimate_repository.dart';
import 'package:lawn_estimator/features/materials/summary_screen.dart';
import 'package:lawn_estimator/features/measure/draft_provider.dart';
import 'package:lawn_estimator/features/measure/measure_screen.dart';
import 'package:lawn_estimator/models/models.dart';

/// V11 widget tests: the Estimate Summary screen's new flows.
///
/// The repository is faked so the tests never touch SQLite: what matters
/// is that both save buttons persist through the same path (with the
/// editing id, so an edit replaces the original) and that "Save and send"
/// then opens the share flow for the saved estimate.
class _FakeRepository extends EstimateRepository {
  _FakeRepository() : super(database: () async => throw UnimplementedError());

  final List<({EstimateDraft draft, String? replaceId})> saves = [];
  final List<String> loads = [];
  String nextId = 'saved-1';

  EstimateFull? fullToReturn;

  @override
  Future<String> saveDraft(EstimateDraft draft, {String? replaceId}) async {
    saves.add((draft: draft, replaceId: replaceId));
    return nextId;
  }

  @override
  Future<EstimateFull?> getEstimateFull(String id) async {
    loads.add(id);
    return fullToReturn;
  }
}

EstimateDraft _draftWithArea() {
  return const EstimateDraft(
    addressLabel: '123 Main St',
    centerLat: 38.5,
    centerLng: -121.7,
    zones: [
      [
        LatLng(38.5, -121.7),
        LatLng(38.5001, -121.7),
        LatLng(38.5001, -121.7001),
      ],
    ],
    // Matches the real flow: arriving at the summary means the resume
    // route is already '/summary', so initState's setResumeRoute is a
    // no-op (it would otherwise trip a debug-mode provider assertion).
    resumeRoute: '/summary',
    editingEstimateId: 'est-1',
  );
}

EstimateFull _sampleFull() {
  final now = DateTime(2026, 9, 20);
  return EstimateFull(
    estimate: Estimate(
      id: 'saved-1',
      name: '123 Main St',
      addressLabel: '123 Main St',
      centerLat: 38.5,
      centerLng: -121.7,
      areaFt2: 5000,
      createdAt: now,
      updatedAt: now,
    ),
    zones: const [],
    verticesByZone: const {},
    materials: const [],
    lineItems: const [],
  );
}

Future<void> _pumpSummary(
  WidgetTester tester, {
  required _FakeRepository repo,
}) async {
  final container = ProviderContainer();
  container.read(estimateDraftProvider.notifier).restore(_draftWithArea());
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        initialRoute: '/summary',
        routes: {
          '/': (_) => const Text('home'),
          '/summary': (_) => Scaffold(body: SummaryScreen(repository: repo)),
          '/measure': (_) => const Text('measure'),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('SummaryScreen v11', () {
    testWidgets('shows Save estimate, Save and send, and the address card', (
      tester,
    ) async {
      final repo = _FakeRepository();
      await _pumpSummary(tester, repo: repo);

      expect(find.text('Save estimate'), findsOneWidget);
      expect(find.text('Save and send'), findsOneWidget);
      expect(find.byKey(const Key('address_card')), findsOneWidget);
      expect(find.text('Long-press to edit the outline'), findsOneWidget);
    });

    testWidgets(
      'long-pressing the address card opens the map in edit-area mode',
      (tester) async {
        final repo = _FakeRepository();
        Object? captured;
        final container = ProviderContainer();
        container
            .read(estimateDraftProvider.notifier)
            .restore(_draftWithArea());
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              initialRoute: '/summary',
              routes: {
                '/': (_) => const Text('home'),
                '/summary': (_) =>
                    Scaffold(body: SummaryScreen(repository: repo)),
                '/measure': (ctx) {
                  captured = ModalRoute.of(ctx)?.settings.arguments;
                  return const Text('measure');
                },
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.longPress(find.byKey(const Key('address_card')));
        await tester.pumpAndSettle();

        expect(find.text('measure'), findsOneWidget);
        expect(captured, isA<EditAreaArgs>());
        // From the summary: pop back to this same screen on "Use this area",
        // so unsaved price/quantity tweaks survive the round trip.
        expect((captured as EditAreaArgs).returnToSummary, isFalse);
      },
    );

    testWidgets('Save and send saves (replacing the original), then shares', (
      tester,
    ) async {
      final repo = _FakeRepository()..fullToReturn = _sampleFull();
      await _pumpSummary(tester, repo: repo);

      // The save path does real async work (draft file cleanup, the share
      // sheet's platform channel). testWidgets runs in a FakeAsync zone
      // where those wedge, so drive the tap in the real async zone.
      await tester.runAsync(() async {
        await tester.tap(find.text('Save and send'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      // Saved exactly like "Save estimate": one save, with the editing id
      // so the original estimate is replaced, not duplicated.
      expect(repo.saves, hasLength(1));
      expect(repo.saves.single.replaceId, 'est-1');
      // Then the share flow opens for the just-saved estimate. (The OS
      // share sheet itself can't run in a widget test; the PDF build fails
      // on the printing channel and is swallowed into a SnackBar, but the
      // share path is provably entered by the load of the saved id.)
      expect(repo.loads, ['saved-1']);
      // And the flow finishes back home, like a normal save.
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('Save estimate still saves and goes home', (tester) async {
      final repo = _FakeRepository();
      await _pumpSummary(tester, repo: repo);

      await tester.runAsync(() async {
        await tester.tap(find.text('Save estimate'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      expect(repo.saves, hasLength(1));
      expect(repo.saves.single.replaceId, 'est-1');
      expect(repo.loads, isEmpty);
      expect(find.text('home'), findsOneWidget);
    });
  });
}

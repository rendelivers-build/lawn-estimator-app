/// Address lookup screen: debounced Google Places autocomplete, then a
/// place-details fetch that seeds the estimate draft and moves to measuring.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lawn_estimator/core/config.dart';
import 'package:lawn_estimator/features/measure/draft_provider.dart';

/// First screen of the flow: find the property address, then measure.
class AddressSearchScreen extends ConsumerStatefulWidget {
  const AddressSearchScreen({super.key});

  @override
  ConsumerState<AddressSearchScreen> createState() =>
      _AddressSearchScreenState();
}

class _AddressSearchScreenState extends ConsumerState<AddressSearchScreen> {
  FlutterGooglePlacesSdk? _places;
  final _controller = TextEditingController();
  Timer? _debounce;
  List<AutocompletePrediction> _predictions = [];
  bool _loading = false;
  bool _fetchingPlace = false;
  String? _error;

  /// Tracks whether a billing session is already open on the SDK. The SDK
  /// manages session tokens internally: passing `newSessionToken: true` on
  /// the first keystroke of a typing session groups the autocomplete calls
  /// and the follow-up fetchPlace into one billed session.
  bool _sessionStarted = false;

  /// Guards against out-of-order autocomplete responses.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    final key = AppConfig.mapsApiKey;
    // No key is ever bundled with the app; without one we show a setup hint.
    if (key.isNotEmpty) {
      _places = FlutterGooglePlacesSdk(key);
    }
    // Refresh the clear-button affordance as the user types.
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _requestId++; // Invalidate any in-flight request.
      setState(() {
        _predictions = [];
        _error = null;
        _loading = false;
        _sessionStarted = false;
      });
      return;
    }
    // Drop a stale error as soon as typing resumes — a failed keystroke's
    // message must not linger on screen while the next search is in flight.
    if (_error != null) {
      setState(() => _error = null);
    }
    _debounce =
        Timer(const Duration(milliseconds: 300), () => _search(trimmed));
  }

  Future<void> _search(String query) async {
    final places = _places;
    if (places == null) return;
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await places.findAutocompletePredictions(
        query,
        countries: const ['US'],
        placeTypesFilter: const [PlaceTypeFilter.ADDRESS],
        newSessionToken: _sessionStarted ? null : true,
      );
      _sessionStarted = true;
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _predictions = response.predictions;
        _loading = false;
      });
    } catch (e) {
      // Technical details go to the debug log only — users just see the
      // friendly message, never a raw PlatformException dump.
      debugPrint('Address autocomplete failed: $e');
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = 'Search failed. Check your connection and try again.';
      });
    }
  }

  void _clearQuery() {
    _controller.clear();
    _onQueryChanged('');
  }

  Future<void> _selectPrediction(AutocompletePrediction prediction) async {
    final places = _places;
    if (places == null) return;
    setState(() {
      _fetchingPlace = true;
      _error = null;
    });
    try {
      final response = await places.fetchPlace(
        prediction.placeId,
        fields: const [PlaceField.Address, PlaceField.Location],
      );
      final place = response.place;
      final latLng = place?.latLng;
      if (!mounted) return;
      if (latLng == null) {
        setState(() {
          _fetchingPlace = false;
          _error = 'Could not load coordinates for that address.';
        });
        return;
      }
      ref.read(estimateDraftProvider.notifier).startNew(
            addressLabel: place?.address ?? prediction.fullText,
            placeId: prediction.placeId,
            lat: latLng.lat,
            lng: latLng.lng,
          );
      if (!mounted) return;
      Navigator.pushNamed(context, '/measure');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchingPlace = false;
        debugPrint('Place details failed: $e');
        _error = 'Could not load that address. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_places == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Find address')),
        body: _buildSetupHint(),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Find address')),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Enter a street address',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'Clear',
                            onPressed: _clearQuery,
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: _onQueryChanged,
                ),
              ),
              if (_loading) const LinearProgressIndicator(),
              Expanded(child: _buildResults()),
            ],
          ),
          if (_fetchingPlace) _buildFetchingOverlay(),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_controller.text.trim().isEmpty) {
      return const Center(
        child: Text('Type an address to search.'),
      );
    }
    if (_loading && _predictions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_predictions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No addresses found. Try a different search.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: _predictions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final prediction = _predictions[index];
        return ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: Text(prediction.primaryText),
          subtitle: Text(prediction.secondaryText),
          onTap: () => _selectPrediction(prediction),
        );
      },
    );
  }

  Widget _buildFetchingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  /// Shown when no Maps API key is configured. Never bundles a key.
  Widget _buildSetupHint() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.key_off, size: 40),
                SizedBox(height: 12),
                Text(
                  'Address search is not set up',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Add your Google Maps API key to AppConfig '
                  '(lib/core/config.dart) to enable address search. '
                  'No key is bundled with the app.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

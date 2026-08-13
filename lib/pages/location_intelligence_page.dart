import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../models/significant_place.dart';
import '../services/device_compatibility_service.dart';
import '../services/location_intelligence_service.dart';
import '../widgets/background_reliability_prompt.dart';

class LocationIntelligencePage extends StatefulWidget {
  const LocationIntelligencePage({super.key});

  @override
  State<LocationIntelligencePage> createState() =>
      _LocationIntelligencePageState();
}

class _LocationIntelligencePageState extends State<LocationIntelligencePage> {
  final LocationIntelligenceService _service = LocationIntelligenceService();
  final DeviceCompatibilityService _deviceCompatibilityService =
      DeviceCompatibilityService();

  bool _loading = true;
  bool _busy = false;
  bool _enabled = false;
  bool _hasBackgroundPermission = false;
  List<SignificantPlace> _places = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Defensive ceiling on every awaited call below — live-reproduced this
  // session as a genuinely stuck loading spinner (traced to somewhere in
  // this chain, likely the native geofence-registration round-trip
  // triggered by updateNotificationText -> _syncGeofences, on a device
  // where Play Services' geofence registration was already known to
  // misbehave — see ARCHITECTURE_ROADMAP.md's Phase 6 notes). Whatever the
  // exact cause, this screen must never hang forever regardless of it.
  static const _loadStepTimeout = Duration(seconds: 10);

  Future<void> _load() async {
    setState(() => _loading = true);

    // The very first `initState()` call into here must not touch anything
    // depending on an InheritedWidget (Localizations, i.e. `context.t`)
    // before this widget has actually finished mounting — Flutter throws
    // (uncaught, since `_load` is fire-and-forget from initState) if it's
    // reached synchronously as part of initState's own call stack. Live
    // reproduced this session as a permanently stuck loading spinner: the
    // exception fired before `_loading` was ever set back to false, and
    // because nothing was awaited yet, it happened synchronously within
    // initState itself. Awaiting these DB/permission calls *first* pushes
    // everything after past the point where mounting has completed, which
    // is what makes touching `context.t` safe afterward.
    final enabled = await _service.isEnabled().timeout(
      _loadStepTimeout,
      onTimeout: () => false,
    );
    final hasBackground = await _service.hasBackgroundPermission().timeout(
      _loadStepTimeout,
      onTimeout: () => false,
    );
    final places = await _service.loadPlaces().timeout(
      _loadStepTimeout,
      onTimeout: () => const <SignificantPlace>[],
    );

    if (mounted) {
      await _service
          .updateNotificationText(
            title: context.t('locationArrivalNotificationTitle'),
            body: context.t('locationArrivalNotificationBody'),
          )
          .timeout(_loadStepTimeout, onTimeout: () {});
    }

    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _hasBackgroundPermission = hasBackground;
      _places = places;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    setState(() => _busy = true);
    if (value) {
      await _service.enable();
    } else {
      await _service.disable();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t(
            value
                ? 'locationIntelligenceEnabledConfirmation'
                : 'locationIntelligenceDisabledConfirmation',
          ),
        ),
      ),
    );
    setState(() => _busy = false);
    await _load();
    if (value && mounted) {
      await maybePromptBackgroundReliability(
        context: context,
        deviceCompatibilityService: _deviceCompatibilityService,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('locationIntelligenceTitle'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                context.t('locationIntelligenceTitle'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Switch(
                              value: _enabled,
                              onChanged: _busy ? null : _toggle,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          context.t('locationIntelligenceIntro'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.t('locationIntelligencePurpose'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        if (_enabled && !_hasBackgroundPermission) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orangeAccent),
                            ),
                            child: Text(
                              context.t(
                                'locationIntelligenceBackgroundWarning',
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.orangeAccent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  context.t('locationIntelligencePlacesTitle'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                if (_places.isEmpty)
                  Text(
                    context.t('locationIntelligenceNoPlacesYet'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  )
                else
                  ..._places.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final place = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(Icons.place),
                        title: Text(
                          '${context.t('locationIntelligencePlaceRow')} $index',
                        ),
                        trailing: Text(
                          '${place.visitCount} ${context.t('locationIntelligenceVisitCount')}',
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}

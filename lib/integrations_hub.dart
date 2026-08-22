import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cloud_sync.dart';
import 'daily_inputs.dart';
import 'contextual_guides.dart';
import 'external_workout_formats.dart';
import 'health_sync.dart';
import 'lab_experiments.dart';
import 'provider_integrations.dart';
import 'safe_layout.dart';
import 'share_options.dart';
import 'store.dart';

class IntegrationPreferencesStore extends ChangeNotifier {
  IntegrationPreferencesStore({required AppStore store, MethodChannel? channel})
    : _store = store,
      _channel =
          channel ??
          const MethodChannel('progression_lab/integration_preferences');

  final AppStore _store;
  final MethodChannel _channel;
  final List<LabExperiment> experiments = <LabExperiment>[];
  final List<ExternalWorkout> externalWorkouts = <ExternalWorkout>[];
  final List<HealthBodyMetric> healthBodyMetrics = <HealthBodyMetric>[];
  WorkoutSharePreferences sharePreferences = const WorkoutSharePreferences();
  bool weeklyReviewEnabled = false;
  bool loaded = false;

  Future<void> load() async {
    try {
      Map<String, dynamic>? decodedMap;
      final embedded = _store.integrationState['integrations'];
      if (embedded is Map) {
        decodedMap = Map<String, dynamic>.from(embedded);
      } else {
        final raw = await _channel.invokeMethod<String>('read');
        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map) decodedMap = Map<String, dynamic>.from(decoded);
        }
      }
      if (decodedMap != null) {
        final decoded = decodedMap;
        {
          final map = Map<String, dynamic>.from(decoded);
          final rawExperiments = map['experiments'];
          if (rawExperiments is List) {
            experiments
              ..clear()
              ..addAll(
                rawExperiments.whereType<Map>().map(
                  (item) =>
                      LabExperiment.fromJson(Map<String, dynamic>.from(item)),
                ),
              );
          }
          final rawShare = map['sharePreferences'];
          if (rawShare is Map) {
            sharePreferences = WorkoutSharePreferences.fromJson(
              Map<String, dynamic>.from(rawShare),
            );
          }
          weeklyReviewEnabled = map['weeklyReviewEnabled'] == true;
          final rawHealthMetrics = map['healthBodyMetrics'];
          if (rawHealthMetrics is List) {
            healthBodyMetrics
              ..clear()
              ..addAll(
                rawHealthMetrics.whereType<Map>().map(
                  (raw) => HealthBodyMetric.fromJson(
                    Map<Object?, Object?>.from(raw),
                  ),
                ),
              );
          }
          AdvancedWorkoutShareCardGenerator.currentPreferences =
              sharePreferences;
          final rawExternal = map['externalWorkouts'];
          if (rawExternal is List) {
            externalWorkouts
              ..clear()
              ..addAll(
                rawExternal.whereType<Map>().map((raw) {
                  final value = Map<String, dynamic>.from(raw);
                  final start = DateTime.parse('${value['startedAt']}').toUtc();
                  final end = DateTime.parse('${value['endedAt']}').toUtc();
                  ExternalWorkoutSource source = ExternalWorkoutSource.file;
                  ExternalWorkoutFormat format = ExternalWorkoutFormat.fit;
                  for (final candidate in ExternalWorkoutSource.values) {
                    if (candidate.name == '${value['source']}')
                      source = candidate;
                  }
                  for (final candidate in ExternalWorkoutFormat.values) {
                    if (candidate.name == '${value['format']}')
                      format = candidate;
                  }
                  return ExternalWorkout(
                    id: '${value['id']}',
                    source: source,
                    format: format,
                    title: '${value['title']}',
                    sport: '${value['sport']}',
                    startedAt: start,
                    endedAt: end,
                    distanceMeters: (value['distanceMeters'] as num?)
                        ?.toDouble(),
                    durationSeconds: (value['durationSeconds'] as num?)
                        ?.toDouble(),
                    calories: (value['calories'] as num?)?.toInt(),
                    averageHeartRate: (value['averageHeartRate'] as num?)
                        ?.toInt(),
                    maximumHeartRate: (value['maximumHeartRate'] as num?)
                        ?.toInt(),
                    averageCadence: (value['averageCadence'] as num?)?.toInt(),
                    averagePowerWatts: (value['averagePowerWatts'] as num?)
                        ?.toInt(),
                    notes: value['notes'] is String
                        ? value['notes'] as String
                        : '',
                    metadata: value['metadata'] is Map
                        ? Map<String, dynamic>.from(value['metadata'] as Map)
                        : const <String, dynamic>{},
                  );
                }),
              );
          }
        }
      }
    } on Object {
      // Defaults remain usable when optional preferences are unavailable.
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    final data = <String, dynamic>{
      'experiments': experiments.map((item) => item.toJson()).toList(),
      'sharePreferences': sharePreferences.toJson(),
      'weeklyReviewEnabled': weeklyReviewEnabled,
      'healthBodyMetrics': healthBodyMetrics
          .map((item) => item.toJson())
          .toList(),
      'externalWorkouts': externalWorkouts
          .map((item) => item.toJson())
          .toList(),
    };
    final merged = Map<String, dynamic>.from(_store.integrationState)
      ..['integrations'] = data;
    await _store.setIntegrationState(merged);
    try {
      await _channel.invokeMethod<void>('write', jsonEncode(data));
    } on PlatformException {
      // The exact .plab state remains authoritative if optional platform
      // preference mirroring is unavailable.
    }
  }

  Future<void> addExperiment(LabExperiment experiment) async {
    experiments.add(experiment);
    await save();
    notifyListeners();
  }

  Future<void> removeExperiment(String id) async {
    experiments.removeWhere((item) => item.id == id);
    await save();
    notifyListeners();
  }

  Future<void> setSharePreferences(WorkoutSharePreferences value) async {
    sharePreferences = value;
    AdvancedWorkoutShareCardGenerator.currentPreferences = sharePreferences;
    await save();
    notifyListeners();
  }

  Future<void> setWeeklyReviewEnabled(bool value) async {
    weeklyReviewEnabled = value;
    await save();
    notifyListeners();
  }

  Future<void> addHealthBodyMetrics(Iterable<HealthBodyMetric> values) async {
    final incoming = values.toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final keys = healthBodyMetrics
        .map(
          (item) =>
              '${item.type}|${item.recordedAt.toUtc().toIso8601String()}|${item.source}',
        )
        .toSet();
    for (final value in incoming) {
      final key =
          '${value.type}|${value.recordedAt.toUtc().toIso8601String()}|${value.source}';
      if (keys.add(key)) healthBodyMetrics.add(value);
      if (value.type != 'bodyWeight' ||
          !value.value.isFinite ||
          value.value <= 0) {
        continue;
      }
      final day = dateOnly(value.recordedAt.toLocal());
      final existing = _store.recoveryForDay(day);
      if (existing?.bodyWeight != null) continue;
      var bodyWeight = value.value;
      var weightUnit = value.unit;
      if (value.unit == 'kg' && _store.unit == 'lb') {
        bodyWeight = value.value / AppStore.poundsToKilograms;
        weightUnit = 'lb';
      } else if (value.unit == 'lb' && _store.unit == 'kg') {
        bodyWeight = value.value * AppStore.poundsToKilograms;
        weightUnit = 'kg';
      }
      final recordTime = value.recordedAt.toLocal();
      await _store.saveRecoveryCheckIn(
        RecoveryCheckIn(
          id: existing?.id ?? createRecordId('recovery'),
          localDate: day,
          sleepHours: existing?.sleepHours,
          sleepQuality: existing?.sleepQuality,
          stress: existing?.stress,
          soreness: existing?.soreness,
          bodyWeight: bodyWeight,
          weightUnit: weightUnit,
          illness: existing?.illness ?? false,
          notes: existing?.notes ?? '',
          createdAt: existing?.createdAt ?? recordTime,
          updatedAt: existing?.updatedAt ?? recordTime,
        ),
      );
    }
    await save();
    notifyListeners();
  }

  Future<void> addExternalWorkouts(Iterable<ExternalWorkout> values) async {
    final ids = externalWorkouts.map((item) => item.id).toSet();
    for (final value in values) {
      if (ids.add(value.id)) externalWorkouts.add(value);
    }
    await save();
    notifyListeners();
  }
}

class IntegrationFileBridge {
  const IntegrationFileBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('progression_lab/integrations');

  final MethodChannel _channel;

  Future<({String name, Uint8List bytes})?> pickWorkoutFile() async {
    final value = await _channel.invokeMapMethod<Object?, Object?>(
      'pickWorkoutFile',
      const <String, Object>{
        'extensions': <String>['fit', 'tcx', 'gpx'],
      },
    );
    if (value == null || value['bytes'] is! Uint8List) return null;
    return (
      name: value['name'] is String ? value['name']! as String : 'workout.fit',
      bytes: value['bytes']! as Uint8List,
    );
  }
}

class IntegrationsHubScreen extends StatefulWidget {
  const IntegrationsHubScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<IntegrationsHubScreen> createState() => _IntegrationsHubScreenState();
}

class _IntegrationsHubScreenState extends State<IntegrationsHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final HealthSyncService _health;
  late final CloudBackupSyncService _cloud;
  late final ProviderIntegrationService _providers;
  late final ContextualGuideState _guides;
  late final IntegrationPreferencesStore _preferences;
  final _fileBridge = const IntegrationFileBridge();
  String? _message;
  bool _fileBusy = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _health = HealthSyncService()..addListener(_refresh);
    _cloud = CloudBackupSyncService.shared(widget.store)..addListener(_refresh);
    _providers = ProviderIntegrationService()..addListener(_refresh);
    _guides = ContextualGuideState(store: widget.store)..addListener(_refresh);
    _preferences = IntegrationPreferencesStore(store: widget.store)
      ..addListener(_refresh);
    _load();
  }

  Future<void> _load() async {
    await Future.wait<void>(<Future<void>>[
      _health.refreshStatus().then((_) {}),
      _cloud.initialize(),
      _providers.initialize(),
      _guides.load(),
      _preferences.load(),
    ]);
    if (mounted) setState(() {});
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabs.dispose();
    _health.dispose();
    _cloud.removeListener(_refresh);
    _providers.dispose();
    _guides.dispose();
    _preferences.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff06070c),
    appBar: AppBar(
      title: const Text('CONNECTIONS & EXPERIMENTS'),
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: const <Tab>[
          Tab(text: 'HEALTH'),
          Tab(text: 'PROVIDERS'),
          Tab(text: 'IMPORT'),
          Tab(text: 'CLOUD'),
          Tab(text: 'SHARING'),
          Tab(text: 'LAB & GUIDES'),
        ],
      ),
    ),
    body: LabSafeScreen(
      child: Column(
        children: <Widget>[
          if (_message != null)
            _Notice(
              message: _message!,
              onClose: () => setState(() => _message = null),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: <Widget>[
                _healthTab(),
                _providerTab(),
                _importTab(),
                _cloudTab(),
                _sharingTab(),
                _labAndGuidesTab(),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _healthTab() {
    final status = _health.status;
    final name = switch (status.platform) {
      HealthPlatformKind.healthConnect => 'Health Connect',
      HealthPlatformKind.appleHealth => 'Apple Health',
      HealthPlatformKind.unavailable => 'Health platform',
    };
    final localWeights =
        widget.store.recoveryCheckIns
            .where((item) => item.bodyWeight != null)
            .toList()
          ..sort((a, b) => a.localDate.compareTo(b.localDate));
    final latestLocalWeight = localWeights.isEmpty ? null : localWeights.last;
    final recentHealthMetrics = List<HealthBodyMetric>.of(
      _preferences.healthBodyMetrics,
    )..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return _ScrollSection(
      children: <Widget>[
        _Hero(
          icon: Icons.favorite_rounded,
          eyebrow: 'PLATFORM HEALTH',
          title: name,
          description:
              'Read and write workout summaries, bodyweight, and body-fat percentage. Progression Lab remains the source of truth for detailed sets and private daily inputs.',
        ),
        _StatusCard(
          title: status.available ? 'AVAILABLE' : 'NOT AVAILABLE',
          detail: status.message.isNotEmpty
              ? status.message
              : 'Authorization: ${status.authorization.name}',
          positive: status.available,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _health.busy || !status.available
              ? null
              : () => _run(() async {
                  final granted = await _health.requestAuthorization();
                  _message = granted
                      ? '$name access is ready.'
                      : '$name access was not granted. Local tracking is unchanged.';
                }),
          icon: const Icon(Icons.security_rounded),
          label: const Text('REVIEW HEALTH PERMISSIONS'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _health.busy || !status.available
              ? null
              : () => _run(() async {
                  final now = DateTime.now();
                  final workouts = await _health.readWorkouts(
                    start: now.subtract(const Duration(days: 90)),
                    end: now,
                  );
                  await _preferences.addExternalWorkouts(workouts);
                  _message =
                      '${workouts.length} health workouts reviewed. Duplicate IDs were skipped.';
                }),
          icon: const Icon(Icons.sync_rounded),
          label: const Text('IMPORT RECENT WORKOUT SUMMARIES'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _health.busy || !status.available
              ? null
              : () => _run(() async {
                  final now = DateTime.now();
                  final metrics = await _health.readBodyMetrics(
                    start: now.subtract(const Duration(days: 365)),
                    end: now,
                  );
                  await _preferences.addHealthBodyMetrics(metrics);
                  _message =
                      '${metrics.length} body metric records reviewed. Existing local bodyweight entries were preserved.';
                }),
          icon: const Icon(Icons.monitor_weight_outlined),
          label: const Text('IMPORT RECENT BODY METRICS'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed:
              _health.busy || !status.available || latestLocalWeight == null
              ? null
              : () => _run(() async {
                  final entry = latestLocalWeight;
                  final written = await _health.writeBodyWeight(
                    HealthBodyMetric(
                      type: 'bodyWeight',
                      value: entry.bodyWeight!,
                      unit: entry.weightUnit ?? widget.store.unit,
                      recordedAt: entry.updatedAt.toUtc(),
                    ),
                  );
                  _message = written
                      ? 'Latest local bodyweight was written to $name.'
                      : 'The latest local bodyweight was not written.';
                }),
          icon: const Icon(Icons.upload_rounded),
          label: const Text('WRITE LATEST LOCAL BODYWEIGHT'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _health.busy || !status.available
              ? null
              : _writeBodyFatReading,
          icon: const Icon(Icons.percent_rounded),
          label: const Text('ADD & WRITE BODY-FAT READING'),
        ),
        if (recentHealthMetrics.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'BODY METRIC ARCHIVE',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  '${recentHealthMetrics.length} unique records',
                  style: const TextStyle(color: Colors.white60),
                ),
                const Divider(height: 24),
                for (final metric in recentHealthMetrics.take(6))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      metric.type == 'bodyWeight'
                          ? Icons.monitor_weight_outlined
                          : Icons.percent_rounded,
                    ),
                    title: Text(
                      metric.type == 'bodyWeight'
                          ? 'Bodyweight'
                          : 'Body-fat percentage',
                    ),
                    subtitle: Text(
                      metric.recordedAt.toLocal().toString().split('.').first,
                    ),
                    trailing: Text(
                      '${metric.value.toStringAsFixed(1)} ${metric.unit}',
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        const _Info(
          title: 'What is shared',
          text:
              'Workout summaries can be read or written. Bodyweight and body-fat percentage can be imported or written after you approve access. Imported bodyweight fills only an empty Daily Inputs bodyweight field; existing local values, detailed sets, notes, substitutions, supplements, meals, hydration, and recovery ratings stay unchanged.',
        ),
      ],
    );
  }

  Widget _providerTab() => _ScrollSection(
    children: <Widget>[
      const _Hero(
        icon: Icons.hub_rounded,
        eyebrow: 'CONNECTED TRAINING',
        title: 'Strava & Garmin',
        description:
            'Connect through a secure OAuth broker when provider credentials are configured. No client secret is stored in the app.',
      ),
      for (final provider in TrainingProvider.values) ...<Widget>[
        _providerCard(provider),
        const SizedBox(height: 12),
      ],
      const _Info(
        title: 'No account connection required',
        text:
            'FIT, TCX, GPX, Strava bulk exports, and Garmin original activity files can be imported from the Import tab without OAuth or a cloud account.',
      ),
    ],
  );

  Widget _providerCard(TrainingProvider provider) {
    final status = _providers.statuses[provider]!;
    final config = ProviderConfiguration.forProvider(provider);
    final title = provider == TrainingProvider.strava
        ? 'STRAVA'
        : 'GARMIN CONNECT';
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                provider == TrainingProvider.strava
                    ? Icons.directions_run_rounded
                    : Icons.watch_rounded,
                color: const Color(0xff22d3ee),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      status.connected
                          ? (status.accountName.isEmpty
                                ? 'Connected'
                                : status.accountName)
                          : status.state.name,
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
              _Dot(positive: status.connected),
            ],
          ),
          if (!config.configured) ...<Widget>[
            const SizedBox(height: 14),
            const Text(
              'Provider configuration is not present in this build. Add the broker URL through a protected build variable; manual file import is already available.',
              style: TextStyle(color: Colors.white60, height: 1.4),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              if (!status.connected)
                Expanded(
                  child: FilledButton(
                    onPressed: !config.configured || _providers.busy
                        ? null
                        : () => _run(() async {
                            await _providers.connect(provider);
                            _message = '$title connected.';
                          }),
                    child: const Text('CONNECT'),
                  ),
                )
              else ...<Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: _providers.busy
                        ? null
                        : () => _run(() async {
                            final now = DateTime.now();
                            final page = await _providers.fetchActivities(
                              provider,
                              start: now.subtract(const Duration(days: 180)),
                              end: now,
                            );
                            await _preferences.addExternalWorkouts(
                              page.workouts,
                            );
                            _message =
                                '${page.workouts.length} $title activities imported.';
                          }),
                    child: const Text('SYNC'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _providers.busy
                      ? null
                      : () => _run(() => _providers.disconnect(provider)),
                  child: const Text('DISCONNECT'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _importTab() => _ScrollSection(
    children: <Widget>[
      const _Hero(
        icon: Icons.file_open_rounded,
        eyebrow: 'WEARABLE & ENDURANCE FILES',
        title: 'FIT, TCX & GPX',
        description:
            'Import common Garmin, Strava, cycling, running, swimming, and wearable activity files locally. Nothing is uploaded to a server.',
      ),
      FilledButton.icon(
        onPressed: _fileBusy ? null : _pickWorkoutFile,
        icon: _fileBusy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_rounded),
        label: const Text('CHOOSE WORKOUT FILE'),
      ),
      const SizedBox(height: 18),
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'IMPORTED ACTIVITY ARCHIVE',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              '${_preferences.externalWorkouts.length} unique activities',
              style: const TextStyle(color: Colors.white60),
            ),
            if (_preferences.externalWorkouts.isNotEmpty) ...<Widget>[
              const Divider(height: 28),
              for (final item in _preferences.externalWorkouts.reversed.take(6))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.route_rounded),
                  title: Text(item.title),
                  subtitle: Text(
                    '${item.sport} · ${item.startedAt.toLocal().toString().split('.').first}',
                  ),
                  trailing: item.distanceMeters == null
                      ? null
                      : Text(
                          '${(item.distanceMeters! / 1000).toStringAsFixed(1)} km',
                        ),
                ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      const _Info(
        title: 'Strength data',
        text:
            'Use Strong, Hevy, FitNotes, or generic CSV import under Data & Backup for set-by-set gym history. FIT, TCX, and GPX are best for timed activities and wearable sensor data.',
      ),
    ],
  );

  Widget _cloudTab() => _ScrollSection(
    children: <Widget>[
      const _Hero(
        icon: Icons.cloud_sync_rounded,
        eyebrow: 'USER-CONTROLLED CLOUD BACKUP',
        title: 'Your folder. Your data.',
        description:
            'Choose a folder from Files. Android can use Drive, OneDrive, Dropbox, or another document provider. iOS can use iCloud Drive or another Files provider.',
      ),
      _StatusCard(
        title: _cloud.status.configured ? 'FOLDER READY' : 'NO FOLDER SELECTED',
        detail: _cloud.status.configured
            ? '${_cloud.status.displayName} · ${_cloud.status.provider.name}'
            : 'Choose a folder before enabling automatic sync.',
        positive: _cloud.status.configured,
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _cloud.busy
            ? null
            : () => _run(() async {
                await _cloud.chooseFolder();
                _message = _cloud.status.configured
                    ? 'Backup folder connected.'
                    : 'No folder was selected.';
              }),
        icon: const Icon(Icons.folder_open_rounded),
        label: Text(
          _cloud.status.configured ? 'CHANGE FOLDER' : 'CHOOSE FOLDER',
        ),
      ),
      const SizedBox(height: 12),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('AUTOMATIC CLOUD BACKUP'),
        subtitle: const Text(
          'Upload after saved data changes. Local workout saves never wait for cloud sync.',
        ),
        value: _cloud.automaticSyncEnabled,
        onChanged: _cloud.status.configured && !_cloud.busy
            ? (value) => _run(() => _cloud.setAutomaticSyncEnabled(value))
            : null,
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: !_cloud.status.configured || _cloud.busy
            ? null
            : () => _run(() async {
                final preview = await _cloud.preview();
                if (preview.direction == CloudSyncDirection.download &&
                    preview.remote != null) {
                  final restore = await _confirm(
                    'Cloud backup is newer',
                    'Restore ${preview.remote!.name}? A verified safety backup will be created first.',
                    confirmLabel: 'RESTORE',
                  );
                  if (restore) await _cloud.restoreRemote(preview.remote!);
                } else if (preview.direction == CloudSyncDirection.upload) {
                  await _cloud.uploadNow();
                }
                _message = preview.reason;
              }),
        icon: const Icon(Icons.sync_rounded),
        label: const Text('REVIEW & SYNC NOW'),
      ),
      const SizedBox(height: 12),
      if (_cloud.status.configured)
        TextButton.icon(
          onPressed: _cloud.busy
              ? null
              : () => _run(() => _cloud.disconnectFolder()),
          icon: const Icon(Icons.link_off_rounded),
          label: const Text('DISCONNECT FOLDER'),
        ),
    ],
  );

  Widget _sharingTab() {
    final preferences = _preferences.sharePreferences;
    return _ScrollSection(
      children: <Widget>[
        const _Hero(
          icon: Icons.auto_awesome_rounded,
          eyebrow: 'WORKOUT STORY CARDS',
          title: 'Share the signal',
          description:
              'Choose a branded template, output format, and privacy level. Images are generated on-device.',
        ),
        _choice<WorkoutShareTemplate>(
          title: 'TEMPLATE',
          values: WorkoutShareTemplate.values,
          selected: preferences.template,
          label: (value) => switch (value) {
            WorkoutShareTemplate.cleanPerformance => 'Clean performance',
            WorkoutShareTemplate.achievement => 'PR / achievement',
            WorkoutShareTemplate.sessionRecap => 'Session recap',
          },
          onSelected: (value) => _saveShare(
            WorkoutSharePreferences(
              template: value,
              aspect: preferences.aspect,
              privacy: preferences.privacy,
              includeCaption: preferences.includeCaption,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _choice<WorkoutShareAspect>(
          title: 'FORMAT',
          values: WorkoutShareAspect.values,
          selected: preferences.aspect,
          label: (value) => switch (value) {
            WorkoutShareAspect.story => 'Story 9:16',
            WorkoutShareAspect.portraitFeed => 'Feed 4:5',
            WorkoutShareAspect.square => 'Square 1:1',
          },
          onSelected: (value) => _saveShare(
            WorkoutSharePreferences(
              template: preferences.template,
              aspect: value,
              privacy: preferences.privacy,
              includeCaption: preferences.includeCaption,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            children: <Widget>[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PRIVACY',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _privacySwitch(
                'Show exact weights',
                preferences.privacy.showExactWeights,
                (value) => _privacy(preferences, showExactWeights: value),
              ),
              _privacySwitch(
                'Show duration',
                preferences.privacy.showDuration,
                (value) => _privacy(preferences, showDuration: value),
              ),
              _privacySwitch(
                'Show volume',
                preferences.privacy.showVolume,
                (value) => _privacy(preferences, showVolume: value),
              ),
              _privacySwitch(
                'Show bodyweight',
                preferences.privacy.showBodyweight,
                (value) => _privacy(preferences, showBodyweight: value),
              ),
              _privacySwitch(
                'Completion-only mode',
                preferences.privacy.completionOnly,
                (value) => _privacy(preferences, completionOnly: value),
              ),
              _privacySwitch(
                'Create caption text',
                preferences.includeCaption,
                (value) => _saveShare(
                  WorkoutSharePreferences(
                    template: preferences.template,
                    aspect: preferences.aspect,
                    privacy: preferences.privacy,
                    includeCaption: value,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _labAndGuidesTab() => _ScrollSection(
    children: <Widget>[
      const _Hero(
        icon: Icons.science_rounded,
        eyebrow: 'PERSONAL EXPERIMENTS',
        title: 'Run the next test',
        description:
            'Define comparison conditions before interpreting the data. Lab Core calculates the result; optional AI explains verified evidence.',
      ),
      FilledButton.icon(
        onPressed: _newExperiment,
        icon: const Icon(Icons.add_rounded),
        label: const Text('START AN EXPERIMENT'),
      ),
      const SizedBox(height: 12),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('WEEKLY LAB REVIEW'),
        subtitle: const Text(
          'Prepare a user-triggered seven-day evidence summary. No background AI inference.',
        ),
        value: _preferences.weeklyReviewEnabled,
        onChanged: (value) =>
            _run(() => _preferences.setWeeklyReviewEnabled(value)),
      ),
      const SizedBox(height: 12),
      for (final experiment in _preferences.experiments) ...<Widget>[
        _experimentCard(experiment),
        const SizedBox(height: 10),
      ],
      if (_preferences.experiments.isEmpty)
        const _Info(
          title: 'No experiments yet',
          text:
              'Start with caffeine timing, creatine consistency, meal timing, or a sleep target. Results remain labeled as associations.',
        ),
      const SizedBox(height: 22),
      const Divider(),
      const SizedBox(height: 12),
      const Text(
        'CONTEXTUAL GUIDES',
        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
      ),
      const SizedBox(height: 8),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Show one-time feature tips'),
        value: _guides.tipsEnabled,
        onChanged: (value) => _run(() => _guides.setTipsEnabled(value)),
      ),
      OutlinedButton.icon(
        onPressed: () => _run(() async {
          await _guides.resetAllTips();
          _message = 'All feature tips are ready to appear again.';
        }),
        icon: const Icon(Icons.restart_alt_rounded),
        label: const Text('RESET ALL TIPS'),
      ),
      const SizedBox(height: 12),
      Text(
        '${_guides.seen.length} of ${ContextualGuideId.values.length} contextual guides completed',
        style: const TextStyle(color: Colors.white54),
      ),
    ],
  );

  Widget _experimentCard(LabExperiment experiment) {
    final result = LabExperimentAnalyzer.analyze(
      experiment,
      widget.store.exportState(),
    );
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.biotech_rounded, color: Color(0xff22d3ee)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  experiment.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: 'Delete experiment',
                onPressed: () =>
                    _run(() => _preferences.removeExperiment(experiment.id)),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result.summary,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _Chip('${result.samplesA.length} A'),
              _Chip('${result.samplesB.length} B'),
              _Chip(result.confidence.name.toUpperCase()),
              if (result.percentDifference != null)
                _Chip('${result.percentDifference!.toStringAsFixed(1)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickWorkoutFile() async {
    setState(() => _fileBusy = true);
    try {
      final file = await _fileBridge.pickWorkoutFile();
      if (file == null) return;
      final parsed = ExternalWorkoutFileParser.parse(
        bytes: file.bytes,
        fileName: file.name,
      );
      await _preferences.addExternalWorkouts(parsed.workouts);
      setState(() {
        _message =
            '${parsed.workouts.length} workout${parsed.workouts.length == 1 ? '' : 's'} imported from ${file.name}.';
      });
    } on Object catch (error) {
      setState(() => _message = 'Import stopped: $error');
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  Future<void> _newExperiment() async {
    final template = await showModalBottomSheet<LabExperimentTemplate>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            const ListTile(
              title: Text(
                'START AN EXPERIMENT',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text('Choose a predefined, deterministic comparison.'),
            ),
            for (final value in <LabExperimentTemplate>[
              LabExperimentTemplate.caffeineTiming,
              LabExperimentTemplate.creatineConsistency,
              LabExperimentTemplate.preWorkoutMealTiming,
              LabExperimentTemplate.sleepTarget,
            ])
              ListTile(
                title: Text(_templateName(value)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(context, value),
              ),
          ],
        ),
      ),
    );
    if (template == null) return;
    final experiment = switch (template) {
      LabExperimentTemplate.caffeineTiming =>
        LabExperimentTemplates.caffeineTiming(),
      LabExperimentTemplate.creatineConsistency =>
        LabExperimentTemplates.creatineConsistency(),
      LabExperimentTemplate.preWorkoutMealTiming =>
        LabExperimentTemplates.mealTiming(),
      LabExperimentTemplate.sleepTarget => LabExperimentTemplates.sleepTarget(),
      _ => LabExperimentTemplates.caffeineTiming(),
    };
    await _preferences.addExperiment(experiment);
  }

  String _templateName(LabExperimentTemplate value) => switch (value) {
    LabExperimentTemplate.caffeineTiming => 'Caffeine timing',
    LabExperimentTemplate.creatineConsistency => 'Creatine consistency',
    LabExperimentTemplate.preWorkoutMealTiming => 'Pre-workout meal timing',
    LabExperimentTemplate.sleepTarget => 'Sleep target',
    LabExperimentTemplate.hydrationTarget => 'Hydration target',
    LabExperimentTemplate.custom => 'Custom experiment',
  };

  Future<void> _writeBodyFatReading() async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add body-fat reading'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'BODY-FAT PERCENTAGE',
            suffixText: '%',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('SAVE & WRITE'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (raw == null) return;
    final value = double.tryParse(raw);
    if (value == null || !value.isFinite || value < 0 || value > 100) {
      if (mounted) {
        setState(() => _message = 'Enter a body-fat percentage from 0 to 100.');
      }
      return;
    }
    await _run(() async {
      final metric = HealthBodyMetric(
        type: 'bodyFatPercentage',
        value: value,
        unit: '%',
        recordedAt: DateTime.now().toUtc(),
        source: 'Progression Lab',
      );
      await _preferences.addHealthBodyMetrics(<HealthBodyMetric>[metric]);
      final written = await _health.writeBodyFat(metric);
      _message = written
          ? 'Body-fat reading was saved locally and written to the health platform.'
          : 'Body-fat reading was saved locally but was not written.';
    });
  }

  Future<void> _saveShare(WorkoutSharePreferences value) =>
      _run(() => _preferences.setSharePreferences(value));

  Future<void> _privacy(
    WorkoutSharePreferences preferences, {
    bool? showExactWeights,
    bool? showDuration,
    bool? showVolume,
    bool? showBodyweight,
    bool? completionOnly,
  }) => _saveShare(
    WorkoutSharePreferences(
      template: preferences.template,
      aspect: preferences.aspect,
      includeCaption: preferences.includeCaption,
      privacy: WorkoutSharePrivacy(
        showExactWeights:
            showExactWeights ?? preferences.privacy.showExactWeights,
        showDuration: showDuration ?? preferences.privacy.showDuration,
        showBodyweight: showBodyweight ?? preferences.privacy.showBodyweight,
        showVolume: showVolume ?? preferences.privacy.showVolume,
        showDate: preferences.privacy.showDate,
        completionOnly: completionOnly ?? preferences.privacy.completionOnly,
      ),
    ),
  );

  Widget _privacySwitch(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: Text(title),
    value: value,
    onChanged: onChanged,
  );

  Widget _choice<T>({
    required String title,
    required List<T> values,
    required T selected,
    required String Function(T value) label,
    required ValueChanged<T> onSelected,
  }) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final value in values)
              ChoiceChip(
                label: Text(label(value)),
                selected: value == selected,
                onSelected: (_) => onSelected(value),
              ),
          ],
        ),
      ],
    ),
  );

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() {});
    } on Object catch (error) {
      if (mounted) setState(() => _message = '$error');
    }
  }

  Future<bool> _confirm(
    String title,
    String message, {
    required String confirmLabel,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}

class _ScrollSection extends StatelessWidget {
  const _ScrollSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
    children: children,
  );
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: <Color>[Color(0xff22d3ee), Color(0xff7c3aed)],
            ),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                eyebrow,
                style: const TextStyle(
                  color: Color(0xff22d3ee),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                description,
                style: const TextStyle(color: Colors.white60, height: 1.45),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xff11131c),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withValues(alpha: .08)),
    ),
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.detail,
    required this.positive,
  });

  final String title;
  final String detail;
  final bool positive;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Row(
      children: <Widget>[
        _Dot(positive: positive),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(detail, style: const TextStyle(color: Colors.white60)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.positive});

  final bool positive;

  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: positive ? const Color(0xff22d3ee) : Colors.white24,
      boxShadow: positive
          ? <BoxShadow>[
              BoxShadow(
                color: const Color(0xff22d3ee).withValues(alpha: .5),
                blurRadius: 12,
              ),
            ]
          : null,
    ),
  );
}

class _Info extends StatelessWidget {
  const _Info({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Color(0xffa855f7),
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 7),
        Text(text, style: const TextStyle(color: Colors.white60, height: 1.45)),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xff172033),
    child: SafeArea(
      bottom: false,
      child: ListTile(
        leading: const Icon(
          Icons.info_outline_rounded,
          color: Color(0xff22d3ee),
        ),
        title: Text(message),
        trailing: IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xff22d3ee).withValues(alpha: .1),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: const Color(0xff22d3ee).withValues(alpha: .25)),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
    ),
  );
}

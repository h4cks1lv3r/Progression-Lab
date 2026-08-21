import 'dart:async';

import 'package:flutter/material.dart';

import 'account_connectors.dart';
import 'brand.dart';
import 'cloud_backup_sync.dart';
import 'external_activity.dart';
import 'health_sync.dart';
import 'integration_settings.dart';
import 'personal_experiments.dart';
import 'store.dart';

class IntegrationsHubScreen extends StatefulWidget {
  const IntegrationsHubScreen({super.key});

  @override
  State<IntegrationsHubScreen> createState() => _IntegrationsHubScreenState();
}

class _IntegrationsHubScreenState extends State<IntegrationsHubScreen> {
  final _settingsRepository = const IntegrationSettingsRepository();
  final _activityRepository = ExternalActivityRepository();
  final _experimentRepository = PersonalExperimentRepository();
  final _store = AppStore();

  IntegrationSettings _settings = const IntegrationSettings();
  List<ExternalActivity> _activities = const <ExternalActivity>[];
  List<PersonalExperiment> _experiments = const <PersonalExperiment>[];
  HealthSyncStatus? _healthStatus;
  bool _loading = true;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await _store.load();
    final settings = await _settingsRepository.load();
    final activities = await _activityRepository.load();
    final experiments = await _experimentRepository.load();
    final healthStatus = await ProgressionHealthSync().status();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _activities = activities;
      _experiments = experiments;
      _healthStatus = healthStatus;
      _loading = false;
    });
  }

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final message = await action();
      if (!mounted) return;
      setState(() => _message = message);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveSettings(IntegrationSettings next) async {
    await _settingsRepository.save(next);
    if (!mounted) return;
    setState(() => _settings = next);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('DATA & CONNECTIONS'),
      actions: [
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(right: 18),
            child: Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ),
      ],
    ),
    body: BrandBackdrop(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                children: [
                  const _Hero(),
                  if (_message != null) ...[
                    const SizedBox(height: 14),
                    _Notice(_message!),
                  ],
                  const SizedBox(height: 18),
                  _Section(
                    title: 'HEALTH PLATFORM',
                    subtitle:
                        'Sync workout summaries and body measurements. Progression Lab remains the source of truth for detailed sets.',
                    icon: Icons.favorite_outline_rounded,
                    children: [
                      _StatusRow(
                        title: _healthStatus?.platformName ?? 'Health platform',
                        value: _healthStatus?.available == true
                            ? (_healthStatus?.authorized == true
                                  ? 'CONNECTED'
                                  : 'READY')
                            : 'UNAVAILABLE',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _healthStatus?.message ?? '',
                        style: const TextStyle(color: Colors.white60),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                    final allowed = await ProgressionHealthSync()
                                        .requestAuthorization();
                                    _healthStatus = await ProgressionHealthSync()
                                        .status();
                                    if (mounted) setState(() {});
                                    return allowed
                                        ? 'Health access granted. Your system settings stay in control.'
                                        : 'Health access was not granted.';
                                  }),
                            icon: const Icon(Icons.shield_outlined),
                            label: const Text('AUTHORIZE'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                    final result = await ProgressionHealthSync()
                                        .sync(store: _store);
                                    _activities = await _activityRepository.load();
                                    if (mounted) setState(() {});
                                    return 'Read ${result.workoutsRead} new workouts, wrote ${result.workoutsWritten}, and read ${result.bodyMeasurementsRead} body measurements.';
                                  }),
                            icon: const Icon(Icons.sync_rounded),
                            label: const Text('SYNC NOW'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'ACTIVITY FILES',
                    subtitle:
                        'Import FIT, TCX, GPX, Strava bulk exports, and Garmin exports without giving another service your Progression Lab password.',
                    icon: Icons.file_download_outlined,
                    children: [
                      _StatusRow(
                        title: 'Imported activity summaries',
                        value: '${_activities.length}',
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                final result = await ExternalActivityImporter
                                    .pickAndParse();
                                if (result == null) return 'Import cancelled.';
                                final added = await _activityRepository.addAll(
                                  result.activities,
                                );
                                _activities = await _activityRepository.load();
                                if (mounted) setState(() {});
                                final warning = result.warnings.isEmpty
                                    ? ''
                                    : ' ${result.warnings.length} file warnings were retained for review.';
                                return 'Imported $added new activities from ${result.fileName}.$warning';
                              }),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('IMPORT ACTIVITY FILES'),
                      ),
                      if (_activities.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        for (final activity in _activities.take(5))
                          _ActivityRow(activity),
                        if (_activities.length > 5)
                          Text(
                            '+ ${_activities.length - 5} more imported activities',
                            style: const TextStyle(color: Colors.white54),
                          ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  _AccountSection(
                    settings: _settings,
                    busy: _busy,
                    onRun: _run,
                    onSettingsChanged: _saveSettings,
                    onActivitiesChanged: () async {
                      _activities = await _activityRepository.load();
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  _CloudSection(
                    store: _store,
                    settings: _settings,
                    settingsRepository: _settingsRepository,
                    busy: _busy,
                    onRun: _run,
                    onSettingsChanged: _saveSettings,
                  ),
                  const SizedBox(height: 16),
                  _ExperimentSection(
                    store: _store,
                    experiments: _experiments,
                    repository: _experimentRepository,
                    onChanged: (values) {
                      if (mounted) setState(() => _experiments = values);
                    },
                  ),
                  const SizedBox(height: 16),
                  _SharingSection(
                    settings: _settings,
                    onChanged: _saveSettings,
                  ),
                  const SizedBox(height: 16),
                  _GuidesSection(
                    settings: _settings,
                    onChanged: _saveSettings,
                  ),
                ],
              ),
            ),
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          BrandColors.violet.withValues(alpha: .28),
          BrandColors.cyan.withValues(alpha: .10),
        ],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: BrandColors.violet.withValues(alpha: .35)),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR DATA. YOUR CALL.',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: .4,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Connect only what helps. Every integration is optional, reversible, and separate from your detailed Progression Lab history.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: BrandColors.cyan.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: BrandColors.cyan.withValues(alpha: .28)),
    ),
    child: Text(message, style: const TextStyle(height: 1.35)),
  );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: BrandColors.surface.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withValues(alpha: .08)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: BrandColors.cyan),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: .4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white60, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(title)),
      Text(
        value,
        style: const TextStyle(
          color: BrandColors.cyan,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow(this.activity);

  final ExternalActivity activity;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        const Icon(Icons.route_outlined, size: 19, color: Colors.white54),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${activity.source.name} · ${activity.start.toLocal().toString().split('.').first}',
                style: const TextStyle(color: Colors.white45, fontSize: 12),
              ),
            ],
          ),
        ),
        Text(
          '${activity.duration.inMinutes} min',
          style: const TextStyle(color: Colors.white60),
        ),
      ],
    ),
  );
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.settings,
    required this.busy,
    required this.onRun,
    required this.onSettingsChanged,
    required this.onActivitiesChanged,
  });

  final IntegrationSettings settings;
  final bool busy;
  final Future<void> Function(Future<String> Function()) onRun;
  final Future<void> Function(IntegrationSettings) onSettingsChanged;
  final Future<void> Function() onActivitiesChanged;

  @override
  Widget build(BuildContext context) => _Section(
    title: 'STRAVA & GARMIN',
    subtitle:
        'Direct account access requires an approved OAuth relay so provider secrets never ship inside the app. Manual exports work without one.',
    icon: Icons.hub_outlined,
    children: [
      for (final provider in ConnectedProvider.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FutureBuilder<ProviderConnectionStatus>(
            future: ConnectedAccountService().status(provider),
            builder: (context, snapshot) {
              final status = snapshot.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusRow(
                    title: provider == ConnectedProvider.strava
                        ? 'Strava'
                        : 'Garmin',
                    value: status?.connected == true
                        ? 'CONNECTED'
                        : status?.configured == true
                            ? 'READY'
                            : 'NOT CONFIGURED',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    status?.message ?? 'Checking configuration…',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: busy || status?.configured != true
                            ? null
                            : () => onRun(() async {
                                final service = ConnectedAccountService();
                                try {
                                  await service.connect(provider);
                                  return '${provider.name} connected.';
                                } finally {
                                  service.close();
                                }
                              }),
                        child: Text(status?.connected == true ? 'RECONNECT' : 'CONNECT'),
                      ),
                      OutlinedButton(
                        onPressed: busy || status?.connected != true
                            ? null
                            : () => onRun(() async {
                                final service = ConnectedAccountService();
                                try {
                                  final values = await service.importRecent(provider);
                                  await onActivitiesChanged();
                                  return 'Imported ${values.length} recent ${provider.name} activities.';
                                } finally {
                                  service.close();
                                }
                              }),
                        child: const Text('IMPORT RECENT'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      TextButton.icon(
        onPressed: () async {
          final result = await showDialog<_RelayValues>(
            context: context,
            builder: (_) => _RelayDialog(settings: settings),
          );
          if (result == null) return;
          await onSettingsChanged(
            settings.copyWith(
              stravaRelayUrl: result.strava,
              garminRelayUrl: result.garmin,
            ),
          );
        },
        icon: const Icon(Icons.settings_outlined),
        label: const Text('CONFIGURE APPROVED RELAYS'),
      ),
    ],
  );
}

class _CloudSection extends StatelessWidget {
  const _CloudSection({
    required this.store,
    required this.settings,
    required this.settingsRepository,
    required this.busy,
    required this.onRun,
    required this.onSettingsChanged,
  });

  final AppStore store;
  final IntegrationSettings settings;
  final IntegrationSettingsRepository settingsRepository;
  final bool busy;
  final Future<void> Function(Future<String> Function()) onRun;
  final Future<void> Function(IntegrationSettings) onSettingsChanged;

  @override
  Widget build(BuildContext context) => _Section(
    title: 'CROSS-PLATFORM CLOUD BACKUP',
    subtitle:
        'Use your own HTTPS WebDAV account for Android-to-iPhone backup transfer. No Progression Lab account is required.',
    icon: Icons.cloud_outlined,
    children: [
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Automatic WebDAV backup'),
        subtitle: Text(
          settings.cloudSyncEnabled
              ? 'Runs after local data changes while the app is active.'
              : 'Off. Local rolling backups still continue.',
        ),
        value: settings.cloudSyncEnabled,
        onChanged: (value) => onSettingsChanged(
          settings.copyWith(cloudSyncEnabled: value),
        ),
      ),
      _StatusRow(
        title: 'Endpoint',
        value: settings.cloudSyncUrl.isEmpty ? 'NOT SET' : 'CONFIGURED',
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: busy || settings.cloudSyncUrl.isEmpty
                ? null
                : () => onRun(() async {
                    final service = WebDavBackupSync(
                      settingsRepository: settingsRepository,
                    );
                    try {
                      return (await service.upload(
                        store: store,
                        settings: settings,
                      )).message;
                    } finally {
                      service.close();
                    }
                  }),
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('UPLOAD BACKUP'),
          ),
          OutlinedButton.icon(
            onPressed: busy || settings.cloudSyncUrl.isEmpty
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Restore cloud backup?'),
                        content: const Text(
                          'A local safety backup is created first. Current data is then replaced by the validated cloud backup.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('CANCEL'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('RESTORE'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    await onRun(() async {
                      final service = WebDavBackupSync(
                        settingsRepository: settingsRepository,
                      );
                      try {
                        return (await service.restore(
                          store: store,
                          settings: settings,
                        )).message;
                      } finally {
                        service.close();
                      }
                    });
                  },
            icon: const Icon(Icons.cloud_download_outlined),
            label: const Text('RESTORE'),
          ),
          TextButton.icon(
            onPressed: () async {
              final password = await settingsRepository.readCloudPassword();
              if (!context.mounted) return;
              final result = await showDialog<_CloudValues>(
                context: context,
                builder: (_) => _CloudDialog(
                  settings: settings,
                  password: password,
                ),
              );
              if (result == null) return;
              await settingsRepository.writeCloudPassword(result.password);
              await onSettingsChanged(
                settings.copyWith(
                  cloudSyncUrl: result.url,
                  cloudSyncUser: result.user,
                  cloudSyncPath: result.path,
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
            label: const Text('CONFIGURE'),
          ),
        ],
      ),
    ],
  );
}

class _ExperimentSection extends StatelessWidget {
  const _ExperimentSection({
    required this.store,
    required this.experiments,
    required this.repository,
    required this.onChanged,
  });

  final AppStore store;
  final List<PersonalExperiment> experiments;
  final PersonalExperimentRepository repository;
  final ValueChanged<List<PersonalExperiment>> onChanged;

  @override
  Widget build(BuildContext context) => _Section(
    title: 'PERSONAL EXPERIMENTS',
    subtitle:
        'Define one variable, one metric, and a minimum sample. Lab Core calculates the result before AI explains it.',
    icon: Icons.science_outlined,
    children: [
      if (experiments.isEmpty)
        const Text(
          'No experiments yet. Run one when there is a specific question worth testing.',
          style: TextStyle(color: Colors.white60),
        )
      else
        for (final experiment in experiments)
          Builder(
            builder: (context) {
              final result = PersonalExperimentEngine.evaluate(experiment, store);
              final effect = result.effectPercent;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(experiment.name),
                subtitle: Text(
                  '${result.conditionSamples} condition · ${result.controlSamples} control · ${result.confidence}',
                ),
                trailing: Text(
                  effect == null ? 'COLLECTING' : '${effect >= 0 ? '+' : ''}${effect.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: BrandColors.cyan,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              );
            },
          ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: () async {
          final value = await showDialog<PersonalExperiment>(
            context: context,
            builder: (_) => const _ExperimentDialog(),
          );
          if (value == null) return;
          await repository.upsert(value);
          onChanged(await repository.load());
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('NEW EXPERIMENT'),
      ),
    ],
  );
}

class _SharingSection extends StatelessWidget {
  const _SharingSection({required this.settings, required this.onChanged});

  final IntegrationSettings settings;
  final Future<void> Function(IntegrationSettings) onChanged;

  @override
  Widget build(BuildContext context) => _Section(
    title: 'SHARE STUDIO DEFAULTS',
    subtitle:
        'Choose a format and privacy defaults. Workout data stays unchanged; only the generated image is affected.',
    icon: Icons.ios_share_rounded,
    children: [
      DropdownButtonFormField<String>(
        initialValue: settings.shareTemplate,
        decoration: const InputDecoration(labelText: 'Default format'),
        items: const [
          DropdownMenuItem(value: 'story', child: Text('Instagram Story · 1080 × 1920')),
          DropdownMenuItem(value: 'portrait', child: Text('Portrait Feed · 1080 × 1350')),
          DropdownMenuItem(value: 'square', child: Text('Square · 1080 × 1080')),
          DropdownMenuItem(value: 'achievement', child: Text('Achievement / PR focus')),
        ],
        onChanged: (value) {
          if (value != null) onChanged(settings.copyWith(shareTemplate: value));
        },
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Hide exact weights'),
        value: settings.shareHideWeights,
        onChanged: (value) => onChanged(settings.copyWith(shareHideWeights: value)),
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Hide workout duration'),
        value: settings.shareHideDuration,
        onChanged: (value) => onChanged(settings.copyWith(shareHideDuration: value)),
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Hide body metrics'),
        value: settings.shareHideBodyMetrics,
        onChanged: (value) => onChanged(settings.copyWith(shareHideBodyMetrics: value)),
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Completion-only privacy mode'),
        subtitle: const Text('Share the session title and completion badge without performance numbers.'),
        value: settings.shareCompletionOnly,
        onChanged: (value) => onChanged(settings.copyWith(shareCompletionOnly: value)),
      ),
    ],
  );
}

class _GuidesSection extends StatelessWidget {
  const _GuidesSection({required this.settings, required this.onChanged});

  final IntegrationSettings settings;
  final Future<void> Function(IntegrationSettings) onChanged;

  @override
  Widget build(BuildContext context) => _Section(
    title: 'CONTEXTUAL GUIDES',
    subtitle:
        'Use short, one-time coach marks inside complex features. Essential controls never depend on a tutorial.',
    icon: Icons.explore_outlined,
    children: [
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Show contextual tips'),
        value: settings.contextualTipsEnabled,
        onChanged: (value) => onChanged(
          settings.copyWith(contextualTipsEnabled: value),
        ),
      ),
      TextButton.icon(
        onPressed: () async {
          final preferences = await IntegrationSettingsRepository().load();
          await onChanged(
            preferences.copyWith(contextualTipsEnabled: true),
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tips reset. Run the next test when you open a guided feature.'),
              ),
            );
          }
        },
        icon: const Icon(Icons.restart_alt_rounded),
        label: const Text('RESET ALL TIPS'),
      ),
    ],
  );
}

class _RelayValues {
  const _RelayValues(this.strava, this.garmin);

  final String strava;
  final String garmin;
}

class _RelayDialog extends StatefulWidget {
  const _RelayDialog({required this.settings});

  final IntegrationSettings settings;

  @override
  State<_RelayDialog> createState() => _RelayDialogState();
}

class _RelayDialogState extends State<_RelayDialog> {
  late final TextEditingController _strava;
  late final TextEditingController _garmin;

  @override
  void initState() {
    super.initState();
    _strava = TextEditingController(text: widget.settings.stravaRelayUrl);
    _garmin = TextEditingController(text: widget.settings.garminRelayUrl);
  }

  @override
  void dispose() {
    _strava.dispose();
    _garmin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Approved OAuth relays'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Do not paste provider client secrets into the app. Enter only HTTPS relay URLs operated by the build owner.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _strava,
            decoration: const InputDecoration(labelText: 'Strava relay URL'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _garmin,
            decoration: const InputDecoration(labelText: 'Garmin relay URL'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _RelayValues(_strava.text.trim(), _garmin.text.trim()),
        ),
        child: const Text('SAVE'),
      ),
    ],
  );
}

class _CloudValues {
  const _CloudValues(this.url, this.user, this.password, this.path);

  final String url;
  final String user;
  final String password;
  final String path;
}

class _CloudDialog extends StatefulWidget {
  const _CloudDialog({required this.settings, required this.password});

  final IntegrationSettings settings;
  final String password;

  @override
  State<_CloudDialog> createState() => _CloudDialogState();
}

class _CloudDialogState extends State<_CloudDialog> {
  late final TextEditingController _url;
  late final TextEditingController _user;
  late final TextEditingController _password;
  late final TextEditingController _path;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.settings.cloudSyncUrl);
    _user = TextEditingController(text: widget.settings.cloudSyncUser);
    _password = TextEditingController(text: widget.password);
    _path = TextEditingController(text: widget.settings.cloudSyncPath);
  }

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _password.dispose();
    _path.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('WebDAV backup'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'HTTPS WebDAV base URL'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _user,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password or app password'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _path,
            decoration: const InputDecoration(labelText: 'Remote backup path'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _CloudValues(
            _url.text.trim(),
            _user.text.trim(),
            _password.text,
            _path.text.trim(),
          ),
        ),
        child: const Text('SAVE'),
      ),
    ],
  );
}

class _ExperimentDialog extends StatefulWidget {
  const _ExperimentDialog();

  @override
  State<_ExperimentDialog> createState() => _ExperimentDialogState();
}

class _ExperimentDialogState extends State<_ExperimentDialog> {
  final _name = TextEditingController();
  ExperimentVariable _variable = ExperimentVariable.caffeine;
  ExperimentMetric _metric = ExperimentMetric.estimatedStrength;
  double _sessions = 12;
  double _days = 28;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New personal experiment'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Question or experiment name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ExperimentVariable>(
            initialValue: _variable,
            decoration: const InputDecoration(labelText: 'Variable'),
            items: [
              for (final value in ExperimentVariable.values)
                DropdownMenuItem(value: value, child: Text(value.name)),
            ],
            onChanged: (value) => setState(() => _variable = value ?? _variable),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ExperimentMetric>(
            initialValue: _metric,
            decoration: const InputDecoration(labelText: 'Outcome metric'),
            items: [
              for (final value in ExperimentMetric.values)
                DropdownMenuItem(value: value, child: Text(value.name)),
            ],
            onChanged: (value) => setState(() => _metric = value ?? _metric),
          ),
          const SizedBox(height: 12),
          Text('Minimum matched workouts: ${_sessions.round()}'),
          Slider(
            value: _sessions,
            min: 6,
            max: 30,
            divisions: 12,
            onChanged: (value) => setState(() => _sessions = value),
          ),
          Text('Collection window: ${_days.round()} days'),
          Slider(
            value: _days,
            min: 14,
            max: 84,
            divisions: 10,
            onChanged: (value) => setState(() => _days = value),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
      FilledButton(
        onPressed: () {
          final name = _name.text.trim();
          if (name.isEmpty) return;
          Navigator.pop(
            context,
            PersonalExperiment(
              id: 'experiment-${DateTime.now().microsecondsSinceEpoch}',
              name: name,
              variable: _variable,
              metric: _metric,
              startedAt: DateTime.now(),
              minimumMatchedSessions: _sessions.round(),
              durationDays: _days.round(),
              conditionLabel: _variable.name,
              controlLabel: 'without ${_variable.name}',
            ),
          );
        },
        child: const Text('START'),
      ),
    ],
  );
}

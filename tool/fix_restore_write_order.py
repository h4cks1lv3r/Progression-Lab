from pathlib import Path


store = Path("lib/store.dart")
text = store.read_text()
old = """  Future<void> restoreState(Map<String, dynamic> source) async {
    final importedIntegrationState = source['integrationState'];
    integrationState = importedIntegrationState is Map
        ? Map<String, dynamic>.from(importedIntegrationState)
        : <String, dynamic>{};
    final sourceVersion = _readInt(source['schemaVersion']);
    if (sourceVersion != null && sourceVersion > schemaVersion) {
      throw StateError(
        'This backup was created by a newer Progression Lab data schema '
        '(version $sourceVersion). Update the app before restoring it.',
      );
    }
    final previous = exportState();
    try {
      final migrated = _migrate(Map<String, dynamic>.from(source));
      _applyStateData(migrated);
      await _channel.invokeMethod('write', jsonEncode(exportState()));
    } on Object {
      _applyStateData(previous);
      notifyListeners();
      rethrow;
    }
    notifyListeners();
  }
"""
new = """  Future<void> restoreState(Map<String, dynamic> source) async {
    final sourceVersion = _readInt(source['schemaVersion']);
    if (sourceVersion != null && sourceVersion > schemaVersion) {
      throw StateError(
        'This backup was created by a newer Progression Lab data schema '
        '(version $sourceVersion). Update the app before restoring it.',
      );
    }
    final previous = exportState();
    try {
      final migrated = _migrate(Map<String, dynamic>.from(source));
      final importedIntegrationState = migrated['integrationState'];
      integrationState = importedIntegrationState is Map
          ? Map<String, dynamic>.from(importedIntegrationState)
          : <String, dynamic>{};
      _applyStateData(migrated);
      await _enqueueStateWrite(jsonEncode(exportState()));
    } on Object {
      final previousIntegrationState = previous['integrationState'];
      integrationState = previousIntegrationState is Map
          ? Map<String, dynamic>.from(previousIntegrationState)
          : <String, dynamic>{};
      _applyStateData(previous);
      notifyListeners();
      rethrow;
    }
    notifyListeners();
  }
"""
if new not in text:
    if old not in text:
        raise RuntimeError("restoreState block was not found")
    text = text.replace(old, new, 1)

old = """  Future<void> flushPendingSaves() => _saveTail;
"""
new = """  Future<void> flushPendingSaves() async {
    while (true) {
      final pending = _saveTail;
      await pending;
      if (identical(pending, _saveTail)) return;
    }
  }
"""
if new not in text:
    if old not in text:
        raise RuntimeError("flushPendingSaves block was not found")
    text = text.replace(old, new, 1)
store.write_text(text)


test = Path("test/persistence_onboarding_test.dart")
text = test.read_text()
old = """  String? storedState;
  List<Object?> automaticBackups = const [];

  setUp(() {
"""
new = """  String? storedState;
  List<Object?> automaticBackups = const [];
  Duration Function(Map<String, dynamic> state) writeDelay =
      (_) => const Duration(milliseconds: 20);

  setUp(() {
"""
if new not in text:
    if old not in text:
        raise RuntimeError("test state declarations were not found")
    text = text.replace(old, new, 1)
old = """    storedState = null;
    automaticBackups = const [];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
"""
new = """    storedState = null;
    automaticBackups = const [];
    writeDelay = (_) => const Duration(milliseconds: 20);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
"""
if new not in text:
    if old not in text:
        raise RuntimeError("test setup reset was not found")
    text = text.replace(old, new, 1)
old = """            case 'write':
              writesInFlight++;
              maximumWritesInFlight = maximumWritesInFlight < writesInFlight
                  ? writesInFlight
                  : maximumWritesInFlight;
              await Future<void>.delayed(const Duration(milliseconds: 20));
              final encoded = call.arguments as String;
              storedState = encoded;
              writes.add(Map<String, dynamic>.from(jsonDecode(encoded) as Map));
"""
new = """            case 'write':
              final encoded = call.arguments as String;
              final decoded = Map<String, dynamic>.from(
                jsonDecode(encoded) as Map,
              );
              writesInFlight++;
              maximumWritesInFlight = maximumWritesInFlight < writesInFlight
                  ? writesInFlight
                  : maximumWritesInFlight;
              await Future<void>.delayed(writeDelay(decoded));
              storedState = encoded;
              writes.add(decoded);
"""
if new not in text:
    if old not in text:
        raise RuntimeError("mock write handler was not found")
    text = text.replace(old, new, 1)
marker = """  test('load reports existing meaningful device data', () async {
"""
addition = """  test('backup restore cannot be overwritten by an older queued save', () async {
    writeDelay = (state) =>
        state['logs'] is List && (state['logs'] as List).isNotEmpty
        ? const Duration(milliseconds: 5)
        : const Duration(milliseconds: 80);
    final store = AppStore();

    final olderSave = store.setPreferredTrack(TrainingTrack.athletic);
    final restore = store.restoreState({
      'schemaVersion': AppStore.schemaVersion,
      'days': 4,
      'week': 1,
      'workout': 0,
      'unit': 'lb',
      'logs': [
        {
          'e': 'Barbell Bench Press',
          'w': 205,
          'r': 4,
          'd': DateTime(2026, 9, 1).toIso8601String(),
          'o': 'Upper Body A',
          'n': 'Restored history',
        },
      ],
      'integrationState': {'restored': true},
    });

    await Future.wait([olderSave, restore]);
    await store.flushPendingSaves();

    final persisted = Map<String, dynamic>.from(
      jsonDecode(storedState!) as Map,
    );
    expect(maximumWritesInFlight, 1);
    expect(persisted['logs'], hasLength(1));
    expect((persisted['integrationState'] as Map)['restored'], isTrue);
    expect(store.logs.single.notes, 'Restored history');
  });

"""
if addition not in text:
    if marker not in text:
        raise RuntimeError("restore test insertion marker was not found")
    text = text.replace(marker, addition + marker, 1)

addition = """  test('flush waits for writes appended while a flush is active', () async {
    writeDelay = (_) => const Duration(milliseconds: 40);
    final store = AppStore();

    final first = store.setPreferredTrack(TrainingTrack.athletic);
    final flush = store.flushPendingSaves();
    await Future<void>.delayed(Duration.zero);
    final second = store.markDataSetupSeen(1);

    await flush;

    expect(writes, hasLength(2));
    expect(writes.last['dataSetupVersionSeen'], 1);
    await Future.wait([first, second]);
  });

"""
if addition not in text:
    if marker not in text:
        raise RuntimeError("flush test insertion marker was not found")
    text = text.replace(marker, addition + marker, 1)
test.write_text(text)


navigation = Path("test/navigation_widget_test.dart")
text = navigation.read_text()
old = """    final store = AppStore()
      ..isLoaded = true
      ..onboardingVersionSeen = 1;
"""
new = """    final store = AppStore()
      ..isLoaded = true
      ..dataSetupVersionSeen = 1
      ..onboardingVersionSeen = 1;
"""
if new not in text:
    if old not in text:
        raise RuntimeError("navigation test store fixture was not found")
    navigation.write_text(text.replace(old, new, 1))

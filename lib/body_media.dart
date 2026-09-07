import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'body_progress.dart';

class BodyPhoto {
  const BodyPhoto({
    required this.id,
    required this.asset,
    required this.thumbnail,
    this.view = 'Front',
    this.pose = 'Relaxed',
    this.zoom = 1,
    this.x = 0,
    this.y = 0,
    this.turns = 0,
    this.coverFace = false,
    this.maskX = .25,
    this.maskY = .02,
    this.maskWidth = .5,
    this.maskHeight = .22,
  });
  final String id, asset, thumbnail, view, pose;
  final double zoom, x, y, maskX, maskY, maskWidth, maskHeight;
  final int turns;
  final bool coverFace;
  Map<String, dynamic> toJson() => {
    'id': id,
    'asset': asset,
    'thumbnail': thumbnail,
    'view': view,
    'pose': pose,
    'zoom': zoom,
    'x': x,
    'y': y,
    'turns': turns,
    'coverFace': coverFace,
    'maskX': maskX,
    'maskY': maskY,
    'maskWidth': maskWidth,
    'maskHeight': maskHeight,
  };
  factory BodyPhoto.fromJson(Map<String, dynamic> j) {
    double n(String key, double fallback) =>
        (j[key] as num?)?.toDouble() ?? fallback;
    return BodyPhoto(
      id: j['id'] as String,
      asset: j['asset'] as String,
      thumbnail: j['thumbnail'] as String,
      view: j['view'] as String? ?? 'Front',
      pose: j['pose'] as String? ?? 'Relaxed',
      zoom: n('zoom', 1).clamp(1, 4),
      x: n('x', 0).clamp(-1, 1),
      y: n('y', 0).clamp(-1, 1),
      turns: (j['turns'] as int? ?? 0) % 4,
      coverFace: j['coverFace'] == true,
      maskX: n('maskX', .25).clamp(0, 1),
      maskY: n('maskY', .02).clamp(0, 1),
      maskWidth: n('maskWidth', .5).clamp(.05, 1),
      maskHeight: n('maskHeight', .22).clamp(.05, 1),
    );
  }
  BodyPhoto edit(Map<String, dynamic> v) =>
      BodyPhoto.fromJson({...toJson(), ...v});
}

class BodyCheckIn {
  const BodyCheckIn({
    required this.id,
    required this.date,
    this.notes = '',
    this.setup = '',
    this.photos = const [],
  });
  final String id, date, notes, setup;
  final List<BodyPhoto> photos;
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'notes': notes,
    'setup': setup,
    'photos': photos.map((p) => p.toJson()).toList(),
  };
  factory BodyCheckIn.fromJson(Map<String, dynamic> j) => BodyCheckIn(
    id: j['id'] as String,
    date: j['date'] as String,
    notes: j['notes'] as String? ?? '',
    setup: j['setup'] as String? ?? '',
    photos: (j['photos'] as List? ?? [])
        .whereType<Map>()
        .map((p) => BodyPhoto.fromJson(Map<String, dynamic>.from(p)))
        .toList(),
  );
}

class BodyMediaStore extends ChangeNotifier {
  static const channel = MethodChannel('progression_lab/body_media');
  String directory = '';
  List<BodyCheckIn> checkIns = [];
  Map<String, dynamic>? draft;
  bool loaded = false;
  String? error;
  bool lockEnabled = false;
  bool sessionUnlocked = false;
  void relock() {
    sessionUnlocked = false;
    notifyListeners();
  }

  int reminderDays = 0;
  String? lastBackup;
  Map<String, dynamic> get journal => {
    'version': 1,
    'checkIns': checkIns.map((c) => c.toJson()).toList(),
    'draft': draft,
    'lockEnabled': lockEnabled,
    'reminderDays': reminderDays,
    'lastBackup': lastBackup,
  };
  void apply(Map<String, dynamic> j) {
    checkIns =
        (j['checkIns'] as List? ?? [])
            .whereType<Map>()
            .map((c) => BodyCheckIn.fromJson(Map<String, dynamic>.from(c)))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    draft = j['draft'] is Map ? Map<String, dynamic>.from(j['draft']) : null;
    lockEnabled = j['lockEnabled'] == true;
    reminderDays = (j['reminderDays'] as num?)?.toInt() ?? 0;
    lastBackup = j['lastBackup'] as String?;
  }

  Future<void> load() async {
    try {
      final raw = await channel.invokeMapMethod<String, dynamic>('load');
      directory = raw?['directory'] as String? ?? '';
      apply(Map<String, dynamic>.from(raw?['journal'] as Map? ?? {}));
      loaded = true;
      error = null;
    } on MissingPluginException {
      loaded = true;
    } on Object {
      error =
          'Your private photo journal could not be opened. Try again before making changes.';
    }
    notifyListeners();
  }

  Future<void> save(Map<String, dynamic> next) async {
    await channel.invokeMethod<void>('saveJournal', jsonEncode(next));
    apply(next);
    notifyListeners();
  }

  Future<BodyPhoto> importPhoto(String path) async {
    final raw = await channel.invokeMapMethod<String, dynamic>('importPhoto', {
      'path': path,
    });
    if (raw == null) throw StateError('The photo could not be imported.');
    return BodyPhoto(
      id: bodyId(),
      asset: raw['asset'] as String,
      thumbnail: raw['thumbnail'] as String,
    );
  }

  String path(BodyPhoto p, {bool thumb = false}) =>
      '$directory/${thumb ? p.thumbnail : p.asset}';
  Future<bool> unlock() async {
    final ok = await channel.invokeMethod<bool>('unlock') ?? false;
    if (ok) {
      sessionUnlocked = true;
      notifyListeners();
    }
    return ok;
  }

  Future<void> protectScreen(bool enabled) =>
      channel.invokeMethod<void>('protectScreen', enabled);
  Future<void> setReminder(int days) async {
    final allowed =
        await channel.invokeMethod<bool>('setReminder', {'days': days}) ??
        false;
    if (!allowed && days > 0)
      throw StateError(
        'Allow notifications in Android settings to enable reminders.',
      );
    await save({...journal, 'reminderDays': days});
  }

  Future<String?> exportArchive(
    Map<String, dynamic> data,
    String password, {
    required bool photos,
  }) => channel.invokeMethod<String>('exportArchive', {
    'bundle': jsonEncode({...data, 'journal': journal}),
    'password': password,
    'photos': photos,
  });
  Future<Map<String, dynamic>?> importArchive(String password) async =>
      channel.invokeMapMethod<String, dynamic>('importArchive', {
        'password': password,
      });
  Future<void> discardImport(String token) =>
      channel.invokeMethod<void>('discardImport', {'token': token});
  Future<void> commit(
    Map<String, dynamic> state,
    Map<String, dynamic> next, {
    String? token,
  }) async {
    await channel.invokeMethod<void>('commit', {
      'state': jsonEncode(state),
      'journal': jsonEncode(next),
      if (token != null) 'token': token,
    });
    apply(next);
    notifyListeners();
  }
}

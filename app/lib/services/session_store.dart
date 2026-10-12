import 'dart:convert';
import 'dart:io';

import 'package:ergo_core/ergo_core.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// What a saved session's `session.json` holds.
@immutable
class SessionMeta {
  const SessionMeta({
    required this.id,
    required this.taskName,
    required this.startedAt,
    required this.inputs,
    required this.summary,
    this.inputsChanged = false,
    this.hasVideo = false,
    this.engineVersion = ergoCoreVersion,
  });

  factory SessionMeta.fromJson(Map<String, Object?> j) => SessionMeta(
    id: j['id']! as String,
    taskName: (j['taskName'] as String?) ?? '',
    startedAt: DateTime.parse(j['startedAt']! as String),
    inputs: sessionInputsFromJson(
      (j['inputs'] as Map?)?.cast<String, Object?>() ?? const {},
    ),
    summary: SessionSummary.fromJson(
      (j['summary']! as Map).cast<String, Object?>(),
    ),
    inputsChanged: j['inputsChanged'] == true,
    hasVideo: j['video'] != null,
    engineVersion: (j['engineVersion'] as String?) ?? 'unknown',
  );

  /// Folder name; sortable timestamp, e.g. `20261012-143005`.
  final String id;
  final String taskName;
  final DateTime startedAt;

  /// Setup when recording started.
  final SessionInputs inputs;

  /// True if the setup was edited during the recording; per-frame scores
  /// always use the setup in force at that frame.
  final bool inputsChanged;
  final SessionSummary summary;
  final bool hasVideo;

  /// ergo_core version that produced the scores.
  final String engineVersion;

  String get title => taskName.isEmpty ? 'Session $id' : taskName;

  Map<String, Object?> toJson() => {
    'formatVersion': 1,
    'id': id,
    'taskName': taskName,
    'startedAt': startedAt.toIso8601String(),
    'engineVersion': engineVersion,
    'inputs': sessionInputsToJson(inputs),
    'inputsChanged': inputsChanged,
    'summary': summary.toJson(),
    'video': hasVideo ? SessionStore.videoFile : null,
    'frames': SessionStore.framesFile,
  };
}

/// Sessions on the phone, one self-contained folder each:
///
/// ```
/// sessions/<id>/session.json   setup, summary, versions
/// sessions/<id>/frames.jsonl   one frame per line (ARCHITECTURE wire format)
/// sessions/<id>/video.mp4      when recorded
/// sessions/<id>/frames.csv     written on export
/// ```
///
/// Folders are self-contained so they can later be uploaded as a unit.
class SessionStore {
  SessionStore(this.root);

  static const metaFile = 'session.json';
  static const framesFile = 'frames.jsonl';
  static const videoFile = 'video.mp4';
  static const csvFile = 'frames.csv';

  /// App-private documents folder (removed when the app is uninstalled).
  static Future<SessionStore> open() async {
    final docs = await getApplicationDocumentsDirectory();
    return SessionStore(Directory('${docs.path}/sessions'));
  }

  final Directory root;

  Directory dirOf(String id) => Directory('${root.path}/$id');
  File fileOf(String id, String name) => File('${dirOf(id).path}/$name');
  File? videoOf(SessionMeta m) => m.hasVideo ? fileOf(m.id, videoFile) : null;

  /// Saves a recording. [videoPath] is moved into the session folder.
  Future<SessionMeta> save({
    required String taskName,
    required DateTime startedAt,
    required SessionInputs inputs,
    required List<FrameScore> frames,
    bool inputsChanged = false,
    String? videoPath,
  }) async {
    final id = await _newId(startedAt);
    final dir = await dirOf(id).create(recursive: true);

    final sink = fileOf(id, framesFile).openWrite();
    for (final f in frames) {
      sink.writeln(jsonEncode(frameScoreToJson(f)));
    }
    await sink.close();

    var hasVideo = false;
    if (videoPath != null && File(videoPath).existsSync()) {
      await _move(File(videoPath), fileOf(id, videoFile));
      hasVideo = true;
    }

    final meta = SessionMeta(
      id: id,
      taskName: taskName,
      startedAt: startedAt,
      inputs: inputs,
      inputsChanged: inputsChanged,
      summary: SessionSummary.of(frames),
      hasVideo: hasVideo,
    );
    await File(
      '${dir.path}/$metaFile',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(meta.toJson()));
    return meta;
  }

  /// Saved sessions, newest first. Unreadable folders are skipped.
  Future<List<SessionMeta>> list() async {
    if (!root.existsSync()) return [];
    final out = <SessionMeta>[];
    await for (final e in root.list()) {
      if (e is! Directory) continue;
      final f = File('${e.path}/$metaFile');
      if (!f.existsSync()) continue;
      try {
        out.add(
          SessionMeta.fromJson(
            jsonDecode(await f.readAsString()) as Map<String, Object?>,
          ),
        );
      } on Object catch (err) {
        debugPrint('Skipping unreadable session ${e.path}: $err');
      }
    }
    return out..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  Future<List<FrameScore>> frames(String id) async {
    final f = fileOf(id, framesFile);
    if (!f.existsSync()) return [];
    final lines = await f.readAsLines();
    return [
      for (final l in lines)
        if (l.trim().isNotEmpty)
          frameScoreFromJson(jsonDecode(l) as Map<String, Object?>),
    ];
  }

  /// Writes (or refreshes) `frames.csv` for export.
  Future<File> csv(String id) async =>
      fileOf(id, csvFile).writeAsString(framesToCsv(await frames(id)));

  /// Files to share for a session's data (not the video).
  Future<List<File>> dataFiles(String id) async => [
    fileOf(id, metaFile),
    await csv(id),
    fileOf(id, framesFile),
  ];

  Future<void> delete(String id) async {
    final d = dirOf(id);
    if (d.existsSync()) await d.delete(recursive: true);
  }

  Future<String> _newId(DateTime t) async {
    String two(int v) => v.toString().padLeft(2, '0');
    final base =
        '${t.year}${two(t.month)}${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
    var id = base;
    for (var n = 2; dirOf(id).existsSync(); n++) {
      id = '$base-$n';
    }
    return id;
  }

  static Future<void> _move(File from, File to) async {
    try {
      await from.rename(to.path);
    } on FileSystemException {
      // Different volume: copy, then remove the temp file.
      await from.copy(to.path);
      await from.delete();
    }
  }
}

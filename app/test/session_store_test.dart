import 'dart:convert';
import 'dart:io';

import 'package:ergo_core/ergo_core.dart';
import 'package:ergocam/features/session/session_format.dart';
import 'package:ergocam/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

Duration ms(int v) => Duration(milliseconds: v);

FrameScore scored(Duration t, {int knee = 0, double kg = 0}) {
  final angles = JointAngles(
    trunkFlexion: 40,
    neckFlexion: 25,
    kneeFlexion: knee.toDouble(),
    nearArm: const ArmAngles(upperArmFlexion: 30, elbowFlexion: 20),
  );
  final inputs = SessionInputs(loadKg: kg, coupling: Coupling.fair);
  final reba = scoreReba(angles, inputs);
  return FrameScore.scored(
    timestamp: t,
    pose: null,
    angles: angles,
    reba: reba,
    owas: scoreOwas(angles, inputs),
    regions: RegionLevels.of(reba),
  );
}

FrameScore unscored(Duration t) =>
    FrameScore.unscored(timestamp: t, unscoredReason: 'No person detected');

void main() {
  late Directory tmp;
  late SessionStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ergocam_store_');
    store = SessionStore(Directory('${tmp.path}/sessions'));
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  final log = [
    scored(ms(0)),
    unscored(ms(100)),
    scored(ms(200), knee: 100, kg: 15),
  ];

  test('saves a self-contained folder and lists it', () async {
    final video = File('${tmp.path}/REC123.mp4')..writeAsBytesSync([1, 2, 3]);
    final meta = await store.save(
      taskName: 'Lift box',
      startedAt: DateTime(2026, 10, 12, 14, 30, 5),
      inputs: const SessionInputs(loadKg: 15, coupling: Coupling.fair),
      frames: log,
      videoPath: video.path,
    );

    expect(meta.id, '20261012-143005');
    expect(meta.hasVideo, isTrue);
    expect(video.existsSync(), isFalse, reason: 'temp video is moved');
    final dir = store.dirOf(meta.id);
    expect(dir.listSync().map((e) => e.uri.pathSegments.last).toSet(), {
      'session.json',
      'frames.jsonl',
      'video.mp4',
    });

    final json = jsonDecode(
      File('${dir.path}/session.json').readAsStringSync(),
    ) as Map<String, Object?>;
    expect(json['formatVersion'], 1);
    expect(json['engineVersion'], ergoCoreVersion);
    expect((json['summary']! as Map)['scoredFrames'], 2);

    final listed = await store.list();
    expect(listed.single.title, 'Lift box');
    expect(listed.single.summary.rebaMax, meta.summary.rebaMax);
    expect(listed.single.inputs.loadKg, 15);
  });

  test('frame log round-trips', () async {
    final meta = await store.save(
      taskName: '',
      startedAt: DateTime(2026),
      inputs: const SessionInputs(),
      frames: log,
    );
    final back = await store.frames(meta.id);
    expect(back, hasLength(3));
    expect(back[1].isScored, isFalse);
    expect(back[2].reba!.score, log[2].reba!.score);
    expect(meta.hasVideo, isFalse);
    expect(meta.title, startsWith('Session '));
  });

  test('same start second gets a distinct id', () async {
    final t = DateTime(2026, 1, 2, 3, 4, 5);
    final a = await store.save(
      taskName: 'a',
      startedAt: t,
      inputs: const SessionInputs(),
      frames: log,
    );
    final b = await store.save(
      taskName: 'b',
      startedAt: t,
      inputs: const SessionInputs(),
      frames: log,
    );
    expect(a.id, isNot(b.id));
    expect(await store.list(), hasLength(2));
  });

  test('export writes a CSV next to the data', () async {
    final meta = await store.save(
      taskName: 'x',
      startedAt: DateTime(2026),
      inputs: const SessionInputs(),
      frames: log,
    );
    final files = await store.dataFiles(meta.id);
    expect(files.map((f) => f.uri.pathSegments.last), [
      'session.json',
      'frames.csv',
      'frames.jsonl',
    ]);
    final csv = files[1].readAsStringSync().split('\r\n');
    expect(csv.first, frameCsvHeader.join(','));
    expect(csv, hasLength(5)); // header + 3 rows + trailing empty
  });

  test('delete removes the folder; broken folders are skipped', () async {
    final meta = await store.save(
      taskName: 'x',
      startedAt: DateTime(2026),
      inputs: const SessionInputs(),
      frames: log,
    );
    Directory('${store.root.path}/junk').createSync();
    File('${store.root.path}/junk/session.json').writeAsStringSync('{oops');
    expect(await store.list(), hasLength(1));

    await store.delete(meta.id);
    expect(store.dirOf(meta.id).existsSync(), isFalse);
    expect(await store.list(), isEmpty);
  });

  group('frameAt', () {
    final frames = [scored(ms(0)), scored(ms(100)), scored(ms(600))];

    test('picks the last frame at or before t', () {
      expect(frameAt(frames, ms(150))!.timestamp, ms(100));
      expect(frameAt(frames, ms(600))!.timestamp, ms(600));
    });

    test('nothing before the first frame or across a long gap', () {
      expect(frameAt(frames, ms(-1)), isNull);
      expect(frameAt(frames, ms(400)), isNull);
      expect(frameAt(const [], ms(0)), isNull);
    });
  });
}

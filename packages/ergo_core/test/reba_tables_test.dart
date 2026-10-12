import 'dart:io';

import 'package:ergo_core/ergo_core.dart';
import 'package:test/test.dart';

/// Reads the markdown table that follows [marker] in docs/SCORING.md and
/// returns its numeric rows (first column = row label, dropped).
List<List<int>> tableAfter(List<String> doc, String marker) {
  final start = doc.indexWhere((l) => l.trim() == marker);
  if (start < 0) throw StateError('"$marker" not found in SCORING.md');
  final rows = <List<int>>[];
  for (final line in doc.skip(start + 1)) {
    final t = line.trim();
    if (!t.startsWith('|')) {
      if (rows.isNotEmpty) break;
      continue;
    }
    final cells = t
        .split('|')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    final label = int.tryParse(cells.first);
    if (label == null) continue; // header or separator
    rows.add(cells.skip(1).map(int.parse).toList());
  }
  return rows;
}

void main() {
  final doc = File('../../docs/SCORING.md').readAsLinesSync();

  group('transcription matches docs/SCORING.md', () {
    for (var neck = 1; neck <= 3; neck++) {
      final expected = tableAfter(doc, 'Neck = $neck');
      for (var trunk = 1; trunk <= 5; trunk++) {
        test('Table A neck $neck trunk $trunk', () {
          expect(rebaTableA[neck - 1][trunk - 1], expected[trunk - 1]);
        });
      }
    }
    for (var la = 1; la <= 2; la++) {
      final expected = tableAfter(doc, 'Lower arm = $la');
      for (var ua = 1; ua <= 6; ua++) {
        test('Table B lower arm $la upper arm $ua', () {
          expect(rebaTableB[la - 1][ua - 1], expected[ua - 1]);
        });
      }
    }
    final c = tableAfter(
      doc,
      '### Table C — rows: Score A 1–12, columns: Score B 1–12',
    );
    for (var a = 1; a <= 12; a++) {
      test('Table C score A $a', () {
        expect(rebaTableC[a - 1], c[a - 1]);
      });
    }
  });

  group('table shape', () {
    test('Table A is 3×5×4', () {
      expect(rebaTableA, hasLength(3));
      for (final n in rebaTableA) {
        expect(n, hasLength(5));
        for (final row in n) {
          expect(row, hasLength(4));
        }
      }
    });

    test('Table B is 2×6×3', () {
      expect(rebaTableB, hasLength(2));
      for (final l in rebaTableB) {
        expect(l, hasLength(6));
        for (final row in l) {
          expect(row, hasLength(3));
        }
      }
    });

    test('Table C is 12×12', () {
      expect(rebaTableC, hasLength(12));
      for (final row in rebaTableC) {
        expect(row, hasLength(12));
      }
    });
  });

  // Worse posture never lowers the score: a cheap guard against typos that
  // happen to be copied consistently into both doc and code.
  group('tables never decrease along any axis', () {
    void checkGrid(String name, List<List<int>> g) {
      for (var r = 0; r < g.length; r++) {
        for (var c = 0; c < g[r].length; c++) {
          if (c > 0) {
            expect(
              g[r][c],
              greaterThanOrEqualTo(g[r][c - 1]),
              reason: '$name row ${r + 1} col ${c + 1}',
            );
          }
          if (r > 0) {
            expect(
              g[r][c],
              greaterThanOrEqualTo(g[r - 1][c]),
              reason: '$name row ${r + 1} col ${c + 1}',
            );
          }
        }
      }
    }

    test('Table A per neck score', () {
      for (var n = 0; n < 3; n++) {
        checkGrid('A neck ${n + 1}', rebaTableA[n]);
      }
    });

    test('Table A across neck scores', () {
      for (var n = 1; n < 3; n++) {
        for (var t = 0; t < 5; t++) {
          for (var l = 0; l < 4; l++) {
            expect(
              rebaTableA[n][t][l],
              greaterThanOrEqualTo(rebaTableA[n - 1][t][l]),
            );
          }
        }
      }
    });

    test('Table B per lower-arm score and across', () {
      checkGrid('B la 1', rebaTableB[0]);
      checkGrid('B la 2', rebaTableB[1]);
      for (var u = 0; u < 6; u++) {
        for (var w = 0; w < 3; w++) {
          expect(
            rebaTableB[1][u][w],
            greaterThanOrEqualTo(rebaTableB[0][u][w]),
          );
        }
      }
    });

    test('Table C', () => checkGrid('C', rebaTableC));
  });

  group('lookups', () {
    test('use 1-based scores', () {
      expect(rebaTableALookup(neck: 3, trunk: 5, legs: 4), 9);
      expect(rebaTableBLookup(lowerArm: 2, upperArm: 6, wrist: 3), 9);
      expect(rebaTableCLookup(scoreA: 6, scoreB: 9), 10);
    });

    test('reject out-of-range scores', () {
      expect(
        () => rebaTableALookup(neck: 4, trunk: 1, legs: 1),
        throwsRangeError,
      );
      expect(
        () => rebaTableBLookup(lowerArm: 1, upperArm: 0, wrist: 1),
        throwsRangeError,
      );
      expect(() => rebaTableCLookup(scoreA: 1, scoreB: 13), throwsRangeError);
    });
  });
}

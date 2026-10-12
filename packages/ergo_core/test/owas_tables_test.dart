import 'dart:io';

import 'package:ergo_core/ergo_core.dart';
import 'package:test/test.dart';

/// Parses the OWAS table in docs/SCORING.md into
/// `{(back, arms): [[load1, load2, load3] × legs 1..7]}`.
Map<(int, int), List<List<int>>> owasTableFromDoc() {
  final doc = File('../../docs/SCORING.md').readAsLinesSync();
  final start = doc.indexWhere(
    (l) => l.trim() == '### OWAS action-category table',
  );
  if (start < 0) throw StateError('OWAS table heading not found');
  final out = <(int, int), List<List<int>>>{};
  for (final line in doc.skip(start + 1)) {
    if (line.startsWith('#')) break;
    final cells = line
        .split('|')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    if (cells.length != 9) continue;
    final back = int.tryParse(cells[0]), arms = int.tryParse(cells[1]);
    if (back == null || arms == null) continue; // header / separator
    out[(back, arms)] = [
      for (final c in cells.skip(2)) c.split('/').map(int.parse).toList(),
    ];
  }
  return out;
}

void main() {
  final doc = owasTableFromDoc();

  test('doc table has all 12 back/arms rows', () {
    expect(doc.keys, hasLength(12));
  });

  group('transcription matches docs/SCORING.md', () {
    for (var back = 1; back <= 4; back++) {
      for (var arms = 1; arms <= 3; arms++) {
        test('back $back, arms $arms', () {
          expect(owasActionTable[back - 1][arms - 1], doc[(back, arms)]);
        });
      }
    }
  });

  test('table is 4×3×7×3 with categories 1–4', () {
    expect(owasActionTable, hasLength(4));
    var cells = 0;
    for (final b in owasActionTable) {
      expect(b, hasLength(3));
      for (final a in b) {
        expect(a, hasLength(7));
        for (final legs in a) {
          expect(legs, hasLength(3));
          for (final c in legs) {
            expect(c, inInclusiveRange(1, 4));
            cells++;
          }
        }
      }
    }
    expect(cells, 252);
  });

  // Spot checks of cells quoted in the cited sources' worked examples and
  // in docs/SCORING.md.
  test('known cells', () {
    expect(owasActionCategoryFor(back: 1, arms: 1, legs: 2, load: 1), 1);
    expect(owasActionCategoryFor(back: 2, arms: 1, legs: 4, load: 1), 3);
    expect(owasActionCategoryFor(back: 2, arms: 2, legs: 4, load: 2), 4);
    expect(owasActionCategoryFor(back: 4, arms: 3, legs: 1, load: 1), 4);
    expect(owasActionCategoryFor(back: 3, arms: 3, legs: 2, load: 3), 1);
  });

  test('lookup rejects out-of-range codes', () {
    expect(
      () => owasActionCategoryFor(back: 5, arms: 1, legs: 1, load: 1),
      throwsRangeError,
    );
    expect(
      () => owasActionCategoryFor(back: 1, arms: 1, legs: 8, load: 1),
      throwsRangeError,
    );
  });
}

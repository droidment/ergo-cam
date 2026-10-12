// REBA lookup tables, transcribed from docs/SCORING.md (Hignett & McAtamney,
// 2000, Applied Ergonomics 31:201–205). test/reba_tables_test.dart re-reads
// SCORING.md and checks every cell, so edit the doc first, then this file.

/// Table A, indexed `[neck - 1][trunk - 1][legs - 1]`.
const List<List<List<int>>> rebaTableA = [
  // Neck = 1
  [
    [1, 2, 3, 4],
    [2, 3, 4, 5],
    [2, 4, 5, 6],
    [3, 5, 6, 7],
    [4, 6, 7, 8],
  ],
  // Neck = 2
  [
    [1, 2, 3, 4],
    [3, 4, 5, 6],
    [4, 5, 6, 7],
    [5, 6, 7, 8],
    [6, 7, 8, 9],
  ],
  // Neck = 3
  [
    [3, 3, 5, 6],
    [4, 5, 6, 7],
    [5, 6, 7, 8],
    [6, 7, 8, 9],
    [7, 8, 9, 9],
  ],
];

/// Table B, indexed `[lowerArm - 1][upperArm - 1][wrist - 1]`.
const List<List<List<int>>> rebaTableB = [
  // Lower arm = 1
  [
    [1, 2, 2],
    [1, 2, 3],
    [3, 4, 5],
    [4, 5, 5],
    [6, 7, 8],
    [7, 8, 8],
  ],
  // Lower arm = 2
  [
    [1, 2, 3],
    [2, 3, 4],
    [4, 5, 5],
    [5, 6, 7],
    [7, 8, 8],
    [8, 9, 9],
  ],
];

/// Table C, indexed `[scoreA - 1][scoreB - 1]`.
const List<List<int>> rebaTableC = [
  [1, 1, 1, 2, 3, 3, 4, 5, 6, 7, 7, 7],
  [1, 2, 2, 3, 4, 4, 5, 6, 6, 7, 7, 8],
  [2, 3, 3, 3, 4, 5, 6, 7, 7, 8, 8, 8],
  [3, 4, 4, 4, 5, 6, 7, 8, 8, 9, 9, 9],
  [4, 4, 4, 5, 6, 7, 8, 8, 9, 9, 9, 9],
  [6, 6, 6, 7, 8, 8, 9, 9, 10, 10, 10, 10],
  [7, 7, 7, 8, 9, 9, 9, 10, 10, 11, 11, 11],
  [8, 8, 8, 9, 10, 10, 10, 10, 10, 11, 11, 11],
  [9, 9, 9, 10, 10, 10, 11, 11, 11, 12, 12, 12],
  [10, 10, 10, 11, 11, 11, 11, 12, 12, 12, 12, 12],
  [11, 11, 11, 11, 12, 12, 12, 12, 12, 12, 12, 12],
  [12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12],
];

int rebaTableALookup({
  required int neck,
  required int trunk,
  required int legs,
}) =>
    rebaTableA[_idx(neck, 3, 'neck')][_idx(trunk, 5, 'trunk')][_idx(
      legs,
      4,
      'legs',
    )];

int rebaTableBLookup({
  required int lowerArm,
  required int upperArm,
  required int wrist,
}) =>
    rebaTableB[_idx(lowerArm, 2, 'lowerArm')][_idx(
      upperArm,
      6,
      'upperArm',
    )][_idx(wrist, 3, 'wrist')];

int rebaTableCLookup({required int scoreA, required int scoreB}) =>
    rebaTableC[_idx(scoreA, 12, 'scoreA')][_idx(scoreB, 12, 'scoreB')];

int _idx(int score, int max, String name) {
  if (score < 1 || score > max) {
    throw RangeError.range(score, 1, max, name);
  }
  return score - 1;
}

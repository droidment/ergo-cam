// OWAS action categories (1 no action · 2 corrective action in the near
// future · 3 as soon as possible · 4 immediately) for every posture code.
//
// Method: Karhu, Kansi & Kuorinka (1977), "Correcting working postures in
// industry: A practical method for analysis", Applied Ergonomics 8(4):199–201.
// The original is not openly available; this table is transcribed from, and
// agrees cell for cell with, all of:
//   1. Joung, Park & Kang (2022), Int. J. Environ. Res. Public Health
//      19(15):9768, Figure 4. doi:10.3390/ijerph19159768
//   2. Chowdhury, Boricha & Yardi (2012), Indian J. Occup. Environ. Med.
//      16(1):3–8, Figure 2. doi:10.4103/0019-5278.99679
//   3. Diego-Mas, "Método OWAS", Ergonautas, Universidad Politécnica de
//      Valencia, Tabla 6. https://www.ergonautas.upv.es/metodos/owas/owas-ayuda.php
// Known disagreement: Lins & Hein (2022), BMC Musculoskelet. Disord., Table 5
// (min–max per cell) differs at back 3 / arms 3 / legs 1–3. See
// docs/SCORING.md. test/owas_tables_test.dart re-reads the copy in
// SCORING.md and checks every cell.

/// Indexed `[back - 1][arms - 1][legs - 1][load - 1]`.
const List<List<List<List<int>>>> owasActionTable = [
  // Back = 1
  [
    // Arms = 1; legs 1..7, each [load 1, 2, 3]
    [
      [1, 1, 1],
      [1, 1, 1],
      [1, 1, 1],
      [2, 2, 2],
      [2, 2, 2],
      [1, 1, 1],
      [1, 1, 1],
    ],
    // Arms = 2; legs 1..7, each [load 1, 2, 3]
    [
      [1, 1, 1],
      [1, 1, 1],
      [1, 1, 1],
      [2, 2, 2],
      [2, 2, 2],
      [1, 1, 1],
      [1, 1, 1],
    ],
    // Arms = 3; legs 1..7, each [load 1, 2, 3]
    [
      [1, 1, 1],
      [1, 1, 1],
      [1, 1, 1],
      [2, 2, 3],
      [2, 2, 3],
      [1, 1, 1],
      [1, 1, 2],
    ],
  ],
  // Back = 2
  [
    // Arms = 1; legs 1..7, each [load 1, 2, 3]
    [
      [2, 2, 3],
      [2, 2, 3],
      [2, 2, 3],
      [3, 3, 3],
      [3, 3, 3],
      [2, 2, 2],
      [2, 3, 3],
    ],
    // Arms = 2; legs 1..7, each [load 1, 2, 3]
    [
      [2, 2, 3],
      [2, 2, 3],
      [2, 3, 3],
      [3, 4, 4],
      [3, 4, 4],
      [3, 3, 4],
      [2, 3, 4],
    ],
    // Arms = 3; legs 1..7, each [load 1, 2, 3]
    [
      [3, 3, 4],
      [2, 2, 3],
      [3, 3, 3],
      [3, 4, 4],
      [4, 4, 4],
      [4, 4, 4],
      [2, 3, 4],
    ],
  ],
  // Back = 3
  [
    // Arms = 1; legs 1..7, each [load 1, 2, 3]
    [
      [1, 1, 1],
      [1, 1, 1],
      [1, 1, 2],
      [3, 3, 3],
      [4, 4, 4],
      [1, 1, 1],
      [1, 1, 1],
    ],
    // Arms = 2; legs 1..7, each [load 1, 2, 3]
    [
      [2, 2, 3],
      [1, 1, 1],
      [1, 1, 2],
      [4, 4, 4],
      [4, 4, 4],
      [3, 3, 3],
      [1, 1, 1],
    ],
    // Arms = 3; legs 1..7, each [load 1, 2, 3]
    [
      [2, 2, 3],
      [1, 1, 1],
      [2, 3, 3],
      [4, 4, 4],
      [4, 4, 4],
      [4, 4, 4],
      [1, 1, 1],
    ],
  ],
  // Back = 4
  [
    // Arms = 1; legs 1..7, each [load 1, 2, 3]
    [
      [2, 3, 3],
      [2, 2, 3],
      [2, 2, 3],
      [4, 4, 4],
      [4, 4, 4],
      [4, 4, 4],
      [2, 3, 4],
    ],
    // Arms = 2; legs 1..7, each [load 1, 2, 3]
    [
      [3, 3, 4],
      [2, 3, 4],
      [3, 3, 4],
      [4, 4, 4],
      [4, 4, 4],
      [4, 4, 4],
      [2, 3, 4],
    ],
    // Arms = 3; legs 1..7, each [load 1, 2, 3]
    [
      [4, 4, 4],
      [2, 3, 4],
      [3, 3, 4],
      [4, 4, 4],
      [4, 4, 4],
      [4, 4, 4],
      [2, 3, 4],
    ],
  ],
];

/// Action category 1–4 for a posture code.
int owasActionCategoryFor({
  required int back,
  required int arms,
  required int legs,
  required int load,
}) {
  RangeError.checkValueInInterval(back, 1, 4, 'back');
  RangeError.checkValueInInterval(arms, 1, 3, 'arms');
  RangeError.checkValueInInterval(legs, 1, 7, 'legs');
  RangeError.checkValueInInterval(load, 1, 3, 'load');
  return owasActionTable[back - 1][arms - 1][legs - 1][load - 1];
}

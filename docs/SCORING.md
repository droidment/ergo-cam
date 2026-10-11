# Scoring Spec

Reference: Hignett & McAtamney (2000), "Rapid Entire Body Assessment (REBA)",
Applied Ergonomics 31. OWAS: Karhu, Kansi & Kuorinka (1977). Verify tables against
these sources before the demo. Do not "fill in" any value from memory.

## Angle definitions (2D, side view)
Use the gravity vector from the accelerometer as "vertical", projected into the image.
Use the side of the body nearest the camera (higher landmark visibility).

| Angle | Definition |
|---|---|
| Trunk flexion | hip-mid → shoulder-mid vs vertical. Forward = +, backward = extension |
| Neck flexion | (shoulder-mid → ear-mid) vs trunk vector. Forward = + |
| Upper arm | shoulder → elbow vs trunk vector (pointing down). Forward = flexion |
| Elbow (lower arm) | flexion = 180° − interior(shoulder, elbow, wrist) |
| Knee | flexion = 180° − interior(hip, knee, ankle) |
| Wrist | Not reliable from ML Kit. Default score 1; manual override in setup |
| Twist / side bend | Not reliable in 2D. Manual toggles in setup (+1 when on) |
| Shoulder raised | Optional heuristic: shoulder-to-ear distance shrinks > 30% vs baseline |

Minimum visibility to score a frame: 0.5 on hip, shoulder, knee, ankle, and elbow (near side).

## REBA

### Group A
**Trunk:** upright 1 · 0–20° flex or ext 2 · 20–60° flex or >20° ext 3 · >60° flex 4 · +1 twist/side bend
**Neck:** 0–20° flex 1 · >20° flex or any ext 2 · +1 twist/side bend
**Legs:** bilateral weight bearing / walking / sitting 1 · unilateral or unstable 2 · +1 knee 30–60° · +2 knee >60° (not sitting)

**Table A** — rows: trunk 1–5, columns: legs 1–4

Neck = 1
| Trunk | L1 | L2 | L3 | L4 |
|---|---|---|---|---|
| 1 | 1 | 2 | 3 | 4 |
| 2 | 2 | 3 | 4 | 5 |
| 3 | 2 | 4 | 5 | 6 |
| 4 | 3 | 5 | 6 | 7 |
| 5 | 4 | 6 | 7 | 8 |

Neck = 2
| Trunk | L1 | L2 | L3 | L4 |
|---|---|---|---|---|
| 1 | 1 | 2 | 3 | 4 |
| 2 | 3 | 4 | 5 | 6 |
| 3 | 4 | 5 | 6 | 7 |
| 4 | 5 | 6 | 7 | 8 |
| 5 | 6 | 7 | 8 | 9 |

Neck = 3
| Trunk | L1 | L2 | L3 | L4 |
|---|---|---|---|---|
| 1 | 3 | 3 | 5 | 6 |
| 2 | 4 | 5 | 6 | 7 |
| 3 | 5 | 6 | 7 | 8 |
| 4 | 6 | 7 | 8 | 9 |
| 5 | 7 | 8 | 9 | 9 |

**Load/force:** <5 kg 0 · 5–10 kg 1 · >10 kg 2 · +1 shock or rapid force
**Score A** = Table A + load

### Group B (score the worse arm)
**Upper arm:** 20° ext to 20° flex 1 · >20° ext or 20–45° flex 2 · 45–90° 3 · >90° 4 · +1 abducted/rotated · +1 shoulder raised · −1 arm supported/leaning (min 1)
**Lower arm:** 60–100° flex 1 · <60° or >100° 2
**Wrist:** 0–15° 1 · >15° 2 · +1 deviation/twist

**Table B** — rows: upper arm 1–6, columns: wrist 1–3

Lower arm = 1
| UA | W1 | W2 | W3 |
|---|---|---|---|
| 1 | 1 | 2 | 2 |
| 2 | 1 | 2 | 3 |
| 3 | 3 | 4 | 5 |
| 4 | 4 | 5 | 5 |
| 5 | 6 | 7 | 8 |
| 6 | 7 | 8 | 8 |

Lower arm = 2
| UA | W1 | W2 | W3 |
|---|---|---|---|
| 1 | 1 | 2 | 3 |
| 2 | 2 | 3 | 4 |
| 3 | 4 | 5 | 5 |
| 4 | 5 | 6 | 7 |
| 5 | 7 | 8 | 8 |
| 6 | 8 | 9 | 9 |

**Coupling:** good 0 · fair 1 · poor 2 · unacceptable 3
**Score B** = Table B + coupling

### Table C — rows: Score A 1–12, columns: Score B 1–12
| A\B | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 1 | 1 | 2 | 3 | 3 | 4 | 5 | 6 | 7 | 7 | 7 |
| 2 | 1 | 2 | 2 | 3 | 4 | 4 | 5 | 6 | 6 | 7 | 7 | 8 |
| 3 | 2 | 3 | 3 | 3 | 4 | 5 | 6 | 7 | 7 | 8 | 8 | 8 |
| 4 | 3 | 4 | 4 | 4 | 5 | 6 | 7 | 8 | 8 | 9 | 9 | 9 |
| 5 | 4 | 4 | 4 | 5 | 6 | 7 | 8 | 8 | 9 | 9 | 9 | 9 |
| 6 | 6 | 6 | 6 | 7 | 8 | 8 | 9 | 9 | 10 | 10 | 10 | 10 |
| 7 | 7 | 7 | 7 | 8 | 9 | 9 | 9 | 10 | 10 | 11 | 11 | 11 |
| 8 | 8 | 8 | 8 | 9 | 10 | 10 | 10 | 10 | 10 | 11 | 11 | 11 |
| 9 | 9 | 9 | 9 | 10 | 10 | 10 | 11 | 11 | 11 | 12 | 12 | 12 |
| 10 | 10 | 10 | 10 | 11 | 11 | 11 | 11 | 12 | 12 | 12 | 12 | 12 |
| 11 | 11 | 11 | 11 | 11 | 12 | 12 | 12 | 12 | 12 | 12 | 12 | 12 |
| 12 | 12 | 12 | 12 | 12 | 12 | 12 | 12 | 12 | 12 | 12 | 12 | 12 |

**Activity (+1 each, from setup):** a body part held static >1 min · small-range repeats >4×/min · rapid large posture changes or unstable base
**REBA** = Table C + activity (cap 15)

**Risk bands:** 1 negligible · 2–3 low · 4–7 medium · 8–10 high · 11–15 very high

Implementation: use near-boundary hysteresis (±3°) so scores don't flicker at thresholds.

## OWAS
Four-digit code: back, arms, legs, load.
- **Back:** 1 straight · 2 bent · 3 twisted · 4 bent and twisted (bent = trunk flex > 20°)
- **Arms:** 1 both below shoulder · 2 one at/above shoulder · 3 both at/above
- **Legs:** 1 sitting · 2 standing, both legs straight · 3 standing on one straight leg · 4 standing, both knees bent · 5 one knee bent · 6 kneeling · 7 walking
- **Load:** 1 <10 kg · 2 10–20 kg · 3 >20 kg

**Action category** (1 normal · 2 correct soon · 3 correct ASAP · 4 correct immediately)
comes from the standard 4×3×7×3 OWAS lookup table. **TODO: transcribe from a cited
source into `owas_tables.dart`, add the source in a comment, and test every back-code block.**
Until then, OWAS shows the posture code only, with category "n/a".

## Golden posture tests (must pass)
Inputs: load 0, coupling good, no activity flags, no manual toggles.

| # | Posture | Key angles | Expected REBA |
|---|---|---|---|
| G1 | Neutral standing, arms by sides | trunk 0, neck 5, knees 0, upper arm 0, elbow 5 | 1–3 |
| G2 | Light forward reach at bench | trunk 15, neck 15, upper arm 50, elbow 80 | 3–5 |
| G3 | Stoop to floor, legs straight | trunk 75, neck 25, knees 10, upper arm 80, elbow 10 | 7–10 |
| G4 | Deep squat lift | trunk 40, knees 100, upper arm 30, elbow 20 | 6–9 |
| G5 | Overhead reach | trunk 0, neck 25 ext, upper arm 120, elbow 30 | 5–8 |

Also test exact sub-scores for G1 by hand: trunk 1, neck 1, legs 1 → A 1;
upper arm 1, lower arm 2, wrist 1 → B 1; C(1,1) = 1 → REBA 1.

import 'package:ergo_core/ergo_core.dart';
import 'package:test/test.dart';

void main() {
  test('defaults are the neutral case', () {
    const i = SessionInputs();
    expect(i.loadKg, 0);
    expect(i.coupling, Coupling.good);
    expect(i.activityScore, 0);
  });

  test('copyWith changes only the given fields', () {
    const i = SessionInputs(loadKg: 12, sitting: true);
    final j = i.copyWith(coupling: Coupling.poor, staticPosture: true);
    expect(j.loadKg, 12);
    expect(j.sitting, isTrue);
    expect(j.coupling, Coupling.poor);
    expect(j.activityScore, 1);
    expect(i.coupling, Coupling.good);
  });
}

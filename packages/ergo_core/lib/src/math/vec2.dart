import 'dart:math' as math;

/// Immutable 2D vector in image coordinates (x right, y down).
class Vec2 {
  const Vec2(this.x, this.y);

  final double x;
  final double y;

  Vec2 operator +(Vec2 o) => Vec2(x + o.x, y + o.y);
  Vec2 operator -(Vec2 o) => Vec2(x - o.x, y - o.y);
  Vec2 operator -() => Vec2(-x, -y);
  Vec2 operator *(double s) => Vec2(x * s, y * s);

  double dot(Vec2 o) => x * o.x + y * o.y;

  /// z component of the 3D cross product; its sign gives rotation direction.
  double cross(Vec2 o) => x * o.y - y * o.x;

  double get length => math.sqrt(x * x + y * y);

  Vec2 get normalized {
    final l = length;
    return l == 0 ? this : Vec2(x / l, y / l);
  }

  static Vec2 midpoint(Vec2 a, Vec2 b) =>
      Vec2((a.x + b.x) / 2, (a.y + b.y) / 2);

  @override
  bool operator ==(Object other) =>
      other is Vec2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Vec2($x, $y)';
}

const double _degPerRad = 180 / math.pi;

/// Signed rotation in degrees (−180, 180] that turns [from] onto [to].
/// The sign follows the coordinate system's handedness; callers fix the
/// meaning of "positive" with a reference rotation sense.
double rotationDeg(Vec2 from, Vec2 to) =>
    math.atan2(from.cross(to), from.dot(to)) * _degPerRad;

/// Unsigned angle in degrees [0, 180] at [vertex] between [a] and [b].
double interiorAngleDeg(Vec2 a, Vec2 vertex, Vec2 b) =>
    rotationDeg(a - vertex, b - vertex).abs();

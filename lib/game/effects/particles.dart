import 'dart:math' as math;

/// A point in the world: tile x, tile y and height in blocks.
typedef Vec3 = (double x, double y, double z);

/// A small colored quad flying through the world.
class Particle {
  /// Creates a particle that lives for [life] seconds.
  new({
    required this.x,
    required this.y,
    required this.z,
    required this.vx,
    required this.vy,
    required this.vz,
    required this.life,
    required this.color,
  });

  /// Position (tiles, tiles, blocks).
  double x;

  /// Position.
  double y;

  /// Position (height).
  double z;

  /// Speed in tiles (or blocks) per second.
  final double vx;

  /// Speed.
  final double vy;

  /// Speed (upward is positive).
  final double vz;

  /// Seconds left.
  double life;

  /// ARGB color.
  final int color;
}

/// Dust and smoke. Seeded, so the same seed always gives the same particles.
class ParticleSystem {
  /// Creates a system with a fixed [seed].
  new(int seed) : _random = math.Random(seed);

  final math.Random _random;
  final List<Particle> _alive = [];

  /// The particles still flying.
  List<Particle> get alive => List.unmodifiable(_alive);

  /// Throws [count] particles up from [origin], colored from [colors]. They
  /// rise 1.5 to 3 blocks per second, spread a little, and live [life]
  /// seconds; [speed] scales how fast they move.
  void burst(
    Vec3 origin,
    List<int> colors,
    int count, {
    double life = 1,
    double speed = 1,
  }) {
    for (var i = 0; i < count; i++) {
      _alive.add(
        Particle(
          x: origin.$1,
          y: origin.$2,
          z: origin.$3,
          vx: (_random.nextDouble() - 0.5) * 2 * speed,
          vy: (_random.nextDouble() - 0.5) * 2 * speed,
          vz: (1.5 + _random.nextDouble() * 1.5) * speed,
          life: life,
          color: colors[_random.nextInt(colors.length)],
        ),
      );
    }
  }

  /// Removes every particle.
  void clear() => _alive.clear();

  /// Moves everything by [dt] and drops the particles whose life ran out.
  void step(Duration dt) {
    final s = dt.inMicroseconds / 1e6;
    for (final p in _alive) {
      p
        ..x += p.vx * s
        ..y += p.vy * s
        ..z += p.vz * s
        ..life -= s;
    }
    _alive.removeWhere((p) => p.life <= 1e-9);
  }
}

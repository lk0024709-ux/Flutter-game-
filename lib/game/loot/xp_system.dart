abstract final class XpSystem {
  static int xpForNextLevel(int level) => (100 * _pow(level, 1.5)).round();
  static int cumulativeXpForLevel(int level) => (100 * _pow(level, 1.5)).round();
  static int levelForXp(int xp) {
    var level = 1;
    var remaining = xp;
    while (level < 100) {
      final cost = xpForNextLevel(level);
      if (remaining < cost) break;
      remaining -= cost;
      level++;
    }
    return level;
  }
  static int xpRemainder(int xp) {
    var remaining = xp;
    var level = 1;
    while (level < 100 && remaining >= xpForNextLevel(level)) {
      remaining -= xpForNextLevel(level);
      level++;
    }
    return remaining;
  }
  static double _pow(int value, double power) {
    if (power == 1.5) return value * _sqrt(value);
    return value.toDouble();
  }
  static double _sqrt(double value) {
    var x = value <= 1 ? 1.0 : value / 2;
    for (var i = 0; i < 20; i++) { x = (x + value / x) / 2; }
    return x;
  }
}

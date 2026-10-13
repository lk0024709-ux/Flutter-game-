import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Campaign level grade. Ordering matters: `ss` is the best, `none` the worst,
/// so a lower [index] is a better grade throughout the app.
enum LevelGrade {
  ss('SS', 800, 'Flawless'),
  s('S', 450, 'Master'),
  a('A', 250, 'Excellent'),
  b('B', 150, 'Good'),
  c('C', 80, 'Fair'),
  d('D', 40, 'Cleared'),
  none('—', 0, 'Not Cleared');

  const LevelGrade(this.label, this.baseReward, this.title);

  /// Letter shown on badges ("SS", "A", "—").
  final String label;

  /// Base coin reward attached to the grade.
  final int baseReward;

  /// Flavour word shown under the grade in the result modal.
  final String title;

  bool get isCleared => this != LevelGrade.none;

  /// Coin multiplier applied to the level reward formula.
  /// D = 1.0, C = 1.2, B = 1.5, A = 2.0, S = 3.0, SS = 5.0
  double get coinMultiplier {
    switch (this) {
      case LevelGrade.ss:
        return 5.0;
      case LevelGrade.s:
        return 3.0;
      case LevelGrade.a:
        return 2.0;
      case LevelGrade.b:
        return 1.5;
      case LevelGrade.c:
        return 1.2;
      case LevelGrade.d:
        return 1.0;
      case LevelGrade.none:
        return 0.0;
    }
  }

  /// Muted grade tint used by badges, pills and the result modal.
  Color get color {
    switch (this) {
      case LevelGrade.ss:
        return AppColors.gradeSS;
      case LevelGrade.s:
        return AppColors.gradeS;
      case LevelGrade.a:
        return AppColors.gradeA;
      case LevelGrade.b:
        return AppColors.gradeB;
      case LevelGrade.c:
        return AppColors.gradeC;
      case LevelGrade.d:
        return AppColors.gradeD;
      case LevelGrade.none:
        return AppColors.gradeNone;
    }
  }

  /// Emoji shown next to the grade.
  String get emoji {
    switch (this) {
      case LevelGrade.ss:
        return '🏆';
      case LevelGrade.s:
        return '💎';
      case LevelGrade.a:
        return '⭐';
      case LevelGrade.b:
        return '🔹';
      case LevelGrade.c:
        return '🔸';
      case LevelGrade.d:
        return '✅';
      case LevelGrade.none:
        return '⬜';
    }
  }

  /// True when this grade is better than [other].
  bool betterThan(LevelGrade other) => index < other.index;

  /// Returns the worst grade of a set of sub-scores (the spec calls this the
  /// "final grade = LOWEST of all sub-grades" rule).
  static LevelGrade lowest(Iterable<LevelGrade> grades) {
    LevelGrade worst = LevelGrade.ss;
    bool any = false;
    for (final LevelGrade grade in grades) {
      if (!any || grade.index > worst.index) {
        worst = grade;
        any = true;
      }
    }
    return any ? worst : LevelGrade.none;
  }

  /// The better of two grades (used when persisting best grades).
  static LevelGrade best(LevelGrade a, LevelGrade b) => a.index <= b.index ? a : b;

  static LevelGrade byName(String? name) {
    for (final LevelGrade grade in LevelGrade.values) {
      if (grade.name == name) {
        return grade;
      }
    }
    return LevelGrade.none;
  }
}

/// Sub-score breakdown of a single battle.
class GradeBreakdown {
  const GradeBreakdown({
    required this.timeGrade,
    required this.hpGrade,
    required this.damageGrade,
  });

  final LevelGrade timeGrade;
  final LevelGrade hpGrade;
  final LevelGrade damageGrade;

  /// The final grade is the lowest of the three sub-grades.
  LevelGrade get finalGrade {
    return LevelGrade.lowest(<LevelGrade>[timeGrade, hpGrade, damageGrade]);
  }

  List<LevelGrade> get all => <LevelGrade>[timeGrade, hpGrade, damageGrade];

  static const GradeBreakdown empty = GradeBreakdown(
    timeGrade: LevelGrade.none,
    hpGrade: LevelGrade.none,
    damageGrade: LevelGrade.none,
  );
}

/// Pure grade maths - unit tested in `test/grade_test.dart`.
class GradeCalculator {
  const GradeCalculator._();

  /// Time thresholds in seconds.
  static LevelGrade gradeTime(double seconds) {
    if (seconds < 50) {
      return LevelGrade.ss;
    }
    if (seconds < 70) {
      return LevelGrade.s;
    }
    if (seconds < 90) {
      return LevelGrade.a;
    }
    if (seconds < 120) {
      return LevelGrade.b;
    }
    if (seconds < 150) {
      return LevelGrade.c;
    }
    return LevelGrade.d;
  }

  /// Remaining health percentage (0..100).
  static LevelGrade gradeHp(double hpPercent) {
    if (hpPercent >= 99.999) {
      return LevelGrade.ss;
    }
    if (hpPercent >= 80) {
      return LevelGrade.s;
    }
    if (hpPercent >= 60) {
      return LevelGrade.a;
    }
    if (hpPercent >= 40) {
      return LevelGrade.b;
    }
    if (hpPercent >= 20) {
      return LevelGrade.c;
    }
    return LevelGrade.d;
  }

  /// Total damage taken during the battle.
  static LevelGrade gradeDamage(double damageTaken) {
    if (damageTaken <= 0) {
      return LevelGrade.ss;
    }
    if (damageTaken < 15) {
      return LevelGrade.s;
    }
    if (damageTaken < 30) {
      return LevelGrade.a;
    }
    if (damageTaken < 60) {
      return LevelGrade.b;
    }
    if (damageTaken < 100) {
      return LevelGrade.c;
    }
    return LevelGrade.d;
  }

  /// Evaluates all three sub-scores at once.
  static GradeBreakdown evaluate({
    required double timeSeconds,
    required double hpPercent,
    required double damageTaken,
  }) {
    return GradeBreakdown(
      timeGrade: gradeTime(timeSeconds),
      hpGrade: gradeHp(hpPercent),
      damageGrade: gradeDamage(damageTaken),
    );
  }
}

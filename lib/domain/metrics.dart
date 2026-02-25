/// 1レップの計測データ
class RepMetrics {
  final int repNumber;
  final double elw; // Effective Load Work [J]
  final double lqs; // Load Quality Score [pts]
  final double dr; // Deceleration Ratio [0-1]
  final double tut; // Time Under Tension [s]
  final double ihd; // Isometric Hold Duration [s]
  final double mpv; // Mean Propulsive Velocity [m/s]
  final double peakVelocity; // [m/s]

  const RepMetrics({
    required this.repNumber,
    required this.elw,
    required this.lqs,
    required this.dr,
    required this.tut,
    required this.ihd,
    required this.mpv,
    required this.peakVelocity,
  });
}

/// セット全体の集計
class SetResult {
  final List<RepMetrics> reps;
  final double totalSetScore;
  final double totalTut;
  final double averageDr;
  final double velocityLoss; // 第1レップ→最終レップのMPV低下率 [%]
  final double massKg;
  final DateTime timestamp;

  SetResult({
    required this.reps,
    required this.massKg,
    required this.timestamp,
  })  : totalSetScore = reps.fold(0.0, (s, r) => s + r.lqs),
        totalTut = reps.fold(0.0, (s, r) => s + r.tut),
        averageDr = reps.isEmpty
            ? 0.0
            : reps.fold(0.0, (s, r) => s + r.dr) / reps.length,
        velocityLoss = (reps.length >= 2)
            ? (reps.first.mpv - reps.last.mpv) / reps.first.mpv * 100
            : 0.0;

  int get repCount => reps.length;
}

/// リアルタイムのレップ計測状態
class LiveRepState {
  final double currentVelocity; // [m/s]
  final double currentElw; // 今レップの累積ELW [J]
  final double loadContinuityRate; // 1 - DR のリアルタイム推定 [0-1]
  final bool isHolding; // 等尺性保持中か
  final double holdDuration; // 保持中のタイマー [s]
  final int repCount;
  final double setScore; // セット累積スコア

  const LiveRepState({
    this.currentVelocity = 0.0,
    this.currentElw = 0.0,
    this.loadContinuityRate = 1.0,
    this.isHolding = false,
    this.holdDuration = 0.0,
    this.repCount = 0,
    this.setScore = 0.0,
  });

  LiveRepState copyWith({
    double? currentVelocity,
    double? currentElw,
    double? loadContinuityRate,
    bool? isHolding,
    double? holdDuration,
    int? repCount,
    double? setScore,
  }) {
    return LiveRepState(
      currentVelocity: currentVelocity ?? this.currentVelocity,
      currentElw: currentElw ?? this.currentElw,
      loadContinuityRate: loadContinuityRate ?? this.loadContinuityRate,
      isHolding: isHolding ?? this.isHolding,
      holdDuration: holdDuration ?? this.holdDuration,
      repCount: repCount ?? this.repCount,
      setScore: setScore ?? this.setScore,
    );
  }
}

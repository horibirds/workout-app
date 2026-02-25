import 'dart:math';
import '../domain/metrics.dart';

const double _g = 9.81; // m/s²

// Isolate間のメッセージ型
class ImuSample {
  final double ax; // 鉛直方向加速度（重力除去済み）[m/s²]
  final int timestampUs; // ハードウェアタイムスタンプ [μs]

  const ImuSample(this.ax, this.timestampUs);
}

class ImuCommand {
  final String type; // 'start', 'stop', 'reset'
  final double? massKg;

  const ImuCommand(this.type, {this.massKg});
}

/// Isolate内で動作するIMU積分・指標計算エンジン
class ImuEngine {
  final double massKg;

  // 速度積分
  double _velocity = 0.0;
  int? _prevTimestampUs;

  // レップ検出
  static const double _velocityThresholdStart = 0.05; // [m/s] コンセントリック開始
  static const double _velocityThresholdZero = 0.02; // [m/s] 静止判定
  static const double _stationaryDurationUs = 400000; // 0.4秒 静止継続で1レップ確定

  _RepAccumulator? _currentRep;
  int _stationaryStartUs = 0;
  bool _wasStationary = true;

  final List<RepMetrics> _completedReps = [];

  ImuEngine({required this.massKg});

  /// サンプル1個を処理して現在のLiveRepStateを返す
  /// レップ完了時はcompletedRepsに追加される
  LiveRepState process(ImuSample sample) {
    final dt = _computeDt(sample.timestampUs);
    if (dt == null) return _buildLiveState();

    // ZUPT: 加速度がほぼゼロかつ速度が小さければ速度をゼロリセット
    final absAx = sample.ax.abs();
    if (absAx < 0.3 && _velocity.abs() < 0.08) {
      _velocity = 0.0;
    } else {
      _velocity += sample.ax * dt;
    }

    final isStationary = _velocity.abs() < _velocityThresholdZero;

    // 静止継続時間を追跡
    if (isStationary) {
      if (_wasStationary == false) {
        _stationaryStartUs = sample.timestampUs;
      }
      final stationaryDuration = sample.timestampUs - _stationaryStartUs;

      // 0.4秒以上静止 → レップ完了判定
      if (stationaryDuration > _stationaryDurationUs && _currentRep != null) {
        _finalizeRep(sample.timestampUs);
      }
    }
    _wasStationary = isStationary;

    // コンセントリック開始検出
    if (_currentRep == null && _velocity > _velocityThresholdStart) {
      _currentRep = _RepAccumulator(
        startTimestampUs: sample.timestampUs,
        repNumber: _completedReps.length + 1,
      );
    }

    // レップ中の積算
    if (_currentRep != null) {
      _currentRep!.accumulate(
        velocity: _velocity,
        ax: sample.ax,
        massKg: massKg,
        dt: dt,
        timestampUs: sample.timestampUs,
      );
    }

    return _buildLiveState();
  }

  double? _computeDt(int timestampUs) {
    if (_prevTimestampUs == null) {
      _prevTimestampUs = timestampUs;
      return null;
    }
    final dtUs = timestampUs - _prevTimestampUs!;
    _prevTimestampUs = timestampUs;
    if (dtUs <= 0 || dtUs > 200000) return null; // 異常値スキップ
    return dtUs / 1e6; // μs → s
  }

  void _finalizeRep(int endTimestampUs) {
    final rep = _currentRep!;
    final metrics = rep.finalize(completedTimestampUs: endTimestampUs);
    _completedReps.add(metrics);
    _currentRep = null;
    _velocity = 0.0;
  }

  LiveRepState _buildLiveState() {
    final rep = _currentRep;
    final setScore = _completedReps.fold(0.0, (s, r) => s + r.lqs);

    // リアルタイムのDR（コンセントリック中のみ）
    final liveDr = rep != null && rep.concentricTimeS > 0
        ? rep.decelerationTimeS / rep.concentricTimeS
        : 0.0;
    final loadContinuity = (1.0 - liveDr).clamp(0.0, 1.0);

    // 等尺性保持（レップ中に速度がほぼゼロの区間）
    final isHolding = rep != null && _velocity.abs() < _velocityThresholdZero;

    return LiveRepState(
      currentVelocity: _velocity,
      currentElw: rep?.elw ?? 0.0,
      loadContinuityRate: loadContinuity,
      isHolding: isHolding,
      holdDuration: rep?.ihdS ?? 0.0,
      repCount: _completedReps.length,
      setScore: setScore,
    );
  }

  List<RepMetrics> get completedReps => List.unmodifiable(_completedReps);

  void reset() {
    _velocity = 0.0;
    _prevTimestampUs = null;
    _currentRep = null;
    _stationaryStartUs = 0;
    _wasStationary = true;
    _completedReps.clear();
  }
}

/// 1レップ分の積算バッファ
class _RepAccumulator {
  final int startTimestampUs;
  final int repNumber;

  double elw = 0.0; // Effective Load Work [J]
  double concentricTimeS = 0.0;
  double decelerationTimeS = 0.0;
  double ihdS = 0.0; // Isometric Hold Duration [s]
  double tutS = 0.0; // Time Under Tension [s]

  // MPV計算用（推進区間のみ）
  double _propulsiveVelocitySum = 0.0;
  double _propulsiveTimeSum = 0.0;
  double _peakVelocity = 0.0;

  // フェーズ追跡（将来のフェーズ別分岐で使用）
  // ignore: unused_field
  bool _inConcentric = true;

  static const double _velocityZero = 0.02;

  _RepAccumulator({
    required this.startTimestampUs,
    required this.repNumber,
  });

  void accumulate({
    required double velocity,
    required double ax,
    required double massKg,
    required double dt,
    required int timestampUs,
  }) {
    tutS += dt;

    // 実効負荷による仕事量（絶対値積算）
    final fEffective = massKg * (_g + ax);
    elw += fEffective * velocity.abs() * dt;

    // コンセントリック（上昇）フェーズ
    if (velocity > 0) {
      _inConcentric = true;
      concentricTimeS += dt;

      // 加速度が負 = 制動（Deceleration）フェーズ
      if (ax < 0) {
        decelerationTimeS += dt;
      }

      // MPV: 推進区間（加速度 > 0）のみ
      if (ax > 0) {
        _propulsiveVelocitySum += velocity * dt;
        _propulsiveTimeSum += dt;
      }

      _peakVelocity = max(_peakVelocity, velocity);
    }

    // 等尺性保持（レップ中に静止）
    if (velocity.abs() < _velocityZero && tutS > 0.1) {
      ihdS += dt;
    }
  }

  RepMetrics finalize({required int completedTimestampUs}) {
    final dr = concentricTimeS > 0
        ? (decelerationTimeS / concentricTimeS).clamp(0.0, 1.0)
        : 0.0;

    final mpv = _propulsiveTimeSum > 0
        ? _propulsiveVelocitySum / _propulsiveTimeSum
        : 0.0;

    final lqs = _calculateLqs(elw: elw, dr: dr, ihd: ihdS, tut: tutS);

    return RepMetrics(
      repNumber: repNumber,
      elw: elw,
      lqs: lqs,
      dr: dr,
      tut: tutS,
      ihd: ihdS,
      mpv: mpv,
      peakVelocity: _peakVelocity,
    );
  }

  static double _calculateLqs({
    required double elw,
    required double dr,
    required double ihd,
    required double tut,
  }) {
    // IHDボーナス: 保持時間が長いほど加点（上限50%）
    final ihdBonus = min(ihd / 2.0, 0.5);

    // Load Quality = (1 - DR) × (1 + IHD bonus)
    final quality = (1.0 - dr) * (1.0 + ihdBonus);

    return elw * quality;
  }
}

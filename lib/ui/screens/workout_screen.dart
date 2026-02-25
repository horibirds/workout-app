import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/metrics.dart';
import '../../imu/imu_service.dart';
import '../widgets/load_continuity_gauge.dart';
import 'result_screen.dart';

class WorkoutScreen extends ConsumerWidget {
  final double massKg;

  const WorkoutScreen({super.key, required this.massKg});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveAsync = ref.watch(liveStateProvider);
    final reps = ref.watch(repHistoryProvider);

    final live = liveAsync.maybeWhen(
      data: (s) => s,
      orElse: () => const LiveRepState(),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${massKg.toStringAsFixed(1)} kg',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  _RecordingIndicator(),
                ],
              ),

              const SizedBox(height: 32),

              // レップカウンター（大きく）
              Center(
                child: Column(
                  children: [
                    Text(
                      '${live.repCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 96,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                    const Text('reps',
                        style: TextStyle(color: Colors.grey, fontSize: 20)),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Set Score
              Center(
                child: Column(
                  children: [
                    Text(
                      live.setScore.toStringAsFixed(0),
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('Set Score',
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 負荷継続率ゲージ
              LoadContinuityGauge(rate: live.loadContinuityRate),

              const SizedBox(height: 24),

              // 等尺性保持表示
              if (live.isHolding)
                _HoldIndicator(duration: live.holdDuration)
              else
                const SizedBox(height: 48),

              const SizedBox(height: 16),

              // 速度表示
              _VelocityDisplay(velocity: live.currentVelocity),

              const Spacer(),

              // レップ履歴（直近5レップ）
              if (reps.isNotEmpty) _RepHistory(reps: reps),

              const SizedBox(height: 24),

              // 終了ボタン
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[850],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => _finishSet(context, ref, reps),
                  child: const Text(
                    'セット終了',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finishSet(
      BuildContext context, WidgetRef ref, List<RepMetrics> reps) async {
    final service = ref.read(imuServiceProvider);
    await service.stop();

    if (!context.mounted) return;

    if (reps.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final result = SetResult(
      reps: reps,
      massKg: massKg,
      timestamp: DateTime.now(),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
    );
  }
}

class _RecordingIndicator extends StatefulWidget {
  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.4 + 0.6 * _ctrl.value),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text('計測中', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}

class _HoldIndicator extends StatelessWidget {
  final double duration;
  const _HoldIndicator({required this.duration});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.pause_circle, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Text(
            'HOLD  ${duration.toStringAsFixed(1)}s',
            style: const TextStyle(
              color: Colors.orange,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          const Text('+ボーナス',
              style: TextStyle(color: Colors.orange, fontSize: 12)),
        ],
      ),
    );
  }
}

class _VelocityDisplay extends StatelessWidget {
  final double velocity;
  const _VelocityDisplay({required this.velocity});

  @override
  Widget build(BuildContext context) {
    final absV = velocity.abs();
    final direction = velocity > 0.03
        ? '▲ 上昇'
        : velocity < -0.03
            ? '▼ 下降'
            : '─ 静止';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${absV.toStringAsFixed(2)} m/s',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 22,
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          direction,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
      ],
    );
  }
}

class _RepHistory extends StatelessWidget {
  final List<RepMetrics> reps;
  const _RepHistory({required this.reps});

  @override
  Widget build(BuildContext context) {
    final recent = reps.length > 5 ? reps.sublist(reps.length - 5) : reps;
    final maxLqs = recent.map((r) => r.lqs).fold(0.0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('直近レップ',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.start,
          children: recent.map((rep) {
            final barH = maxLqs > 0 ? (rep.lqs / maxLqs * 48).clamp(4.0, 48.0) : 4.0;
            final drColor = rep.dr < 0.25
                ? Colors.green
                : rep.dr < 0.4
                    ? Colors.amber
                    : Colors.red;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'R${rep.repNumber}',
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 28,
                    height: barH,
                    decoration: BoxDecoration(
                      color: drColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

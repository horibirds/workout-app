import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../imu/imu_service.dart';
import 'workout_screen.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  double _barKg = 20.0;
  double _platesKg = 0.0;

  double get _totalKg => _barKg + _platesKg;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'セット設定',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // 合計重量表示
              Center(
                child: Column(
                  children: [
                    Text(
                      '${_totalKg.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      '合計重量',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // バー重量
              _WeightSlider(
                label: 'バー重量',
                value: _barKg,
                min: 10,
                max: 30,
                divisions: 4,
                onChanged: (v) => setState(() => _barKg = v),
              ),

              const SizedBox(height: 32),

              // プレート重量
              _WeightSlider(
                label: 'プレート重量（両側合計）',
                value: _platesKg,
                min: 0,
                max: 200,
                divisions: 40,
                onChanged: (v) => setState(() => _platesKg = v),
              ),

              const Spacer(),

              // 開始ボタン
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _startWorkout(context),
                  child: const Text(
                    'トレーニング開始',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startWorkout(BuildContext context) async {
    final service = ref.read(imuServiceProvider);
    ref.read(repHistoryProvider.notifier).clear();
    await service.start(massKg: _totalKg);

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutScreen(massKg: _totalKg),
      ),
    );
  }
}

class _WeightSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _WeightSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
            Text(
              '${value.toStringAsFixed(1)} kg',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.green,
            thumbColor: Colors.green,
            inactiveTrackColor: Colors.grey[800],
            overlayColor: Colors.green.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

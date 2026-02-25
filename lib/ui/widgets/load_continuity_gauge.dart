import 'package:flutter/material.dart';

/// 負荷継続率ゲージ（1 - DR）
/// 緑 = 高い（負荷が続いている）、赤 = 低い（負荷が抜けている）
class LoadContinuityGauge extends StatelessWidget {
  final double rate; // [0.0 - 1.0]

  const LoadContinuityGauge({super.key, required this.rate});

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(Colors.red, Colors.green, rate)!;
    final percent = (rate * 100).toInt();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('負荷継続率',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            Text(
              '$percent%',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: rate,
            minHeight: 12,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

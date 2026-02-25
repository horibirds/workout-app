import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../domain/metrics.dart';

class ResultScreen extends StatelessWidget {
  final SetResult result;

  const ResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final quality = _qualityLabel(result.averageDr);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー
              const Text(
                'セット完了',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),

              // レップ数（大きく、でも主役ではない）
              Text(
                '${result.repCount} reps',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w300,
                ),
              ),

              const SizedBox(height: 24),

              // Set Score（主役）
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      result.totalSetScore.toStringAsFixed(0),
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                    const Text(
                      'Set Score',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      quality.message,
                      style: TextStyle(
                        color: quality.color,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // サマリーカード
              _SummaryRow(
                items: [
                  _SummaryItem(
                    label: 'TUT',
                    value: '${result.totalTut.toStringAsFixed(1)}s',
                    sub: '総緊張時間',
                  ),
                  _SummaryItem(
                    label: '平均DR',
                    value: '${(result.averageDr * 100).toStringAsFixed(0)}%',
                    sub: quality.drLabel,
                    valueColor: _drColor(result.averageDr),
                  ),
                  _SummaryItem(
                    label: '速度低下',
                    value: '${result.velocityLoss.toStringAsFixed(0)}%',
                    sub: '疲労度',
                    valueColor: result.velocityLoss < 30
                        ? Colors.green
                        : Colors.orange,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // レップごとのLQSグラフ
              const Text(
                'レップ別スコア',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: _RepBarChart(reps: result.reps),
              ),

              const SizedBox(height: 24),

              // レップ詳細リスト
              const Text(
                'レップ詳細',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 8),
              ...result.reps.map((rep) => _RepDetailRow(rep: rep)),

              const SizedBox(height: 32),

              // 終了ボタン
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    // セットアップ画面まで戻る
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  child: const Text(
                    '次のセットへ',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ヘルパー
// ---------------------------------------------------------------------------

Color _drColor(double dr) {
  if (dr < 0.2) return Colors.green;
  if (dr < 0.35) return Colors.amber;
  return Colors.red;
}

class _QualityLabel {
  final String message;
  final String drLabel;
  final Color color;
  const _QualityLabel(this.message, this.drLabel, this.color);
}

_QualityLabel _qualityLabel(double dr) {
  if (dr < 0.2) {
    return const _QualityLabel('高品質なセットでした ✓', '良好', Colors.green);
  } else if (dr < 0.35) {
    return const _QualityLabel('まずまずのセット', '普通', Colors.amber);
  } else {
    return const _QualityLabel('もう少しゆっくり試してみよう', '制動が多め', Colors.orange);
  }
}

// ---------------------------------------------------------------------------
// ウィジェット
// ---------------------------------------------------------------------------

class _SummaryRow extends StatelessWidget {
  final List<_SummaryItem> items;
  const _SummaryRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items
          .map((item) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        item.value,
                        style: TextStyle(
                          color: item.valueColor ?? Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(item.label,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11)),
                      Text(item.sub,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 10)),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _SummaryItem {
  final String label;
  final String value;
  final String sub;
  final Color? valueColor;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.sub,
    this.valueColor,
  });
}

class _RepBarChart extends StatelessWidget {
  final List<RepMetrics> reps;
  const _RepBarChart({required this.reps});

  @override
  Widget build(BuildContext context) {
    final maxLqs =
        reps.map((r) => r.lqs).fold(0.0, (a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,
        maxY: maxLqs * 1.2,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Text(
                'R${v.toInt() + 1}',
                style:
                    const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ),
          ),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: reps.asMap().entries.map((e) {
          final rep = e.value;
          final color = _drColor(rep.dr);
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: rep.lqs,
                color: color,
                width: 20,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _RepDetailRow extends StatelessWidget {
  final RepMetrics rep;
  const _RepDetailRow({required this.rep});

  @override
  Widget build(BuildContext context) {
    final drPct = (rep.dr * 100).toStringAsFixed(0);
    final drColor = _drColor(rep.dr);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              'R${rep.repNumber}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              'Score ${rep.lqs.toStringAsFixed(0)}',
              style: const TextStyle(color: Colors.amber),
            ),
          ),
          Text(
            'DR $drPct%',
            style: TextStyle(color: drColor, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Text(
            'TUT ${rep.tut.toStringAsFixed(1)}s',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          if (rep.ihd > 0.2) ...[
            const SizedBox(width: 8),
            Text(
              'HOLD ${rep.ihd.toStringAsFixed(1)}s',
              style: const TextStyle(color: Colors.orange, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

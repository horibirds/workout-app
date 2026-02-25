# 開発ドキュメント

## プロジェクト概要

「回数ではなく負荷の質で評価する」筋トレ計測アプリ。
iPhoneをバーベルシャフトにマウントし、IMUで動作を計測する。

**コアコンセプト**: ゆっくり丁寧な8回 > 速い10回 になるスコア設計。

詳細は `SPEC.md` 参照。

---

## 技術スタック

| 項目 | 採用技術 |
|------|---------|
| フレームワーク | Flutter（iOS優先、将来Android対応） |
| IMU取得 | sensors_plus v6.1.1（ハードウェアタイムスタンプ対応） |
| 状態管理 | Riverpod v2.6.1 |
| グラフ | fl_chart v0.70.2 |
| IMU処理 | Dart Isolate（メインスレッドと分離） |

---

## アーキテクチャ

```
lib/
├── domain/
│   └── metrics.dart          # データモデル
│       ├── RepMetrics        # 1レップの計測結果
│       ├── SetResult         # セット全体の集計
│       └── LiveRepState      # リアルタイム状態
├── imu/
│   ├── imu_processor.dart    # ImuEngine（Isolate内で動作）
│   │   ├── 速度積分（ZUPT補正付き）
│   │   ├── レップ検出（速度ゼロクロス）
│   │   ├── 等尺性保持検出（IHD）
│   │   └── ELW / DR / LQS / Set Score 計算
│   └── imu_service.dart      # ImuService（メインIsolate）
│       ├── sensors_plus 100Hz購読
│       ├── Isolate管理
│       └── Riverpod Providers
└── ui/
    ├── screens/
    │   ├── setup_screen.dart  # バー重量・プレート重量入力
    │   ├── workout_screen.dart # リアルタイム計測
    │   └── result_screen.dart # セット完了・スコア表示
    └── widgets/
        └── load_continuity_gauge.dart
```

---

## 指標定義

### ELW（Effective Load Work）— 実効負荷仕事量 [J]
```
ELW = ∫ m × (g + a(t)) × |v(t)| dt
```
往復で打ち消されない絶対値積算。ゆっくり動かすほど大きくなる。

### DR（Deceleration Ratio）— 負荷が抜けた割合 [0-1]
```
DR = 制動区間の時間 / コンセントリック全体の時間
```
低いほど良い（負荷をかけ続けている）。

### IHD（Isometric Hold Duration）— 等尺性保持時間 [s]
```
IHD = |v| < 0.02 m/s が継続した時間（レップ中）
```
途中で止めた時間。スコアにボーナス加算される。

### LQS（Load Quality Score）— 1レップのスコア [pts]
```
LQS = ELW × (1 - DR) × (1 + min(IHD/2, 0.5))
```

### Set Score — セット全体のスコア [pts]
```
Set Score = Σ LQS_i
```
**これが主役の数値。回数ではなくこれで評価する。**

---

## IMU実装の重要ポイント

### ハードウェアタイムスタンプ必須
```dart
// ✓ 正しい: ハードウェアタイムスタンプでΔtを計算
final timestampUs = event.timestamp.microsecondsSinceEpoch;
```
sensors_plus v6.0.0以降で利用可能。ジッター補正に必須。

### Isolate構成
```
[メインIsolate]
  sensors_plus 100Hz受信（EventChannelのためメインIsolate必須）
     ↓ SendPortでImuSampleを転送
[バックグラウンドIsolate]
  積分・フィルタ・スコア計算（重い処理）
     ↓ LiveRepState / RepMetricsを返す
[メインIsolate]
  UIを更新
```

### ZUPT（Zero Velocity Update）
静止状態（|a| < 0.3 かつ |v| < 0.08）を検出したら速度をゼロリセット。
積分ドリフトを各レップ間でリセットする。

### iOSの軸方向
現在は `event.y`（縦持ち時の上方向）を鉛直として使用。
バーへのマウント方向によって変わるため、Phase 2でキャリブレーション機能を追加予定。

---

## 開発フェーズ

| Phase | 内容 | 状態 |
|-------|------|------|
| **1** | MVP: IMU計測・スコア計算・基本UI | **完了** |
| **2** | 精度向上: カルマンフィルタ・軸キャリブレーション | 未着手 |
| **3** | レポート・データ永続化 | 未着手 |
| **4** | 種目自動認識 | 未着手 |
| **5** | センサー拡張（ロードセル・M5StickC） | 未着手 |

---

## 実行方法

```bash
# 依存関係インストール
flutter pub get

# iOSシミュレータで実行
flutter run

# 実機で実行（IMU計測には実機必須）
flutter run -d <device-id>

# デバイス一覧
flutter devices
```

## リポジトリ

- GitHub: https://github.com/horibirds/workout-app
- メインブランチ: main

## 注意事項

- **IMU計測は実機必須**（シミュレータではIMUデータが取れない）
- バーへのiPhone固定には市販のバーベルクランプ型スマホホルダーを使用
- 現在は軸方向が固定（`event.y`）。Phase 2でキャリブレーション追加予定

# 筋トレ計測アプリ 仕様書

## 1. プロジェクト概要

スマートフォン（iPhone）のIMUセンサーを使って筋トレの「質」を定量化するアプリ。
「30回を速くやる」より「10回を丁寧にやる」方が高スコアになる指標設計を目指す。

---

## 2. デバイス構成

### メインデバイス: iPhone
- **設置方法**: バーベルシャフト（またはスクワットバー）にマウント
- **使用センサー**:
  - **加速度計（Accelerometer）**: 加速度・移動量の計測
  - **ジャイロスコープ（Gyroscope）**: バーの傾き・回転検出
  - **カメラ**: トレーニング種目の自動認識（オプション）

### 将来拡張（Phase 5）
- **M5StickC**: BLE連携でより精度の高いIMUデータ取得
- **FSRセンサー / ロードセル**: 等尺性収縮フェーズの荷重を直接計測（後述）

### iPhoneのみで対応できる理由と限界
- iPhone 12以降のCore Motionは精度の高い6軸IMU（加速度+ジャイロ）を内蔵
- バーの上下運動（鉛直方向）の加速度積分で変位・速度推定が可能（ICC: 0.91〜0.96）
- **限界**: 等尺性収縮（バーが静止）中はIMUで力を計測できない → 保持時間で代替

---

## 3. 筋トレの負荷指標と定義

### 3.1 力-速度関係（Hill方程式）の理解

筋肉の収縮速度が上がるほど発揮できる力は急激に低下する（双曲線関係）：

```
(F + a)(v + b) = b(F₀ + a)
```

- **F₀**: 最大等尺性力（速度=0のときの最大力）
- **Vmax**: 無負荷時の最大短縮速度
- 最大パワーは約 F₀ × 0.3 の負荷・速度で発生

**アプリへの示唆**:
「一瞬で高加速度で上げる」と収縮速度が上がり力が下がるだけでなく、
コンセントリック後半のデセラレーションフェーズで実効負荷がさらに下がる。
→ ペナルティは「最大速度」ではなく**「最大加速度」**が本質的に正しい。

### 3.2 実効負荷（Effective Force）

バーへの実際の負荷は加速度によって変化する：

```
F_effective = m × (g + a_vertical)
```

| フェーズ | 加速度 a | 実効負荷 | 筋への負荷 |
|---------|---------|---------|----------|
| 加速フェーズ（上げ始め） | a > 0 | m×(g+a) | 増大 |
| 等速フェーズ | a = 0 | m×g | 定格通り |
| 減速フェーズ（上げ終わり） | a < 0 | m×(g+a) | **低下（負荷が抜ける）** |
| 等尺性（静止保持） | a ≈ 0 | m×g | 定格通り（ただし力は計測不可） |

**「負荷が抜ける」現象の定量化**:
軽い重量ほどデセラレーションフェーズが長くなる（軽量: 52%、重量: 24%）。
→ デセラレーション区間の長さ・深さがペナルティの根拠となる。

### 3.3 採用する指標体系

#### (A) Mean Propulsive Velocity（MPV）— 速度の質評価

```
MPV = a_vertical > 0 の区間のみの平均速度  [m/s]
```

加速度が正（推進している）区間だけを対象にすることで、
デセラレーション（負荷が抜けている）区間を除外した真の推進速度を測定。
VBT研究ではスクワット・ベンチプレスの1RM推定精度 **≥95%**。

**「ゆっくり丁寧」の評価**: MPVが低いほど良い動作 → 直接的な評価指標

#### (B) Deceleration Ratio（DR）— 負荷が抜けた割合

```
DR = デセラレーション区間の時間 / コンセントリック全体の時間  [0〜1]
```

- DRが大きい（0.5以上）= 後半で大きく制動 = 負荷が抜けている
- DRが小さい（0.2以下）= ほぼ等速〜加速で完遂 = 負荷をかけ続けている

#### (C) Absolute Work（絶対仕事量）— エネルギー指標

上下の符号を取らずに積算：

```
W_abs = ∫ F_effective(t) × |v(t)| dt
      = ∫ m × (g + a(t)) × |v(t)| dt   [J]
```

往復でゼロにならず、丁寧な動作ほど積算値が増大する。

#### (D) Time Under Tension（TUT）— 緊張時間

```
TUT = コンセントリック時間 + 等尺性保持時間 + エキセントリック時間  [s]
```

IMUでゼロクロス検出により計測可能。
等尺性保持フェーズ（バーが静止）の時間も加算する。

#### (E) Isometric Hold Duration（IHD）— 等尺性保持時間

```
IHD = |v(t)| < 閾値(0.02 m/s) が継続した時間  [s]
```

「50%地点で止めて気合いで上げる」ケースを捉える重要指標。
IMUで計測可能（速度がゼロに近い区間を検出）。
**注意**: 保持中の発揮力はIMUでは計測不可。力はユーザー入力重量からm×gで推定。

#### (F) Velocity Loss（VL）— セット内疲労

```
VL(%) = (第1レップのMPV - 現在のレップのMPV) / 第1レップのMPV × 100
```

疲労による速度低下を定量化。カットオフ目安: ベンチプレス 35%、スクワット 30%。

### 3.4 総合スコア（Q_score）の定義

上記指標を組み合わせたスコア：

```
Q_score = W_abs × quality_factor

quality_factor = (1 - α × DR) × (1 + β × IHD_ratio) × (1 - γ × a_peak_penalty)
```

- `DR`: Deceleration Ratio（高いと減点）
- `IHD_ratio = IHD / TUT`: TUT中の等尺性保持割合（高いと加点）
- `a_peak_penalty = clip(a_max / g, 0, 1)`: 最大加速度ペナルティ（力-速度関係から）
- `α ≈ 0.4`, `β ≈ 0.3`, `γ ≈ 0.3`（チューニングパラメータ）

**直感的な意味**:
- ゆっくり等速で上げる → DR小、a_max小 → quality_factor高 → 高スコア
- 途中で止めて再開 → IHD大 → quality_factor高 → 高スコア
- 一瞬で爆発的に上げて止める → a_max大、DR大 → quality_factor低 → 低スコア

### 3.5 等尺性収縮フェーズの扱い（重要な制約）

**IMUのみでは等尺性中の発揮力は計測できない**（バーが動かないためIMU応答なし）。

| 計測できること | 計測できないこと |
|-------------|----------------|
| 保持継続時間（IHD） | 保持中の実際の筋力（N） |
| 保持開始・終了タイミング | 最大随意収縮に対する%強度 |
| 静止中の微細な振動 | Rate of Force Development（RFD） |

**将来の拡張**: バーにロードセル（FSRセンサー）を取り付けることで等尺性中の力を直接計測し、Impulse（= ∫F dt）を算出できる。

### 3.6 レップ検出フロー

```
1. 静止状態検出（|v| < 0.02 m/s が0.5秒継続）
2. コンセントリック開始（v > 0.05 m/s）
3. 等尺性保持の検出（|v| < 0.02 m/s が0.1秒継続, but not rep end）
4. 頂点検出（速度が正→負にゼロクロス）
5. エキセントリック（v < 0）
6. 静止状態検出 → 1レップ完了
   → 各指標を記録（MPV, DR, W_abs, TUT, IHD）
```

### 3.7 セッション総合指標

```
Session_W_abs = Σ W_abs_i          // 総絶対仕事量
Session_Score = Σ Q_score_i        // 総合スコア
VL_final = (MPV_1 - MPV_last) / MPV_1 × 100  // セット内疲労度
```

---

## 4. 各指標のIMU計測可否まとめ

| 指標 | IMUのみ | 精度 | ロードセル追加時 |
|------|--------|------|----------------|
| Mean Propulsive Velocity（MPV） | **可** | 良（ICC 0.91-0.96） | — |
| Deceleration Ratio（DR） | **可** | 良 | — |
| Absolute Work（W_abs） | **可** | 中（ドリフト誤差） | 高精度化 |
| Time Under Tension（TUT） | **可** | 良 | — |
| Isometric Hold Duration（IHD） | **可** | 良（速度閾値で検出） | — |
| Velocity Loss（VL） | **可** | 良（相対値） | — |
| 等尺性 Impulse（∫F dt） | **不可** | — | **可能に** |
| Rate of Force Development（RFD） | 限定的 | 低 | **高精度に** |
| Metabolic Stress | **不可** | — | EMG等が必要 |

---

## 5. トレーニング種目の自動認識

### 5.1 IMUベースの認識（優先）

| 種目 | バーの動き | IMU特徴 |
|------|------------|---------|
| ベンチプレス | 鉛直上下 | Z軸主成分、傾きほぼ水平、仰向け姿勢 |
| スクワット | 鉛直上下 | Y軸主成分、バー肩載せ位置 |
| デッドリフト | 鉛直上下 | 加速度の立ち上がり急峻、振れが大きい |
| ショルダープレス | 鉛直上下 | バーが頭上まで到達（変位大） |
| バーベルロウ | 水平+鉛直 | 複合軸運動 |

### 5.2 カメラベースの認識（オプション）

- Vision framework + Core ML による姿勢推定
- セットアップ時に1フレームでユーザーポーズを判定
- ベンチ（仰向け）/ スクワット（直立）/ デッドリフト（前傾） を分類

---

## 6. アプリ機能

### 6.1 セッション計測画面

- リアルタイム表示:
  - 現在の速度 [m/s]
  - MPV（推進速度）
  - Deceleration Ratio（緑〜赤のゲージ）
  - 等尺性保持中の表示（タイマー）
  - レップカウンター
  - 今レップのQ_score
- セット設定:
  - バー重量 + プレート重量入力
  - 目標レップ数

### 6.2 レポート画面

#### セット単位レポート
- レップごとの棒グラフ（Q_score, W_abs）
- MPVの時系列グラフ（疲労検出）
- Deceleration Ratio per レップ
- TUT / IHD の内訳（コンセントリック / 等尺性 / エキセントリック）

#### セッション単位レポート
- 総仕事量・総スコア
- Velocity Loss推移
- 種目別サマリー

#### 長期トレンド（履歴）
- 週次・月次の総仕事量推移
- 種目別パフォーマンス推移
- Personal Record管理（Q_score, W_abs, MPV）

### 6.3 種目管理
- プリセット種目（ベンチプレス、スクワット、デッドリフト等）
- カスタム種目の追加

---

## 7. 技術スタック

### iOSアプリ
- **言語**: Swift
- **フレームワーク**:
  - `Core Motion`: IMUデータ取得（100Hz）
  - `Vision` / `Core ML`: 種目認識
  - `SwiftUI`: UI
  - `Charts`（Swift Charts）: グラフ表示
  - `SwiftData`: ローカルデータ保存

### データフロー
```
IMU (100Hz) → バッファリング → ローパスフィルタ
→ 速度積分（ZUPTドリフト補正）
→ レップ・等尺性フェーズ検出
→ MPV / DR / W_abs / TUT / IHD の計算
→ Q_score算出
→ UI更新（30Hz）/ DB保存
```

---

## 8. 技術的課題と対策

### 課題1: 加速度積分のドリフト
- **問題**: 加速度を積分すると誤差が累積して速度がずれる
- **対策**: 静止フェーズ（レップ間・等尺性保持中）でゼロ速度補正（ZUPTアルゴリズム）

### 課題2: 有効質量の不明
- **問題**: iPhoneだけでは荷重を直接計測できない
- **対策**: ユーザーが重量を手動入力。相対比較としてのスコアを使用

### 課題3: 等尺性収縮中の力計測不可
- **問題**: バーが静止しているとIMUでは力が分からない
- **対策**: IHD（保持時間）+ 入力重量からImpulse推定値（m×g×IHD）で代替。将来はロードセル追加

### 課題4: MPV計算の閾値設定
- **問題**: 加速度がゼロになる瞬間を正確に検出する必要がある
- **対策**: カルマンフィルタで加速度計とジャイロを融合。ノイズ閾値を動的調整

### 課題5: バーへのiPhone固定
- **問題**: 安定したマウントが必要
- **対策**: バーベルクランプ型スマホホルダーを使用（市販品）

---

## 9. 開発ステップ

### Phase 1: プロトタイプ（MVP）
- [ ] Core Motionで加速度・ジャイロデータ取得（100Hz）
- [ ] 速度積分（ZUPTドリフト補正）
- [ ] レップ自動検出（ゼロクロス）
- [ ] 等尺性保持フェーズ検出（IHD）
- [ ] W_abs / MPV / DR の計算
- [ ] Q_score算出
- [ ] 基本UI（リアルタイム速度・DR・IHD表示）

### Phase 2: 計測精度向上
- [ ] カルマンフィルタの実装
- [ ] quality_factorパラメータ（α, β, γ）のキャリブレーション
- [ ] バー固定位置の補正（iPhoneがバーの端にある場合の回転補正）
- [ ] デセラレーションフェーズ検出の精度向上

### Phase 3: レポート機能
- [ ] セット・セッションレポート画面
- [ ] Swift Chartsによるグラフ（TUT内訳、MPV時系列、DR棒グラフ）
- [ ] SwiftDataによるデータ永続化
- [ ] 長期トレンド表示

### Phase 4: 種目認識
- [ ] IMUパターンによる種目自動認識
- [ ] カメラ + Vision frameworkによる姿勢認識（オプション）

### Phase 5: 拡張
- [ ] ロードセル/FSRセンサー連携（等尺性Impulse計測）
- [ ] M5StickC連携（BLE）
- [ ] Apple Watch連携（心拍数との相関）

---

## 10. 実装例（疑似コード）

```swift
struct RepMetrics {
    var W_abs: Double = 0.0           // 絶対仕事量 [J]
    var mpv: Double = 0.0             // Mean Propulsive Velocity [m/s]
    var decelerationRatio: Double = 0.0  // Deceleration Ratio [0-1]
    var tut: Double = 0.0             // Time Under Tension [s]
    var ihd: Double = 0.0             // Isometric Hold Duration [s]
}

func processIMUSample(a_vertical: Double, dt: Double, mass: Double) {
    let g = 9.81

    // 速度積分（重力補正済みの純加速度を積分）
    velocity += a_vertical * dt

    // ZUPT: 静止検出時にドリフト補正
    if isStationary { velocity = 0.0 }

    // 絶対仕事量
    let F_effective = mass * (g + a_vertical)
    W_abs += F_effective * abs(velocity) * dt

    // Mean Propulsive Velocity: a_vertical > 0 の区間のみ
    if a_vertical > 0 {
        propulsiveTimeSum += dt
        propulsiveVelocitySum += velocity * dt
    }

    // Deceleration Ratio計算
    if isConcentricPhase {
        concentricTime += dt
        if a_vertical < 0 { decelerationTime += dt }
    }

    // Isometric Hold Duration
    if abs(velocity) < 0.02 && isInRep { ihd += dt }
}

func calculateQScore(metrics: RepMetrics, alpha: Double = 0.4,
                     beta: Double = 0.3, gamma: Double = 0.3) -> Double {
    let a_peak_penalty = min(a_peak / 9.81, 1.0)
    let ihdRatio = metrics.tut > 0 ? metrics.ihd / metrics.tut : 0.0
    let qualityFactor = (1 - alpha * metrics.decelerationRatio)
                      * (1 + beta * ihdRatio)
                      * (1 - gamma * a_peak_penalty)
    return metrics.W_abs * qualityFactor
}
```

---

## 11. 成功指標

| 指標 | 目標 |
|------|------|
| レップ検出精度 | > 95% |
| MPV推定誤差 | < 0.05 m/s（対LPT比較） |
| 等尺性フェーズ検出 | > 90%（0.3秒以上の保持） |
| アプリ遅延 | < 100ms（リアルタイム表示） |
| スコアの再現性 | 同条件で ±5% 以内 |

---

## 12. 参考文献

- Hill's muscle model: Hill (1938), PMC3840917
- VBT / MPV: NSCA VBT review, PMC7739360
- Deceleration phase ratio: Sanchez-Medina et al. (2010)
- Sticking point: PMC5357260
- IMU validity for barbell velocity: PMC8038306, MDPI sensors 2021
- Isometric impulse as training metric: ScienceDirect (2025)
- Velocity Loss thresholds: PMC7558277

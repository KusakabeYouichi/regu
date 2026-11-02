---
type: impl-report
cycle: c09
title: リファクタリング(名前の見直し・使い道が 1 つの定数を畳む・条件式の簡略化)
branch: main
base: main
issue: なし
date: 2026-11-02
scale: 小
stages:
  - {stage: 0, status: done}
  - {stage: 1, status: done, agent: Plan, reason: "本体の全ファイルを別エージェントに読ませて候補 13 件を出させ、メインが 9 件を採った"}
  - {stage: 2, status: done, reason: "振る舞いを変えないので既存のテストが合否条件。追加はしない"}
  - {stage: 3, status: skipped, reason: "機械的な改名・畳み込みのみ。候補を出した側とは別のエージェントが段 5 で差分と設計を読んだ"}
  - {stage: 4, status: done, agent: implementer}
  - {stage: 5, status: done, agent: code-reviewer}
  - {stage: 6, status: done, agent: main, reason: "既存の単体テストを実行。テストは関数名の改名に追随しただけで観点は変えていないので、テストを読む・赤を先に見るは省略"}
  - {stage: 7, status: done, agent: main, reason: "XCUITest を iPhone・iPad で全件"}
  - {stage: 8, status: done, agent: main, reason: "小規模のため差分と設計の突き合わせで代替(段 5 で設計外の変更なしを確認済み)"}
  - {stage: 9, status: done}
  - {stage: 10, status: done}
adversarial:
  findings: 0
  rejected: 0
---

# リファクタリング(名前の見直し)

## 要求事項

- ソースのリファクタリング。変数名・メソッド名が妥当かも見直す
- 振る舞いは変えない。保存データ(Codable のキー・UserDefaults のキー・rawValue)、accessibilityIdentifier、起動引数、表示文言は変えない

## 実装

| # | 場所 | 変更 | 理由 |
|---|---|---|---|
| C1 | `PresetStore` | コメント「以下 3 つとも」→「以下はいずれも」 | 対象のメソッドが 4 つに増えていた |
| C2 | `UnitConversion` | private な辞書 `ligatureToSI` → `siByLigature` | `UnitOption.ligatureToSI` と同名で紛らわしい |
| C3 | `Theme` | `accentPlatformColor` を `accent` の定義に畳む | 使い道が 1 か所。paper / card などと同じ書き方に |
| C4 | `MainView` | `isLandscape ? 56 : (isInputFocused ? 56 : 120)` → `isLandscape \|\| isInputFocused ? 56 : 120` | 同じ値の分岐をまとめる |
| C5 | `Converter` | `isASCIIAlphanumeric` を private に | Converter の中でしか使わない |
| C6 | `ConversionSession` | `convertTapped()` → `convertInput()`(テストの関数名も追随) | モデルに UI の出来事の名前が付いていた |
| C7 | `ConversionSession.convertAndCopy` | `store.selectedPreset.settings` を 1 回だけ読む | 変換と指紋に同じ設定を使うことを明示 |
| C8 | `ReguApp` | `handle(_:)` → `handleScenePhase(_:)` | 何を扱うかが名前に無かった |
| C9 | `MainView` | `presetChip(height:)` / `settingsButton(size:)` の引数をやめ、定数 `controlHeight = 44` に | 呼び出しがすべて 44 |

見送ったもの:
- Option enum の `init(from:)` の共通化。合成された `init(from:)` が選ばれると、未知の rawValue で読み込みに失敗し、保存データの互換が崩れる
- iOS / macOS の Coordinator の統合、カードとカプセルの背景の統合。新しい抽象化が要る
- `convertAccent` の到達しない guard の削除。意図が読めなくなる
- `decodeReference` の return の統合、`UnitConversion.convert` の分割、`unusedName(startingWith:)` の改名。効果が小さい

## 検証

- `swift test` 109 件成功
- XCUITest(iPhone 全件): 18 件成功・1 件失敗(E11)・iPhone では対象外のスキップ 6 件(スクリーンショット撮影 5 件・iPad 専用 1 件)
  - 失敗した E11(「コピーしました」が 1.5 秒の表示中に検出できるか)を単独で再実行: 変更後のコードで全件実行の 1 回を含め 7 回中 5 回成功(失敗は全件実行とその直後の 1 回)、変更前のコードで 3 回中 3 回成功
  - 差分は表示の時間や「コピーしました」の処理に触れていない。検出の遅れで落ちる時間依存のテストと判断した(下の申し送り)
- XCUITest(iPad 全件): 5 件成功・iPhone 専用のスキップ 23 件
- コードレビュー: 指摘なし(三項演算子と `||` の優先順位で値が変わらないこと、旧名の残りが無いこと、設計外の変更が無いことを確認)

## 残課題 / 申し送り

- E11 は「1.5 秒で消える表示を検出してから押し直す」形のため、シミュレータが遅いと落ちることがある。直すならテストの待ち方を見直す(今回は範囲外)

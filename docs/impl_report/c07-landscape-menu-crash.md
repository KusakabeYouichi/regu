---
type: impl-report
cycle: c07
title: 横長でキーボード表示中にプリセットのチップを押すと落ちる(c05 の退行)を直す
branch: main
base: main
issue: なし
date: 2026-10-30
scale: 小
stages:
  - {stage: 0, status: done}
  - {stage: 1, status: done}
  - {stage: 2, status: done}
  - {stage: 3, status: done, agent: code-reviewer, reason: "小規模のため、設計への反証を段 5 のレビューに同じ依頼で含めた"}
  - {stage: 4, status: done, agent: main}
  - {stage: 5, status: done, agent: code-reviewer}
  - {stage: 6, status: done, agent: main, reason: "E17 を追加し、c05 の実装で落ちることを先に確認。test-reviewer は省略"}
  - {stage: 7, status: done, agent: main, reason: "XCUITest 全件を iPhone・iPad で実行。最後の 1 行の修正の後は横長の 3 本を再実行"}
  - {stage: 8, status: done, agent: main, reason: "小規模のため差分確認で代替"}
  - {stage: 9, status: done}
  - {stage: 10, status: done}
adversarial:
  findings: 4
  rejected: 3
---

# 横長・キーボード表示中のチップでのクラッシュ

## 要求事項

実機(iPhone 15、Xcode から入れた最新版)で、横向きでキーボードを出した後に画面が縮んだまま戻らない。Xcode には
「Fatal error: Starting a pivot morph to a view that isn't in the view hierarchy」(ButtonHost)が出ていた。
キーボードが出ていないときの配置が崩れるなら、キーボード表示中だけ動かしてよい(ユーザー、c05 のとき)。

## 原因

c05 で中央の列を `ViewThatFits` の 2 つの形(通常・詰めた形)にした。キーボード表示中にチップを押すと、その押下でキーボードが閉じ、
列が詰めた形から通常の形の別の View に差し替わる。開き始めたメニューが消えたボタンから開こうとして UIKit が落ちる。
「画面が縮んだまま戻らない」は、落ちた時点でデバッガが止めて固まった姿だった。

## 主要な実装の詳細

- 変更ファイル: `Packages/ReguKit/Sources/ReguUI/MainView.swift`
- 列は 1 つの View のまま、間・タイルの大きさ・キャプションだけを変える(c05 より前の形に戻した)
- 詰めた形にするかは、キーボードの通知(willShow / willHide)で決める。画面に出ているキーボードの高さが 100pt を超えたら詰める。
  ハードウェアキーボードの候補バーだけのときは超えない。枠を画面外に置いて通知することがあるため、画面と重なる分の高さだけを測る
- **なぜそうしたか**: 列や画面の高さは中身に押し広げられるので、大きさから判定すると文字サイズが大きいときに切り替わらない(c05 の原因)。
  途中で「キーボードを除いた高さ − 使える高さ」で判定する案も試したが、同じ理由で E12b が赤になった
- 結果として、横長でキーボードが出ている間は、文字サイズや機種によらず常に詰めた形になる(ユーザーの許可の範囲)

## 検証結果

| 内容 | 結果 |
|---|---|
| E17(新): 横長・キーボード表示中にチップからプリセットを選ぶ | c05 の実装ではアプリが落ちて赤、修正後は緑 |
| E12 / E12b / E13 | 緑(E12b は文字サイズ AccessibilityL、iPhone 17) |
| UI テスト全件 | iPhone 17 Pro Max: 17 件が緑(iPad 専用の E8 は飛ばした)。iPad: E8 が緑 |
| `swift build`(macOS)・`swift test` | 成功・98 件が緑 |

## 敵対的検証・コードレビューの結果

| # | 指摘 | 対処 |
|---|---|---|
| 1 | ハードウェアキーボードで、通知の枠の高さが候補バーより大きいことがある | 画面と重なる分の高さで判定するように修正 |
| 2 | 他の窓のキーボードでも詰めた形になる | 複数ウィンドウは無効(Info.plist の UIApplicationSupportsMultipleScenes = false)。却下 |
| 3 | 切り替えにアニメーションが無い | 見た目だけ。現状維持(却下) |
| 4 | iPad でも詰めた形になる | 見た目だけ。押せる大きさは保つ。現状維持(却下) |

## 残課題 / 要確認 / 申し送り

- c05 のレポートの実装(ViewThatFits)は本サイクルで置き換えた
- 実機(iOS 27)での確認はユーザーに依頼中

---
type: impl-report
cycle: c08
title: アクセントカラーをロゴの朱に・選択を生成りに・複製と新規の名前に番号を振る・複製を左スワイプに・名前の重なりを知らせる
branch: main
base: main
issue: なし
date: 2026-10-31
scale: 小
stages:
  - {stage: 0, status: done}
  - {stage: 1, status: done}
  - {stage: 2, status: done}
  - {stage: 3, status: skipped, reason: "小規模。ユーザーと会話で案を決めて進めたため、反証は段 5 のレビューに含めた"}
  - {stage: 4, status: done, agent: main}
  - {stage: 5, status: done, agent: code-reviewer}
  - {stage: 6, status: done, agent: main, reason: "単体テスト 11 本と E18 を追加。E18 は変更前のソースで落ちることを確認。test-reviewer は省略"}
  - {stage: 7, status: done, agent: main, reason: "XCUITest を iPhone で全件(レビュー指摘の修正後に再実行)、iPad は修正前に全件"}
  - {stage: 8, status: done, agent: main, reason: "小規模のため差分確認で代替"}
  - {stage: 9, status: done}
  - {stage: 10, status: done}
adversarial:
  findings: 5
  rejected: 2
---

# アクセントカラー・選択の色・プリセットの名前

## 要求事項

- アクセントカラーをロゴの赤に合わせる
- 結果欄の選択の色は面が大きいので、別の色(生成り)にする。ハンドルの色も変えてよい
- 複製の名前を「xxx copie」「xxx copie 2」…にする(2 回目の複製が同じ名前にならないように)
- 複製の操作を左スワイプに。ビルトインの注記で複製のしかたを教える
- 新しく作るときも名前が重ならないようにし、名前を変えて重なったら知らせる

## 実装

- `Theme`: 朱をライト #AD2533・ダーク #F0707E(アイコンの画素から採った値)。選択の地 `selectionPlatformColor` はカードの上でライト #EAE0CF・ダーク #554C3F。
  iOS は選択の地を `tintColor` にライト約 20%・ダーク約 35% を掛けて描く(シミュレータの画素で測定)ので、結果欄の `tintColor` を #96640F / #BBA17C にした。
  `UITextSelectionDisplayInteraction` の `highlightView` だけを塗り替える案は、`UITextView.interactions` に見つからず効かなかった
- `PresetStore`: `duplicate(_:)` が名前を決める(末尾の「 copie」「 copie N」を外してから番号を振る)。`unusedName(startingWith:)` は名前とビルトインの別名を使用中とみなす。
  `hasOtherPreset(named:excluding:)` は名前の重なりの判定
- `PresetListView`: 行の操作を `swipeActions(edge: .trailing, allowsFullSwipe: false)` にまとめ、`onDelete` を外した。+ は `unusedName` で「新しいプリセット 2」…を付け、何も変えていないかの判定はその名前で行う
- `PresetEditorView`: ビルトインの注記を「一覧で行を左へスワイプするか長押しすると複製でき、…」に。名前が重なれば入力欄の下に「同じ名前のプリセットがあります」(保存は止めない)

## 検証

- `swift test` 109 件成功(追加: D1〜D6、U1〜U3、W1〜W2)
- E18(左スワイプの複製・重なりの知らせ・「新しいプリセット 2」・注記)は変更前のソースで「左へ払っても複製が出ない」で失敗、変更後に成功
- XCUITest: iPhone 18 件成功・1 件(iPad 専用)スキップ。レビュー指摘の修正後に再実行して同じ結果。iPad は修正前に E8 成功
- 選択の地の色はシミュレータのスクリーンショットの画素で #EAE0CF / #554C3F を確認

## コードレビューの指摘と処分

| # | 指摘 | 処分 |
|---|---|---|
| 1 | `unusedName` が別名を見ないので、付けた直後に重なりを知らせることがある | 修正(U3) |
| 2 | 名前が「 copie」だけのとき複製名が空白で始まる | 修正(D6) |
| 3 | 払い切るだけで複製・削除が実行される | 修正(`allowsFullSwipe: false`) |
| 4 | 非ビルトインでは名前と表示名の比較が重複 | 却下(別名でも比べる意図を残す) |
| 5 | 別名付きビルトインの複製が本当の名前 + copie になる | 却下(複製は元のプリセットの名前を基にする) |

## 残課題 / 申し送り

- App Store のスクリーンショットは、色と「ここにcoller」を反映して撮り直す(ユーザーが後でまとめて行う)

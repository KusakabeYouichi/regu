---
type: impl-report
cycle: c05
title: 横長でキーボード表示中、中央の列(チップ・変換タイル・設定)が上下に見切れるのを直す
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
  - {stage: 6, status: done, agent: main, reason: "UI テストの強化と追加 1 本。旧実装で赤になることを先に確認(test-reviewer は省略。期待は枠の座標の比較だけ)"}
  - {stage: 7, status: done, agent: main, reason: "XCUITest 全件を iPhone と iPad で実行"}
  - {stage: 8, status: done, agent: main, reason: "小規模のため差分確認で代替"}
  - {stage: 9, status: done}
  - {stage: 10, status: done}
adversarial:
  findings: 4
  rejected: 0
---

# 横長・キーボード表示中の中央の列の見切れ

## 要求事項

iPhone の横向きでキーボードを出すと、設定ボタンやプリセットの選択チップが見切れる(ユーザーの実機のスクリーンショット)。見切れないようにする。
キーボードが出ていないときの配置が崩れるなら、キーボード表示中だけ動かしてよい(ユーザー)。

## 原因

中央の列は自分の高さを測り、200pt 未満なら詰めた形(タイル 44pt・「変換」の字なし)にしていた。
しかし列の高さは中身に押し広げられるため、通常の形の中身が 200pt を超えると(文字サイズが大きいと「変換」の字が伸びる)測った値も 200 以上になり、詰めた形に切り替わらなかった。
既定の文字サイズでは中身が約 194pt で切り替わるため、これまでの UI テストでは見つからなかった。

## 主要な実装の詳細

- 変更ファイル: `Packages/ReguKit/Sources/ReguUI/MainView.swift`
- 列の高さを測るのをやめ、`ViewThatFits(in: .vertical)` に通常の形と詰めた形を順に渡す。使える高さに通常の形が収まらなければ詰めた形になる
- **なぜそうしたか**: 判定に使う高さを中身から切り離すため。通常の形・詰めた形の寸法は変えていないので、キーボードが出ていないときと iPad の配置は変わらない
- 2 つの形は別の View なので、切り替わる瞬間に開いていたメニューは閉じる(コメントに記載)

## 検証結果

| 内容 | 結果 |
|---|---|
| 再現(旧実装): iPhone 17 のシミュレータ、文字サイズ AccessibilityL、横向き・キーボード表示 | E12b が赤(チップの上端 -3.7pt、設定ボタンの下端 224.7pt > キーボード上端 221pt) |
| 修正後: 同じ条件 | E12・E12b とも緑。スクリーンショットで詰めた形が収まることを目視 |
| UI テスト全件 | iPhone(17 Pro Max): 15 件が緑、iPad 専用の 1 件は飛ばした。iPad: E8(横向き・キーボード)が緑、iPhone 専用は飛ばした |
| `swift test` | 93 件が緑 |

E12 は、チップ・変換・設定の枠の全体が画面の内側かつキーボードより上にあることを見るように強化した(isHittable だけでは一部の見切れを見逃す)。

## 敵対的検証の結果

| # | 指摘 | 対処 |
|---|---|---|
| 1 | 設計の文字サイズ(XL)とテスト(AccessibilityL)が食い違う | 設計を AccessibilityL に直した |
| 2 | レポートが差分に無い | 本レポートを同じコミットに含めた |
| 3 | 切り替えで Menu が作り直される | 実用上まれ。コメントに記載 |
| 4 | テストのコメントが読みにくい | 書き直した |

## 残課題 / 要確認 / 申し送り

- 使える高さが詰めた形(約 140pt)にも足りない場合は、従来どおり見切れる。現行の iPhone の横向きでは到達しない見込み
- 新しいシミュレータ regu-iPhone-small(iPhone 17、iOS 26.5、7A7CCE02-4D16-4A2F-B09A-B695C893F164)を作った。画面の小さい機種での確認に使う

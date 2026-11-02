---
type: impl-report
cycle: c11
title: régu の操作マニュアル(docs/manual)と、プリセット一覧からの入口
branch: main
base: main
issue: なし
date: 2026-11-02
scale: 中
stages:
  - {stage: 0, status: done}
  - {stage: 1, status: done, reason: "マニュアルを新しく作る・入口はプリセット一覧の下、はユーザーが選んだ"}
  - {stage: 2, status: done}
  - {stage: 3, status: skipped, reason: "文書が主。事実の誤りは段 8 で別エージェントがソースと突き合わせた"}
  - {stage: 4, status: done, agent: "implementer(マニュアル)/ main(アプリの入口)"}
  - {stage: 5, status: done, agent: main, reason: "アプリの変更は Section 1 つと Link のみ"}
  - {stage: 6, status: done, agent: main, reason: "UI テスト E19 を追加。リンクを消せば存在確認で落ちるのは自明なので赤を先に見るは省略"}
  - {stage: 7, status: done, agent: main, reason: "XCUITest を iPhone で全件"}
  - {stage: 8, status: done, agent: reality-checker}
  - {stage: 9, status: done}
  - {stage: 10, status: done}
adversarial:
  findings: 6
  rejected: 0
---

# 操作マニュアルとアプリからの入口

## 要求事項

- アプリからマニュアルに飛ぶ動線を付ける
- ユーザーの決定: マニュアルを新しく作る(écritu の docs/manual に倣う)、入口はプリセット一覧のいちばん下

## 実装

- `docs/manual/`(日本語): 目次・第1章 régu とは・第2章 基本の使い方・第3章 プリセット・第4章 設定リファレンス・第5章 困ったとき。付録はサポートページのプライバシーポリシーへリンク。図は App Store 用のスクリーンショットを縮小して使う。JS なし
- サポートページ(日本語の節)に「操作マニュアル」へのリンクを 1 行
- `PresetListView`: いちばん下に Section を足し、Link「使い方(マニュアル)」(book のアイコン)→ https://kusakabeyouichi.github.io/regu/manual/ 。識別子 `manualLink`
- UI テスト E19: 一覧に「使い方(マニュアル)」があり、ユーザー設定より下にあり、押すと Safari が前面に来る
- プリセット一覧のスクリーンショット(App Store 用 iPhone・iPad、マニュアルの図)を、入口の行が入った画面に撮り直した

## 検証

- マニュアルの相対リンク・画像・アンカー 62 件の実在(スクリプト)。errors 0
- 第4章の変換例は ReguCore の `Converter.convert` を実際に呼んで一致を確認(書いた役)
- 別エージェントによるソースとの突き合わせ: 約 80 件一致、6 件を修正(下表)
- XCUITest(iPhone 全件)26 件中 20 件成功・6 件スキップ(iPhone 対象外)・失敗 0

## 突き合わせの指摘と処分

| # | 指摘 | 処分 |
|---|---|---|
| 1 | チップで開くのはメニューで、「プリセットの一覧」ではない | 修正 |
| 2 | 一覧に「使い方(マニュアル)」の節があることが抜けている | 修正 |
| 3 | les katakana は ー ⇄ ｰ も変える | 修正 |
| 4 | 配置は機種の向きではなくウインドウの形で決まる | 修正 |
| 5 | 番号付けはビルトインの alias と同じ名前も避ける。ビルトインの複製は本来の名前が元 | 修正 |
| 6 | マニュアルへのリンクはブラウザで開く(アプリ自身は通信しない) | 修正 |

## あわせて直したもの(突き合わせの途中で見つかった既存の誤り)

- `appstore/metadata.md`: 「&eacute; ⇄ é」は誤り(文字参照にするのは & < > " ' の 5 文字だけ)。日本語・フランス語とも「&eacute; を é に(逆向きは & や引用符など 5 つの記号だけ)」の形に。ASC は < > を含む説明文をマークアップとして拒否するため、記号は書き出さない。ASC の説明文も更新済み
- `docs/privacy.html`: 端末内に保存する情報に、ビルトインの alias と、書き戻した内容から計算した照合用の値を追記。改定日を記載(日本語・フランス語)

## 残課題 / 申し送り

- ペーストの許可の iOS 設定の経路はサポートページの FAQ と同じ文言。実機での確認はしていない
- マニュアルはフランス語版なし

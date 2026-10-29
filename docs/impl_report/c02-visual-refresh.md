---
type: impl-report
cycle: c02
title: メイン画面の見た目の刷新(カード・タイルの変換ボタン・横向き配置)
branch: main
base: main
issue: なし
date: 2026-10-29
scale: 中
stages:
  - {stage: 0, status: done}
  - {stage: 1, status: done}
  - {stage: 2, status: done}
  - {stage: 3, status: done, agent: adversarial-reviewer}
  - {stage: 4, status: done, agent: implementer, model: opus}
  - {stage: 5, status: done, agent: code-reviewer}
  - {stage: 6, status: done, agent: implementer+test-reviewer, model: opus, reason: "Core は無変更(既存 68 件を回すだけ)。赤を先に見るは UI テストのみの追加のため省略"}
  - {stage: 7, status: done, agent: implementer(XCUITest), model: opus}
  - {stage: 8, status: done, agent: reality-checker}
  - {stage: 9, status: done}
  - {stage: 10, status: done}
adversarial:
  findings: 14
  rejected: 0
---

# メイン画面の見た目の刷新

## 要求事項

簡素さは保ちつつ、現代的でかっこよく、そこそこの高級感を出す。アプリアイコンを小さくして変換ボタンにしてよい。
途中の決定: 変換ボタンはアイコンのタイル、コピー時に「✓ コピーしました」を小さく出す、カード見出しは entrée / résultat、
プリセット名が入らないときは文字を縮める(配置は中央のまま)、横向きでは横並び(キーボード表示中でも使える)。

## 対応スコープ

- 対象: 背景・カード・見出し・プレースホルダー、プリセットのチップ(Menu)、タイルの変換ボタン、設定の丸ボタン、コピー表示、ダークモード、横向きの横並び、UI テストの追随と追加(E11〜E14)
- 対象外: 変換ロジック・自動変換の条件(ReguCore 無変更)、プリセット編集画面の作り直し(差し色のみ)、アイコン画像の作り直し、macOS アプリ本体

## 参照した仕様

- 設計: `.claude/hataraku/progress/c02-design.md`(作業用)、テスト観点 `c02-tests.md`
- c01 の設計・完了レポート `docs/impl_report/c01-regu-initial.md`

## 実装概要

- ReguUI に `Theme`(紙の白 / 墨色、カード色、朱の差し色)、`TileConvertButton`、`CopiedBadge` を追加し、`MainView` を作り直した
- 変換ボタンの絵柄はアイコン 1024 から「れ＋朱の点」だけを透過 PNG で切り出し(`Sources/ReguUI/Resources/ConvertTile.png`)、タイルの白い面・角丸・影は SwiftUI で描く
- コピー表示は既存の `selectAllToken`(クリップボードへ書いた直後に必ず増える)をトリガーにし、Core は変えていない

## 主要な実装の詳細

### 配置
- 変更ファイル: `Sources/ReguUI/MainView.swift`
- 縦向き: entrée カード / 操作行(左 チップ・中央 タイル・右 設定)/ résultat カード。キーボード表示中はカードの最小高さを下げる
- 横向き(キーボードを除いた領域で幅 > 高さ): entrée / 幅 150 の中央列(チップ・タイル・設定)/ résultat。列の高さが 200 未満ならタイル 44pt・キャプションなし・間を詰める(チップと設定は 44pt のまま。段 8 の指摘で 36pt から戻した)。カードの見出しと本文の間は 12pt
- **なぜそうしたか**: iPhone 横向きでキーボードを出すと高さが大きく不足する(ユーザー指摘。約 150pt と見込んだが、iPhone 17 Pro Max の実測では中央列の高さは 200pt 以上)。入力・結果のビューは切り替えで作り直さない

### プリセットのチップ
- 1 行、入らなければ文字を 70% まで縮め、それでも入らなければ末尾を省略。accessibilityLabel「プリセット」、value に選択中の名前
- **なぜそうしたか**: 変換ボタンの中央配置を保つ(ユーザー選択)

### 変換ボタン・コピー表示
- 変更ファイル: `TileConvertButton.swift`, `CopiedBadge.swift`
- 1 要素「変換」として読み上げ、押下の縮小は Reduce Motion で無効、触覚は押下時のみ。画像が無いときはデバッグで assertionFailure
- コピー表示は結果カードの右下に 1 枚だけ、表示中の再トリガーで 1.5 秒を数え直す、背面へ移ったら消す、VoiceOver に読み上げ。文字サイズは .xxxLarge で頭打ち

### 色
- 朱 ライト #CF2222(白 5.38:1、紙 #F6F4F0 4.90:1)、ダーク #FF6B63(カード #1E1E1E 5.98:1、背景 #121212 6.72:1)

## 検証結果

| 段 | 内容 | 結果 |
|---|---|---|
| 6 UT | `swift test`(Packages/ReguKit)、`swift build`(macOS) | 68 件全緑、macOS ビルド成功 |
| 6 テストを読んだ(test-reviewer) | 高 2(E8 の回転未確認、E11 の数え直しが時間次第で空振り)・中 4・低 2 → 共通化 1 件を除き修正 | 直す → 直して通す |
| 7 E2E | XCUITest(専用シミュレータ iPhone 17 Pro Max / iPad Pro 13-inch、iOS 26.5)。E1〜E14。E8 は横向きでキーボード表示中も変換ボタンが押せることを確認(キーボードが出ない環境では理由付きで skip) | iPhone: E1〜E7, E9〜E14 通過(一部は単独再実行で通過)、iPad: E8 通過。失敗はいずれも起動直後の応答待ちの時間切れ・回転しない等の環境側で、再実行で通過 |
| 7 見た目 | ライト / ダーク × iPhone / iPad、横向き＋キーボード、長いプリセット名、文字サイズ最大のスクリーンショットをユーザーに提示 | ユーザー確認済み(指摘 → チップ縮小・横向き配置を追加) |
| 規約 | R01〜R12 検査、括弧の空行スクリプト | 違反 0 |
| 8 実装実態検査 | reality-checker。実装は設計(追補含む)と一致、Core 無変更、色とコントラスト比を再計算して一致。指摘: 詰めた表示のチップ・設定 36pt(→ 44pt に修正)、レポートの関数名・150pt の書き方・未記載の変更(→ 修正) | 一致(処置済み) |

## 敵対的検証の結果(段 3)

| # | 指摘 | 対処 |
|---|---|---|
| 1 | iPhone でキーボード表示中に操作行が隠れる | 設計修正(最小高さを下げる、E4/E10 で hittable 検査) |
| 2 | ダークの朱のコントラスト不足 | 設計修正(#FF6B63、比を記録) |
| 3 | copyToken は selectAllToken と重複 | 設計修正(Core 無変更) |
| 4 | 起動時のコピー表示・連続トリガーが未定義 | 設計修正(起動時も出す、1 枚で数え直し) |
| 5 | 64pt で「régu」の文字が読めない・縁が二重 | 設計修正(「れ＋朱の点」だけを透過で切り出し、縁は SwiftUI) |
| 6〜14 | ダークのタイル、VoiceOver、Menu と UI テスト、Dynamic Type、選択色の macOS、プレースホルダーの読み上げ、触覚の範囲、編集画面の範囲、macOS ビルド | すべて設計に反映 |

## 省略した段とその理由

- 段 6 の赤を先に見る: ReguCore を変えておらず単体テストの追加が無いため省略。UI テストは test-reviewer で読んだ

## 残課題 / 要確認 / 申し送り

- 横向きの中央列を詰める表示(高さ 200pt 未満)は iPhone 17 Pro Max では起きず、画面で未確認(小さい機種での確認が要る)。段 8 の後にチップと設定を 44pt に揃えた変更は、この表示でしか効かないため UI テストは回していない(ビルド・規約検査のみ)
- 「キーボード表示中」は入力欄のフォーカスで判定している。iPad でハードウェアキーボードを使うとキーボードが出ないのにカードの最小高さが下がる(許容)
- E11(数え直し)と E14(背面で消す)は、XCUITest の検出遅れ(約 1.6 秒)のため検証が弱い
- UI テストは起動直後に応答待ちで時間切れになることがあり、単独の再実行で通る(環境側の不安定さ)。全件を一度に流すとシミュレータが回転しないことがあった(再起動で解消)
- UI テストの createPreset と createSwapPreset の重複は未整理

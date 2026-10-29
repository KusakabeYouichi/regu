---
type: impl-report
cycle: c04
title: 変換の実行順を「実行順」シートの 3 段階(Prétraitement → Traitement → Post-traitement)に合わせる
branch: main
base: main
issue: なし
date: 2026-10-29
scale: 小
stages:
  - {stage: 0, status: done}
  - {stage: 1, status: done}
  - {stage: 2, status: done}
  - {stage: 3, status: done, agent: adversarial-reviewer}
  - {stage: 4, status: done, agent: main}
  - {stage: 5, status: done, agent: code-reviewer}
  - {stage: 6, status: done, agent: main, reason: "追加 9 本はメインが書き、古い順序に戻して M1/M2 が赤になることを確認。test-reviewer は 2 段のレビューで代替(code-reviewer に期待値の手計算を依頼)"}
  - {stage: 7, status: skipped, reason: "画面・プリセットの値に変更なし。既定 3 プリセットの出力は新順でも不変(段 3 で手計算)"}
  - {stage: 8, status: done, agent: main, reason: "小規模のため差分確認で代替"}
  - {stage: 9, status: done}
  - {stage: 10, status: done}
adversarial:
  findings: 8
  rejected: 0
---

# 変換の実行順を 3 段階に合わせる

## 要求事項

numbers「実行順」シート(2026-10-29 追加)のとおり、Prétraitement を全部終えてから Traitement、それを全部終えてから Post-traitement を行い、各グループの中は番号順にする。
まず設計に問題が無いかを検討し、問題なければ実装を合わせる。

## 対応スコープ

- 対象: `Converter.convert` の並び替え、半角カナ化の結合濁点の扱い、順序に依存するテストの追加。`references/文字変換ルール 2018年11月.numbers`(「実行順」シート追加版)を同じコミットに含める
- 対象外: MIME decode/encode(まだ無い機能。コメントの枠だけ)、UI・保存データ・プリセットの値

## 参照した仕様

- `references/文字変換ルール 2018年11月.numbers` の「実行順」シート。切れていたセル(Post 3〜6)とTraitement 内の順はユーザー確認済み:
  Post 3 = JIS X 0208 → JIS X 0201(カナ)、4 = SI → ligature、5 = Code Point → URL Entity、6 = Code Point → HTML Entity。Traitement はシートの並び(ラテン → 空白 → 仮名 → 記号)
- 設計: `.claude/hataraku/progress/c04-design.md`、テスト観点 `c04-tests.md`

## 設計の検討結果

問題なし。各設定の 2 方向が前処理と後処理に分かれていて同時には走らないこと、Traitement の 5 項目は扱う文字が重ならず順序に依存しないこと、
半角カナ ↔ ひらがなの連携(前処理 4 → Traitement、Traitement → 後処理 3)が成り立つことを確認した。

## 主要な実装の詳細

### 並び替え
- 変更ファイル: `Sources/ReguCore/Converter.swift`
- 前処理: HTML decode → URL decode → ligature→SI → カナ 0201→0208 → NFC。Traitement: alphabet → space → hiragana → symbol → guillemets。後処理: NFD → カナ 0208→0201 → SI→ligature → URL encode → HTML encode
- **なぜそうしたか**: シートどおり。各処理の関数は方向ごとに呼び分けられる形だったので、並びだけを書き換えた

### 半角カナ化が結合濁点を扱う
- 変更ファイル: `Sources/ReguCore/KanaConversion.swift`
- 後処理 2 の NFD が ガ を カ+U+3099 に分解するため、後処理 3 の半角化が U+3099 / U+309A を ﾞ ﾟ に写すようにした。ただし直前に出した文字が半角カナ(U+FF66-FF9D)のときだけ(ひらがなの か+U+3099 や ヰ+U+3099 は残し、正準等価を保つ。段 5 の指摘で絞った)
- **なぜそうしたか**: シートの順(NFD → 半角化)を保ったまま「ふりがな → ﾌﾘｶﾞﾅ」を成り立たせるため。順序を入れ替える案は採らなかった

### 旧実装と結果が変わる組み合わせ(すべて実行順の帰結。テストで固定)
1. `&#37;41` + HTML/URL 復号 → `A`(旧 `%41`)。逆に `%26amp;` は `&amp;` のまま(旧 `&`)。URL 符号化された HTML 参照は解けない(既知の制限)
2. `１０ｍｍ` + 0208→ASCII + SI→組文字 → `10㎜`(旧 `10mm`)
3. `10mm` + ASCII→0208 + SI→組文字 → `１０ｍｍ`(旧 `１０㎜`。全角化すると組文字にならない)
4. `10 mm` + 空白の全角化 + SI→組文字 → `10　mm`(旧 `10　㎜`)
5. 『a』+ 『』→「」+ 半角カナ化 → `｢a｣`(旧 `「a」`)。「a」+ 「」→『』+ 半角カナ化 → `『a』`(旧 `｢a｣`)
6. `ｶ`+U+3099 + 0201→0208 + NFC → `が`(旧は合成されない)
7. `aé` + ASCII→0208 + NFD → `ａe`+U+0301(旧 `ａｅ`+U+0301。é は英字でないため全角化されず、最後に分解される)

既定 3 プリセット(régularisation / Adresse héritée / ruby héritée)の出力は変わらない。

## 検証結果

| 段 | 内容 | 結果 |
|---|---|---|
| 6 UT | `swift test`(Packages/ReguKit)、`swift build`(macOS)、iOS Release ビルド | 93 件全緑(M1〜M9、D2b を追加)、ビルド成功 |
| 6 赤を先に見た | Converter.swift を旧順(HEAD)に戻して実行 → M1・M2 が赤。半角化の「直前が半角カナ」の条件を外す → D2b が赤。戻して全緑 | |
| 5 コードレビュー | code-reviewer: 中 3(結合記号の無条件置換でひらがなの NFD 出力が「かﾞ」になる退行 → 直前が半角カナのときだけに修正／結果変化の漏れ(NFD + 全角化)→ 7 点目として追記・M9／観点表 M5 の不一致 → 修正)、低 2(設計の変更予定ファイル・レポートの同梱 → 対応) | 差し戻し → 修正して通過 |
| 規約 | R01〜R12、括弧の空行スクリプト | 違反 0 |

## 敵対的検証の結果(段 3)

| # | 指摘 | 対処 |
|---|---|---|
| 1 | M5 の期待値が誤り(全角化した ＜ も URL 符号化される) | 期待値を修正 |
| 2 | M4: NFD 後の半角化が結合濁点を残す | 半角化で U+3099/U+309A を扱う(D2b) |
| 3 | 結果が変わる組み合わせの漏れ 4 点 | 設計・レポートに追記、M3 改・M6・M7 で固定 |
| 4 | HTML→URL の順で失うもの(`%26lt;`)が未記載 | 既知の制限として記載、M8 で固定 |
| 段 5 | 結合記号の無条件置換がひらがなの正準等価を壊す | 半角カナ直後に限定(D2b で両方を固定) |
| 5〜8 | M3 が順序の検証になっていない、MIME の枠の範囲、赤の確認手順、設計書の食い違い | M3 の入力追加、コメントのみ、レポートに記録、c01-design に注記 |

## 省略した段とその理由

- 段 7(E2E): 画面に影響せず、既定プリセットの出力も不変のため

## 残課題 / 要確認 / 申し送り

- MIME decode/encode は未実装(シートの 前処理 6・後処理 1 の枠だけ)
- URL 符号化された HTML 参照(`%26lt;`)は、HTML を先に復号する順のため解けない(ユーザー確認済みの順の帰結)
- ASCII→JIS X 0208 または空白の全角化と SI→組文字を同時に使うと、組文字にならない(上記 3・4)

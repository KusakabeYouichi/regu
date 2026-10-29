---
type: impl-report
cycle: c01
title: régu(クリップボード文字変換アプリ)の新規作成
branch: feature/initial-app
base: main
issue: なし
date: 2026-10-29
scale: 中
# 規模の理由: 新規約 35 ファイル・約 4,200 行で大に近いが、1 アプリ 1 画面＋設定画面の 1 機能として中とした。作業役は opus(大と同じ)で運用
stages:
  - {stage: 0, status: done}
  - {stage: 1, status: done}
  - {stage: 2, status: done}
  - {stage: 3, status: done, agent: adversarial-reviewer}
  - {stage: 4, status: done, agent: implementer, model: opus}
  - {stage: 5, status: done, agent: code-reviewer}
  - {stage: 6, status: done, agent: implementer+test-reviewer+worker, model: opus}
  - {stage: 7, status: done, agent: e2e-runner+implementer(XCUITest), model: opus, reason: "Simulator.app と UI 操作手段が無いため Xcode 標準の XCUITest で自動化(ユーザー決定)"}
  - {stage: 8, status: done, agent: reality-checker}
  - {stage: 9, status: done}
  - {stage: 10, status: done}
adversarial:
  findings: 23
  rejected: 5
---

# régu(クリップボード文字変換アプリ)の新規作成

## 要求事項

réguという iPhone アプリを SwiftUI で作る。上にペースト用の大きなテキストエリア、その下に変換ボタンとプリセット選択(既定 3 つ＋ユーザー作成のセット)、
下に読み取り専用・選択可の変換結果エリア。前面に来たときクリップボードが空でなければ読み込み、前回のプリセットで変換し、結果を全選択表示してクリップボードにもコピーする。
変換ルールは `references/文字変換ルール 2018年11月.numbers`。iPad / iPhone 両対応、将来 macOS 版を作れる構造。

## 対応スコープ

- 対象: 変換エンジン(10 項目・既定 3 プリセット)、ユーザープリセットの作成・編集・複製・削除、メイン画面と設定画面、前面化時の自動変換、
  iOS アプリ(iPhone / iPad)、Xcode プロジェクト(手書き pbxproj)、単体テスト 68 件、UI テスト(E2E 10 項目)
- 対象外: macOS アプリターゲット本体(構造と macOS 向けの部品だけ用意。要求は「将来」)、履歴・共有・ウィジェット(要求に無い)

## 参照した仕様

- 関連仕様書なし(単体プランで対応)。変換仕様の正: `references/文字変換ルール 2018年11月.numbers`(設定項目・プリセットの 2 シート)
- 設計: `.claude/hataraku/progress/c01-design.md`(作業用・コミットしない)、テスト観点 `c01-tests.md`、E2E 計画 `c01-e2e-plan.md`

## 環境の前提(段 0 の前)

| 確認したもの | 結果 |
|---|---|
| Xcode | 27.1 あり |
| XcodeGen | /usr/local の Intel 版のみで起動不可(Rosetta 無し)。ユーザー判断で使わない |
| Simulator.app・UI 操作手段 | 無し → XCUITest で代替 |
| 署名設定 | Config/Signing.local.xcconfig(gitignore)に ecritu と同じチームの値をメインが写した(値はレポートに書かない) |
| シミュレータ | ecritu のテストと共用すると UI テストが停止 → régu 専用機(regu-iPhone / regu-iPad, iOS 26.5)を simctl create で作成 |

## 実装概要

- `Packages/ReguKit`(ローカル Swift Package, iOS 18 / macOS 15)に 2 モジュール
  - ReguCore(Foundation + Observation のみ): 変換設定・変換パイプライン・プリセット・保存・クリップボード状態(ConversionSession)
  - ReguUI(SwiftUI): 画面。プラットフォーム差分は結果欄(UITextView / NSTextView)とクリップボード(UIPasteboard / NSPasteboard)
- `App/`: iOS アプリの入口(ReguApp)。前面化の種類(launch / background / inactive)を判定して ConversionSession へ渡す
- macOS 版で差し替えが要るのは 3 点(結果欄・クリップボード・前面化の検知)。ReguCore はそのまま使える

## 主要な実装の詳細

### 変換パイプライン

- 変更ファイル: `Sources/ReguCore/Converter.swift` ほか KanaConversion / UnitConversion / EntityConversion / HTMLEntityTable
- 何をしたか: URL decode → HTML decode → accent → unit → alphabet → symbol → space → katakana 全角化 → hiragana → katakana 半角化 → guillemets → HTML encode → URL encode の順で適用
- **なぜそうしたか**: decode を先・encode を最後にし、katakana を 2 段に分けて「ひらがな→カタカナ→半角」「半角→全角→ひらがな」を 1 回で成立させるため。
  unit を alphabet より前に置き、組文字の展開結果も全角化の対象にした

### numbers に無い細部の解釈(ユーザー確認済み・既定案)

- 全角数字は alphabet に含める。symbol の「CP932(〜0x7f)」は ￥↔\ ・ ￣↔~ を追加する意味と解釈
- NFC / NFD は全体に適用するが CJK 互換漢字を含む書記素は除外(人名の異体字を守る)
- unit は SI 単位の組文字だけを明示列挙。SI → 組文字は数字の直後のみで、後ろに ASCII 英字が続くときは変換しない(かな・漢字が続く「10mmの」は変換する)
- HTML は数値参照＋HTML4 名前付き＋&apos; を復号、符号化は 5 文字のみ。URL 符号化は非 ASCII のみ(ユーザー決定)
- ruby héritée の hiragana は numbers の preserve から hiraganaToKatakana に変更(ユーザー指示)。régularisation の「」→『』は numbers どおり(ユーザー確認)

### 自動変換と「自分の出力を再変換しない」

- 変更ファイル: `Sources/ReguCore/ConversionSession.swift`、`App/ReguApp.swift`
- 何をしたか: 自動変換は起動時と background からの復帰だけ(inactive 復帰では行わない)。最後に書いた changeCount と読もうとした changeCount を UserDefaults に保存。
  加えて「変換設定 + 出力」の FNV-1a 64 指紋を保存し、changeCount が変わっていても指紋が一致すれば自分の出力として変換しない
- **なぜそうしたか**: UI テスト E6 で、クリップボードを読まずに起動して手で変換した後に前面化すると、自分の出力を再変換する不具合を検出した。
  iOS で書き込み直後の changeCount が古い値のことがあると推測。指紋に設定を含めるのはユーザーの指摘による(設定を変えた後は同じ文字列でも変換する)。
  文字列そのものは保存しない。さらに、書き込み直後の記録値が古いままだと「変換→プリセット切替→背面→復帰」で再変換するため(段 5 再レビューの指摘)、
  前面中に書き込んだときは背面へ移る時点で changeCount を読み直して記録し直す(`enterBackground`。中身は読まないのでアラートは出ない)

### プリセット名の折り返し

- 変更ファイル: `Sources/ReguUI/MainView.swift`
- 何をしたか: Picker に `.lineLimit(1).layoutPriority(1)`
- **なぜそうしたか**: 最初の E2E 撮影で iPhone 縦表示の「régularisation」が 2 行に折り返していた

### iPad の複数ウィンドウ無効

- 変更ファイル: `App/Info.plist`、pbxproj
- 何をしたか: シーンマニフェストの自動生成を止め、Info.plist に UIApplicationSupportsMultipleScenes = false を明記
- **なぜそうしたか**: INFOPLIST_KEY で NO を指定しても、Xcode 27.1 の自動生成では true になった

### Xcode プロジェクト

- 変更ファイル: `regu.xcodeproj/**`、`Config/Edition.xcconfig`、`Config/Signing.local.xcconfig.example`
- 何をしたか: pbxproj を手書きし正本とする(project.yml は置かない)。識別子はプレースホルダー、実値は gitignore の Signing.local.xcconfig
- **なぜそうしたか**: ユーザーの方針「余分なツールは使わない」。ecritu は Team ID をコミットしているが、régu ではコミットしない

### UI テスト

- 変更ファイル: `reguUITests/ReguE2EUITests.swift`、ReguUI の accessibilityIdentifier、`App/ReguApp.swift`(DEBUG 限定の `-reguUITestReset`)
- **なぜそうしたか**: この Mac には Simulator.app も UI 操作手段も無く、追加ツールは入れない方針のため

## 検証結果

| 段 | 内容 | 結果 |
|---|---|---|
| 6 UT/FT | `swift test`(Packages/ReguKit) | 68 件全緑 |
| 6 テストを読んだ(test-reviewer) | 1 回目: 高 1・中 1・低 1 → すべて直した。2 回目(UI テスト・T11/T12): 高 2(E9 の空振り・E5 のスワイプ判定)・中 4・低 3 → 高と中の大半を直した。E5 のスワイプ判定は XCUITest で判定不能のため外した | 直す → 直して通す |
| 6 赤を先に見た(worker + メイン) | 実装に 10 種の変異 → 8 種で赤。見逃し 2 種(既定削除時の選択・数字なし単位)はテスト追加後に赤を確認。E6 修正の指紋判定・設定の指紋・背面での記録し直しを外すと T11 / T12 / T13 が赤 | |
| 7 E2E | XCUITest。iPhone 17 Pro Max / iPad Pro 13-inch (M5)、iOS 26.5 の専用機。前提ゲート(起動・描画・クラッシュ無し)合格。判定はメインが結果バンドルと添付を確認 | PASS 10(E10 追加)/ 手順変更あり 1(E5: スワイプ削除の確認を外した)/ FAIL 0 / 未実施 0。修正前のコードでは E6 が FAIL(不具合を検出)。全選択は目視、E8 の複数ウィンドウ不可は Info.plist の確認のみ |
| 8 実装実態検査 | reality-checker。乖離: 実装 1(siToLigature の後続判定が かな・漢字 でも「英字」扱い → ASCII 英字に修正、テスト追加)・設計書の更新漏れ 2(μ の U+00B5、project.yml なし → 追補)・レポート 2(ビルド前スクリプトの記述、段 8 の記入)→ すべて処置 | 乖離あり → 処置済み |

ビルド: `xcodebuild ... CODE_SIGNING_ALLOWED=NO build` を iPhone / iPad で成功。`swift build`(macOS)成功(macOS の画面表示は未確認)。

## 敵対的検証の結果(段 3)

| # | 指摘 | 対処 |
|---|---|---|
| 1 | 半角カナ記号 ｡｢｣､･ の変換経路が無い | 設計修正(katakana の往復対象に追加) |
| 2 | iPad 複数ウィンドウで再変換の判定が崩れる | 設計修正(複数ウィンドウ無効、セッションは 1 個) |
| 3 | inactive 復帰・拒否時に再プロンプトのループ | 設計修正(launch / background のみ、試行した changeCount を記録) |
| 4 | HTML4 に &apos; が無い | 設計修正(&apos; を追加) |
| 5 | NFC / NFD の範囲が狭すぎる | 設計修正(全体適用＋互換漢字除外) |
| 6 | unit 表に非 SI が混じる・範囲外がある | 設計修正(明示列挙) |
| 7 | パイプライン順で unit と alphabet が噛み合わない | 設計修正(unit を前へ) |
| 8 | 変換ボタンの空入力でクリップボードを潰す | 設計修正(何もしない) |
| 9 | changeCount を永続化しないと再起動で再変換 | 設計修正(UserDefaults に保存) |
| 10 | 全選択が未表示のビューで失敗する | 設計修正(トークン保持と再試行) |
| 11 | 保存データの一部破損で全消失 | 設計修正(要素単位で読む) |
| 12 | CP932 と JIS の写像差(〜 等) | 却下(「〜0x7f」は 1 バイト域と解釈) |
| 13 | ヷ ヺ ゔ 等の X 0213 文字を生成する | 却下(通常のカタカナとして扱う) |
| 14 | Adresse héritée の半角化が他と逆向き | 却下(numbers どおり) |
| 15 | Universal Clipboard で読み取りが待つ | 却下(既知の制約として記載) |
| 16 | 要求に無い既定の挙動 | 却下(下の申し送りに明記) |
| 他 | 低(URL decode の塊・HTML 境界・表示名・macOS の差分点数など)7 件 | 設計修正・テスト追加 |

## 省略した段とその理由

- 省略なし。段 7 は当初の手動操作での E2E が環境(UI 操作手段なし)で 8 項目未実施となり、XCUITest で実施し直した

## 残課題 / 要確認 / 申し送り

- 要求に無い既定の挙動(ユーザーに明示): 設定(歯車)ボタン、既定プリセットからの複製、変換ボタンでもクリップボードへコピー、プリセット変更だけでは再変換しない、空白だけの名前は保存しない
- 既知の制約: 同じ設定のまま自分の出力と同じ文字列を他アプリからコピーした場合は変換しない／端末再起動で changeCount が戻り偶然一致すると 1 回だけ自動変換しない(指紋で大半は救われる)／
  Universal Clipboard の内容は読み取りに時間がかかることがある／入力中に変換ボタンを押すとキーボードが閉じる(結果欄が全選択のためフォーカスを取る)
- macOS 版: ReguUI の NSTextView 版・NSPasteboard 版はビルドのみで表示・動作未確認。macOS ターゲット追加時に確認する
- 細部の追加(設計に追補済み): SI → 組文字で μ はマイクロ記号 U+00B5 も受け付ける
- ビルド前スクリプト(括弧の空行検査)は `git ls-files` の対象だけを見るため、git 管理外や未追跡の間は何も検査せずに通る(ecritu と同じ)。今サイクルは未追跡だったので、同じ規則を手で全 Swift ファイルにかけて違反 0 を確認した
- シミュレータ名は README の例(OS=26.5)を環境に合わせて変える必要がある

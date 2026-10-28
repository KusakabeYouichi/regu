# régu

クリップボードの文字列を、選んだプリセットの規則で変換する iPhone / iPad アプリ。

- 前面に来るたび（起動時と、バックグラウンドからの復帰時）に、クリップボードに文字列があれば入力欄へ読み込み、
  前回選んだプリセットで変換し、結果を全選択して表示し、結果をクリップボードへ書き戻す
- 自分が書き戻した内容は再び変換しない
- 変換規則は英数字・アクセント・空白・カナ・ひらがな・記号・鉤括弧・単位・HTML / URL エンティティの 10 項目。
  既定のプリセット 3 つ（régularisation / Adresse héritée / ruby héritée）に加えて、名前付きのプリセットを作れる

## 構成

- `App/` iOS アプリの入口（`ReguApp.swift`、アセット、プライバシーマニフェスト）
- `Packages/ReguKit/` ローカル Swift Package
  - `ReguCore` 変換エンジン・プリセット・保存・画面の状態（Foundation のみ）
  - `ReguUI` SwiftUI の画面（iOS / macOS の差分は結果欄とクリップボードに閉じる）
- `regu.xcodeproj` プロジェクト。`project.pbxproj` が正本で、直接編集する（生成ツールは使わない）

## セットアップ

署名の識別子はリポジトリに入れない。雛形を写して自分の値を書く。

```sh
cp Config/Signing.local.xcconfig.example Config/Signing.local.xcconfig
# REGU_DEVELOPMENT_TEAM と REGU_APP_BUNDLE_IDENTIFIER を書き換える
```

## テストとビルド

変換エンジンのテストは Mac 上で `swift test` で回す。

```sh
cd Packages/ReguKit
swift test
```

アプリのビルド（シミュレータ）:

```sh
xcodebuild -project regu.xcodeproj -scheme regu \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.5" \
  CODE_SIGNING_ALLOWED=NO build
```

名前だけで指定すると最新の iOS ランタイムから探すため、その機種が無いと失敗する。
使えるシミュレータは `xcrun simctl list devices available` で確かめ、`name=` と `OS=` を手元の機種に合わせる。
最低 OS は iOS 18（パッケージは macOS 15 でもビルドできる）。

# App Store 提出用メタデータ(régu)

作成: 2026-10-30。説明文・プロモーションテキストには ㎏ などの組文字を書けない(ASC が拒否する。2026-10-31)。文字数は 2026-10-30 に確認済み。
ASC へは API で書き込む(値の正本はこのファイル)。

## 共通

- 価格: 最低価格(日本 ¥50、米国 $0.29、フランス €0.29。2026-10-30 に ASC の価格表で確認)
- カテゴリー: プライマリ ユーティリティ / セカンダリ 仕事効率化
- 著作権: © 2026 Kusakabe Youichi
- プライバシーポリシー: https://kusakabeyouichi.github.io/regu/privacy.html
- サポート URL: https://kusakabeyouichi.github.io/regu/
- お問い合わせ: régu@merope.pleiades.or.jp(サポートのページに載せる)
- 輸出コンプライアンス: ITSAppUsesNonExemptEncryption = NO(暗号化を一切使わない)
- 年齢レーティング: すべて「なし」で 4+
- App Privacy: 「データを収集しない」、トラッキングなし(ネットワーク通信のコードが無い。PrivacyInfo.xcprivacy も収集なし)

---

## 日本語(ja)

### アプリ名(30字以内)

régu

### サブタイトル(30字以内)

コピーした文字を、いつもの形にそろえる

### プロモーションテキスト(170字以内)

コピーして régu を開くだけ。全角の英数字、半角カナ、全角スペース、合成済みでないアクセント、1 文字にまとめた単位記号を、選んだプリセットの規則でそろえ、結果をそのままクリップボードへ戻します。通信は一切しません。

### キーワード(100字以内・半角カンマ区切り)

全角,半角,変換,クリップボード,コピペ,整形,カタカナ,ひらがな,住所,ふりがな,スペース,記号,単位,NFC,NFD,Unicode,HTML,URL,エンティティ

### 説明文(4000字以内)

régu(レギュ)は、コピーした文字列を、あらかじめ決めた規則で一度にそろえるアプリです。

使い方は、文字列をコピーして régu を開くだけ。régu は前面に来るたびにクリップボードを読み、選んでいるプリセットで変換し、結果をクリップボードへ書き戻します。あとは元のアプリに戻って貼り付けるだけです。結果は全選択された状態で表示されるので、確かめてからコピーし直すこともできます。régu 自身が書き戻した文字列を、もう一度変換することはありません。

■ 変換できる 10 項目
・英数字 — 全角 ⇄ 半角(ASCII)
・アクセント — 合成済み(NFC)⇄ 分解(NFD)
・空白 — 全角スペース ⇄ 半角スペース(1 個 / 2 個)
・カナ — 半角カナ ⇄ 全角カナ
・ひらがな — ひらがな ⇄ カタカナ、入れ替え
・記号 — 全角 ⇄ ASCII、Windows の文字コード(CP932)に合わせた変換
・鉤括弧 — 「」⇄『』
・単位 — kg や cm を 1 文字にまとめた組文字 ⇄ kg cm m² などの表記
・HTML エンティティ — &eacute; ⇄ é
・URL エンティティ — %C3%A9 ⇄ é

■ 3 つの既定のプリセット
・régularisation — 全角の英数字・記号を半角に、半角カナを全角に、全角スペースを半角に、アクセントを合成済みに。ふだん使いの整形に。
・Adresse héritée — 英数字・記号・スペースを全角に、カナを半角に。全角しか受け付けない古い入力欄の住所に。
・ruby héritée — ひらがなを半角カタカナに。半角カナのふりがな欄に。

■ 自分のプリセット
10 項目を組み合わせて、名前を付けたプリセットをいくつでも作れます。メイン画面のチップから、すぐに切り替えられます。

■ 通信しません
régu にはネットワーク通信を行なうコードがありません。クリップボードの内容が端末の外へ送られることはありません。解析・広告の SDK も使っていません。

iPhone と iPad に対応しています。

### What's New(初回)

初回リリースです。

---

## フランス語(fr-FR)

### Nom (30 caractères max.)

régu

### Sous-titre (30 caractères max.)

Normaliser le texte copié

### Texte promotionnel (170 caractères max.)

Copiez, ouvrez régu : pleine chasse, demi-chasse, espaces idéographiques, accents décomposés et unités sont normalisés, et le résultat revient au presse-papiers.

### Mots-clés (100 caractères max.)

japonais,pleine chasse,demi-chasse,presse-papiers,katakana,hiragana,Unicode,NFC,NFD,HTML,URL,entité

### Description (4000 caractères max.)

régu remet en ordre, en une seule fois, le texte que vous avez copié, selon des règles choisies à l’avance.

Copiez un texte, puis ouvrez régu. À chaque passage au premier plan, régu lit le presse-papiers, le convertit avec le préréglage sélectionné et y replace le résultat. Il ne reste qu’à revenir dans l’app d’origine et à coller. Le résultat s’affiche entièrement sélectionné : vous pouvez le vérifier avant de le copier à nouveau. régu ne reconvertit jamais le texte qu’il vient lui-même d’écrire.

■ 10 conversions
• Lettres et chiffres — pleine chasse ⇄ demi-chasse (ASCII)
• Accents — composés (NFC) ⇄ décomposés (NFD)
• Espaces — espace idéographique ⇄ espace (une ou deux)
• Kana — katakana demi-chasse ⇄ pleine chasse
• Hiragana — hiragana ⇄ katakana, ou permutation
• Symboles — pleine chasse ⇄ ASCII, ou selon le jeu de caractères Windows (CP932)
• Crochets japonais — 「」⇄『』
• Unités — symboles d’unités SI en un seul caractère ⇄ kg, cm, m², etc.
• Entités HTML — &eacute; ⇄ é
• Encodage URL — %C3%A9 ⇄ é

■ Trois préréglages fournis
• régularisation — lettres, chiffres et symboles en demi-chasse, kana en pleine chasse, espaces idéographiques en espaces, accents composés. Pour le nettoyage de tous les jours.
• Adresse héritée — lettres, chiffres, symboles et espaces en pleine chasse, kana en demi-chasse. Pour les anciens formulaires japonais qui n’acceptent que la pleine chasse.
• ruby héritée — hiragana en katakana demi-chasse. Pour les champs de lecture (furigana) en demi-chasse.

■ Vos propres préréglages
Combinez les 10 conversions et créez autant de préréglages nommés que vous le souhaitez. Changez-en d’un geste depuis l’écran principal.

■ Aucune connexion réseau
régu ne contient aucun code réseau. Le contenu du presse-papiers ne quitte jamais votre appareil. Aucun SDK d’analyse ni de publicité.

Pour iPhone et iPad.

### Nouveautés (première version)

Première version.

---

## 審査ノート(Notes for Review)

régu reads the clipboard each time it comes to the foreground, converts the text with the selected preset, and writes the result back to the clipboard. This is the app's core function, so iOS may show its "Allow Paste" prompt; please allow it. To try it: copy any text containing full-width letters (e.g. "ＡＢＣ１２３") in another app, then open régu — the result "ABC123" (preset régularisation) appears selected and is already on the clipboard. The app contains no networking code and collects no data. No account or sign-in is required.

(日本語訳)régu は前面に来るたびにクリップボードを読み、選んだプリセットで変換して書き戻します。これがアプリの中心機能なので、iOS の「ペーストを許可」が出ることがあります。試し方: 他のアプリで「ＡＢＣ１２３」のような全角の英数字を含む文字列をコピーして régu を開くと、「ABC123」(プリセット régularisation)が選択された状態で表示され、クリップボードにも入っています。通信のコードは無く、データも収集しません。アカウントは不要です。

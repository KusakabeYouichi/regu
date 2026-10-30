#!/usr/bin/env python3
# appstore/metadata.md から docs/store-preview/index.html を生成する(App Store 掲載の想定イメージ)。
# スクリーンショットは appstore/screenshots/{iphone,ipad}/*.png を docs/store-preview/ へコピーして参照する。
# 実行: python3 appstore/build-store-preview.py
import html
import os
import re
import shutil
import subprocess

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
md = open(f'{root}/appstore/metadata.md', encoding='utf-8').read()

def language_block(heading):
    m = re.search(r'\n## ' + re.escape(heading) + r'\n(.*?)(?=\n---\n|\Z)', md, re.S)
    return m.group(1)

def field(block, title):
    m = re.search(r'\n### ' + re.escape(title) + r'[^\n]*\n\n(.*?)(?=\n### |\Z)', block, re.S)
    return m.group(1).strip()

out = f'{root}/docs/store-preview'
os.makedirs(out, exist_ok=True)
shots = {}
for device in ('iphone', 'ipad'):
    src = f'{root}/appstore/screenshots/{device}'
    shots[device] = sorted(f for f in os.listdir(src) if f.endswith('.png'))
    for f in shots[device]:
        shutil.copy(f'{src}/{f}', f'{out}/{f}')
subprocess.run(['sips', '-Z', '240', f'{root}/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png', '--out', f'{out}/icon.png'],
               capture_output=True)

captions = {
    'ja': {'01': 'régularisation', '02': 'Adresse héritée', '03': 'ruby héritée', '04': 'プリセットの一覧', '05': 'プリセットの設定'},
    'fr': {'01': 'régularisation', '02': 'Adresse héritée', '03': 'ruby héritée', '04': 'Liste des préréglages', '05': 'Réglages d’un préréglage'},
}
labels = {
    'ja': {'iphone': 'iPhone', 'ipad': 'iPad', 'meta': 'カテゴリ: ユーティリティ · 年齢: 4+ · 対応: iPhone / iPad · 価格: ¥50',
           'kw': 'キーワード(検索用・ストアには表示されません)', 'new': '新機能'},
    'fr': {'iphone': 'iPhone', 'ipad': 'iPad', 'meta': 'Catégorie : Utilitaires · Âge : 4+ · iPhone / iPad · Prix : 0,29 €',
           'kw': 'Mots-clés (pour la recherche, non affichés)', 'new': 'Nouveautés'},
}

def description_html(text):
    parts = []
    for block in text.split('\n\n'):
        lines = block.split('\n')
        if lines[0].startswith('■ '):
            parts.append(f'<h3>{html.escape(lines[0][2:])}</h3>' + ''.join(f'<p>{html.escape(l)}</p>' for l in lines[1:]))
        else:
            parts.append(''.join(f'<p>{html.escape(l)}</p>' for l in lines))
    return ''.join(parts)

def gallery(lang, device):
    size = 'width="1320" height="2868"' if device == 'iphone' else 'width="2064" height="2752"'
    figures = ''.join(
        f'<figure class="{device}"><img src="{f}" alt="{html.escape(captions[lang][f[:2]])}" {size} loading="lazy">'
        f'<figcaption>{html.escape(captions[lang][f[:2]])}</figcaption></figure>'
        for f in shots[device])
    return f'<h3>{labels[lang][device]}</h3><div class="gallery">{figures}</div>'

def section(lang, heading, titles):
    block = language_block(heading)
    name, subtitle, promo, keywords, desc, news = (field(block, t) for t in titles)
    return f'''<section lang="{lang}">
  <div class="store-head">
    <img src="icon.png" alt="">
    <div>
      <h1>{html.escape(name)}</h1>
      <p class="sub">{html.escape(subtitle)}</p>
      <p class="meta">{html.escape(labels[lang]['meta'])}</p>
    </div>
  </div>
  {gallery(lang, 'iphone')}
  {gallery(lang, 'ipad')}
  <div class="promo">{html.escape(promo)}</div>
  <div class="desc">{description_html(desc)}</div>
  <h3>{html.escape(labels[lang]['new'])}</h3>
  <p>{html.escape(news)}</p>
  <h3>{html.escape(labels[lang]['kw'])}</h3>
  <p class="meta">{html.escape(keywords)}</p>
</section>'''

ja = section('ja', '日本語(ja)', ('アプリ名', 'サブタイトル', 'プロモーションテキスト', 'キーワード', '説明文', "What's New"))
fr = section('fr', 'フランス語(fr-FR)', ('Nom', 'Sous-titre', 'Texte promotionnel', 'Mots-clés', 'Description', 'Nouveautés'))
page = f'''<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>régu ストア掲載プレビュー</title>
<link rel="stylesheet" href="../site.css">
<style>
  .store-head {{ display: flex; gap: 20px; align-items: flex-start; margin: 1.5rem 0 1rem; }}
  .store-head img {{ width: 120px; height: 120px; border-radius: 27px; box-shadow: 0 2px 8px rgba(0, 0, 0, .12); flex: none; }}
  .store-head h1 {{ margin: 0; font-size: 1.9rem; line-height: 1.3; }}
  .store-head .sub {{ margin: .2rem 0 0; color: var(--muted); font-size: 1.05rem; }}
  .promo {{ border: 1px solid color-mix(in srgb, var(--fg) 15%, transparent); border-radius: 12px; padding: .9rem 1.1rem; margin: 1rem 0 1.5rem; }}
  .gallery {{ display: flex; gap: 12px; overflow-x: auto; padding: 4px 0 12px; scroll-snap-type: x mandatory; }}
  .gallery figure {{ flex: 0 0 auto; margin: 0; scroll-snap-align: start; }}
  .gallery figure.iphone {{ width: min(62vw, 240px); }}
  .gallery figure.ipad {{ width: min(80vw, 360px); }}
  .gallery img {{ width: 100%; height: auto; border-radius: 18px; border: 1px solid color-mix(in srgb, var(--fg) 15%, transparent); display: block; }}
  .gallery figcaption {{ font-size: .85rem; color: var(--muted); margin-top: .3rem; }}
  .desc h3 {{ margin: 1.3rem 0 .3rem; font-size: 1.05rem; }}
  .desc p {{ margin: .2rem 0; }}
  .meta {{ color: var(--muted); font-size: .9rem; }}
</style>
</head>
<body>
<header>régu</header>
<main>
  <p class="meta">App Store に載せる予定の文面と画像の確認用ページです(未公開)。文面は appstore/metadata.md から生成しています。</p>
  {ja}
  <hr>
  {fr}
</main>
</body>
</html>
'''
open(f'{out}/index.html', 'w', encoding='utf-8').write(page)
print('store-preview generated')

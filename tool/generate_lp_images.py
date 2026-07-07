# -*- coding: utf-8 -*-
"""LP用画像の一括生成スクリプト

assets/store/ のストア素材から public/ 配下のLP用画像を再生成する。
スクショや OGP 素材を差し替えたら、このスクリプトを再実行するだけでよい。

実行: python tool/generate_lp_images.py
依存: Pillow(pip install Pillow)

生成物:
  public/assets/img/screen-1..5.webp   ... phone_1..5.png を幅720pxに縮小+WebP化
  public/assets/img/ogp.png            ... feature_graphic.png を 1200x630 黒地に中央合成
  public/favicon.ico                   ... icon_512.png から 16/32/48 マルチサイズ
  public/assets/img/apple-touch-icon.png ... icon_512.png から 180x180
  public/assets/img/icon-192.png       ... web/icons/Icon-192.png のコピー
"""
import os
import shutil
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "store")
OUT = os.path.join(ROOT, "public", "assets", "img")
os.makedirs(OUT, exist_ok=True)


def report(path):
    print(f"{path}  {os.path.getsize(path) // 1024} KB")


# 1) スクリーンショット: 幅720px(表示幅~360pxのRetina 2x)に縮小して WebP 化
for i in range(1, 6):
    im = Image.open(os.path.join(SRC, f"phone_{i}.png")).convert("RGB")
    w, h = im.size
    nw = 720
    nh = round(h * nw / w)
    im = im.resize((nw, nh), Image.LANCZOS)
    dst = os.path.join(OUT, f"screen-{i}.webp")
    im.save(dst, "WEBP", quality=80, method=6)
    print(f"screen-{i}: {nw}x{nh}", end="  ")
    report(dst)

# 2) OGP 画像: 1200x630 黒キャンバスに feature_graphic(1024x500)を中央合成
fg = Image.open(os.path.join(SRC, "feature_graphic.png")).convert("RGB")
canvas = Image.new("RGB", (1200, 630), (0, 0, 0))
nh = round(fg.height * 1200 / fg.width)
fg = fg.resize((1200, nh), Image.LANCZOS)
canvas.paste(fg, (0, (630 - nh) // 2))
ogp = os.path.join(OUT, "ogp.png")
canvas.save(ogp, "PNG", optimize=True)
report(ogp)

# 3) favicon.ico(16/32/48)+ apple-touch-icon(180x180)
icon = Image.open(os.path.join(SRC, "icon_512.png")).convert("RGBA")
fav = os.path.join(ROOT, "public", "favicon.ico")
icon.save(fav, sizes=[(16, 16), (32, 32), (48, 48)])
report(fav)

ati = icon.resize((180, 180), Image.LANCZOS).convert("RGB")
ati_path = os.path.join(OUT, "apple-touch-icon.png")
ati.save(ati_path, "PNG", optimize=True)
report(ati_path)

# 4) icon-192.png のコピー
dst192 = os.path.join(OUT, "icon-192.png")
shutil.copyfile(os.path.join(ROOT, "web", "icons", "Icon-192.png"), dst192)
report(dst192)

print("done")

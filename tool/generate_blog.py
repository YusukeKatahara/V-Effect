# -*- coding: utf-8 -*-
"""LPブログの一括生成スクリプト

content/blog/*.md (frontmatter + Markdown) から public/blog/ 配下の
一覧ページ・記事詳細ページ・sitemap.xml を再生成する。
記事を追加/更新したら、このスクリプトを再実行するだけでよい。

実行: python tool/generate_blog.py
依存: markdown(pip install markdown), PyYAML(pip install PyYAML)

生成物:
  public/blog/index.html        ... 記事一覧
  public/blog/<slug>/index.html ... 記事詳細（1記事につき1ディレクトリ）
  public/sitemap.xml            ... 既存の固定URL + ブログURLで全文再生成

注意:
  ヘッダー/フッターの構成は public/index.html と手動で同期している。
  index.html のナビ構成を変えた場合は、下記 HEADER 定数も合わせて変更すること。
"""
import json
import os
import re
import markdown
import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT_DIR = os.path.join(ROOT, "content", "blog")
OUT_DIR = os.path.join(ROOT, "public", "blog")
SITEMAP_PATH = os.path.join(ROOT, "public", "sitemap.xml")
SITE_URL = "https://veffect.web.app"

# public/sitemap.xml のうちブログ以外の固定URL(現状の index.html / en / support / terms / privacy)
FIXED_SITEMAP_URLS = [
    {
        "loc": f"{SITE_URL}/",
        "hreflang": [
            ("ja", f"{SITE_URL}/"),
            ("en", f"{SITE_URL}/en/"),
            ("x-default", f"{SITE_URL}/"),
        ],
    },
    {
        "loc": f"{SITE_URL}/en/",
        "hreflang": [
            ("ja", f"{SITE_URL}/"),
            ("en", f"{SITE_URL}/en/"),
            ("x-default", f"{SITE_URL}/"),
        ],
    },
    {"loc": f"{SITE_URL}/support/"},
    {"loc": f"{SITE_URL}/terms/"},
    {"loc": f"{SITE_URL}/privacy/"},
]

HEADER = """    <header class="site-header">
        <div class="container">
            <a href="/" class="logo-text">V EFFECT</a>
            <nav class="header-nav">
                <a href="/#features" class="nav-anchor">機能</a>
                <a href="/#how" class="nav-anchor">使い方</a>
                <a href="/#download" class="nav-anchor">ダウンロード</a>
                <a href="/blog/" class="nav-anchor">ブログ</a>
                <a href="/en/" class="lang-switch" lang="en" hreflang="en">EN</a>
            </nav>
        </div>
    </header>"""

FOOTER = """    <footer class="site-footer">
        <div class="footer-links">
            <a href="/support">サポート</a>
            <a href="/terms">利用規約</a>
            <a href="/privacy">プライバシーポリシー</a>
            <a href="/en/" lang="en" hreflang="en">English</a>
        </div>
        <div class="copyright">
            &copy; 2026 V EFFECT.
        </div>
    </footer>"""

CTA_SECTION = """        <section class="cta" id="download">
            <div class="container">
                <h2>今日から、自分に勝つ。</h2>
                <p>ダウンロードは無料。最初のヒーロータスクを宣言しよう。</p>
                <div class="store-row">
                    <a href="https://apps.apple.com/jp/app/v-effect/id6763709764" class="store-button" target="_blank" rel="noopener noreferrer">
                        <svg class="store-icon" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                            <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.82M15.97 4.17c.66-.81 1.11-1.93.99-3.06-1 .04-2.22.67-2.94 1.51-.64.74-1.2 1.88-1.05 2.99 1.11.09 2.27-.58 3-1.44Z"/>
                        </svg>
                        <span>App Store からダウンロード</span>
                    </a>
                    <a href="https://veffect-app.web.app/" class="store-button store-button--web" target="_blank" rel="noopener noreferrer">
                        <svg class="store-icon" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                            <path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm7.93 9h-3.44a15.7 15.7 0 0 0-1.02-4.88A8.03 8.03 0 0 1 19.93 11ZM12 4.04c.83 1.2 1.86 3.36 2.24 6.96H9.76c.38-3.6 1.41-5.76 2.24-6.96ZM8.53 6.12A15.7 15.7 0 0 0 7.51 11H4.07a8.03 8.03 0 0 1 4.46-4.88ZM4.07 13h3.44c.14 1.83.51 3.46 1.02 4.88A8.03 8.03 0 0 1 4.07 13ZM12 19.96c-.83-1.2-1.86-3.36-2.24-6.96h4.48c-.38 3.6-1.41 5.76-2.24 6.96Zm3.47-2.08c.51-1.42.88-3.05 1.02-4.88h3.44a8.03 8.03 0 0 1-4.46 4.88Z"/>
                        </svg>
                        <span>ブラウザで使う</span>
                    </a>
                    <span class="store-chip">Google Play 近日公開</span>
                </div>
            </div>
        </section>
"""


def parse_post(path):
    """frontmatter(YAML) + Markdown本文 の .md ファイルを1件パースする"""
    with open(path, "r", encoding="utf-8") as f:
        raw = f.read()
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", raw, re.DOTALL)
    if not m:
        raise ValueError(f"frontmatterが見つかりません: {path}")
    meta = yaml.safe_load(m.group(1))
    meta["date"] = str(meta["date"])
    meta["updated"] = str(meta.get("updated", meta["date"]))
    meta["body_html"] = markdown.markdown(
        m.group(2).strip(), extensions=["extra", "sane_lists"]
    )
    return meta


def load_posts():
    files = sorted(f for f in os.listdir(CONTENT_DIR) if f.endswith(".md"))
    posts = [parse_post(os.path.join(CONTENT_DIR, f)) for f in files]
    posts.sort(key=lambda p: p["date"], reverse=True)
    return posts


def card_html(post):
    return f"""                <a class="blog-card" href="/blog/{post['slug']}/">
                    <p class="blog-card-cat">{post['category']}</p>
                    <h2 class="blog-card-title">{post['title']}</h2>
                    <p class="blog-card-desc">{post['description']}</p>
                    <p class="blog-card-date">{post['date']}</p>
                </a>
"""


def page_shell(title, description, canonical, body, og_type="website", extra_head=""):
    return f"""<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title}</title>
    <meta name="description" content="{description}">
    <meta name="theme-color" content="#000000">
    <link rel="canonical" href="{canonical}">

    <!-- OGP -->
    <meta property="og:site_name" content="V EFFECT">
    <meta property="og:title" content="{title}">
    <meta property="og:description" content="{description}">
    <meta property="og:type" content="{og_type}">
    <meta property="og:url" content="{canonical}">
    <meta property="og:image" content="{SITE_URL}/assets/img/ogp.png">
    <meta property="og:image:width" content="1200">
    <meta property="og:image:height" content="630">
    <meta property="og:locale" content="ja_JP">
    <meta name="twitter:card" content="summary_large_image">

    <!-- Icons -->
    <link rel="icon" href="/favicon.ico" sizes="48x48">
    <link rel="icon" type="image/png" sizes="192x192" href="/assets/img/icon-192.png">
    <link rel="apple-touch-icon" href="/assets/img/apple-touch-icon.png">

    <!-- Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&family=Noto+Sans+JP:wght@400;500;700&family=Outfit:wght@800;900&display=swap" rel="stylesheet">

    <link rel="stylesheet" href="/assets/css/lp.css">
{extra_head}</head>
<body>
{HEADER}

    <main>
{body}
    </main>

{FOOTER}

</body>
</html>
"""


def build_list_page(posts):
    cards = "".join(card_html(p) for p in posts)
    body = f"""        <section class="blog-hero">
            <div class="container">
                <p class="hero-eyebrow">BLOG</p>
                <h1>習慣化を続けるためのヒント集</h1>
                <p class="hero-sub">宣言・証明・仲間・勝敗という V EFFECT の考え方をベースに、行動科学の視点から習慣化のコツを紹介します。</p>
            </div>
        </section>

        <section class="blog-list">
            <div class="container">
                <div class="blog-grid">
{cards}                </div>
            </div>
        </section>
"""
    html = page_shell(
        title="ブログ｜V EFFECT — 習慣化を続けるためのヒント集",
        description="宣言・証明・仲間・勝敗の仕組みで習慣化する V EFFECT が、行動科学の視点から習慣化のコツを紹介するブログです。",
        canonical=f"{SITE_URL}/blog/",
        body=body,
    )
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, "index.html"), "w", encoding="utf-8") as f:
        f.write(html)


def build_post_page(post, all_posts):
    related = [p for p in all_posts if p["slug"] != post["slug"]][:3]
    related_html = "".join(card_html(p) for p in related)
    canonical = f"{SITE_URL}/blog/{post['slug']}/"

    json_ld = f"""    <script type="application/ld+json">
    {{
        "@context": "https://schema.org",
        "@type": "BlogPosting",
        "headline": {json.dumps(post['title'], ensure_ascii=False)},
        "description": {json.dumps(post['description'], ensure_ascii=False)},
        "datePublished": "{post['date']}",
        "dateModified": "{post['updated']}",
        "author": {{"@type": "Organization", "name": "V EFFECT"}},
        "publisher": {{"@type": "Organization", "name": "V EFFECT"}},
        "image": "{SITE_URL}/assets/img/ogp.png",
        "mainEntityOfPage": "{canonical}"
    }}
    </script>
"""

    body = f"""        <article class="blog-article">
            <div class="container blog-article-inner">
                <p class="blog-meta"><span class="blog-card-cat">{post['category']}</span><span class="blog-meta-date">{post['date']}</span></p>
                <h1>{post['title']}</h1>
                <div class="blog-body">
{post['body_html']}
                </div>
            </div>
        </article>

        <section class="blog-related">
            <div class="container">
                <div class="section-head">
                    <p class="section-eyebrow">RELATED</p>
                    <h2 class="section-title">関連記事</h2>
                </div>
                <div class="blog-grid">
{related_html}                </div>
            </div>
        </section>

{CTA_SECTION}"""

    html = page_shell(
        title=f"{post['title']}｜V EFFECT ブログ",
        description=post["description"],
        canonical=canonical,
        body=body,
        og_type="article",
        extra_head=json_ld,
    )
    post_dir = os.path.join(OUT_DIR, post["slug"])
    os.makedirs(post_dir, exist_ok=True)
    with open(os.path.join(post_dir, "index.html"), "w", encoding="utf-8") as f:
        f.write(html)


def build_sitemap(posts):
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"',
        '        xmlns:xhtml="http://www.w3.org/1999/xhtml">',
    ]
    for entry in FIXED_SITEMAP_URLS:
        lines.append("  <url>")
        lines.append(f"    <loc>{entry['loc']}</loc>")
        for hreflang, href in entry.get("hreflang", []):
            lines.append(f'    <xhtml:link rel="alternate" hreflang="{hreflang}" href="{href}"/>')
        lines.append("  </url>")

    lines.append("  <url>")
    lines.append(f"    <loc>{SITE_URL}/blog/</loc>")
    lines.append("  </url>")

    for p in posts:
        lines.append("  <url>")
        lines.append(f"    <loc>{SITE_URL}/blog/{p['slug']}/</loc>")
        lines.append(f"    <lastmod>{p['updated']}</lastmod>")
        lines.append("  </url>")

    lines.append("</urlset>")
    with open(SITEMAP_PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def main():
    posts = load_posts()
    build_list_page(posts)
    for p in posts:
        build_post_page(p, posts)
    build_sitemap(posts)
    print(f"{len(posts)} 記事を生成しました:")
    for p in posts:
        print(f"  /blog/{p['slug']}/  ({p['date']})  {p['title']}")
    print("public/blog/index.html")
    print("public/sitemap.xml")


if __name__ == "__main__":
    main()

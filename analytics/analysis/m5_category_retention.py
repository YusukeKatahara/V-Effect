import datetime
import os
import sys
from collections import Counter

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from analysis.utils import days_since, load_latest_json, save_csv, save_figure

import pandas as pd
import plotly.express as px

TODAY = datetime.date.today()

# ========================================================================
# Claude による手動タスク分類辞書（全59種 + postsユニーク分を網羅）
# リリース後30日・開発者友人ユーザーのデータから精査
# ========================================================================
TASK_CATEGORY_MAP: dict[str, str] = {
    # ---- Fitness（フィットネス）----
    "筋トレ":                        "Fitness",
    "筋トレ / Work Out":             "Fitness",
    "筋トレ🏋️‍♀️":                   "Fitness",
    "ランニング":                     "Fitness",
    "RUN":                          "Fitness",
    "ストレッチ":                    "Fitness",
    "軽いストレッチ":                "Fitness",
    "縄跳び":                        "Fitness",
    "ジム":                          "Fitness",
    "gym work":                     "Fitness",
    "Work Out":                     "Fitness",
    "ウォーキング":                  "Fitness",
    "お散歩":                        "Fitness",
    "脚痩せ":                        "Fitness",
    "腹筋":                          "Fitness",
    "オフシーズン":                  "Fitness",   # スポーツ競技のオフシーズン練習
    "オンシーズン":                  "Fitness",
    "リカバリー（レスト）":          "Fitness",
    "練習":                          "Fitness",   # スポーツ練習（コンテキストから判断）
    # ---- Education（学習・研究・キャリア）----
    "勉強":                          "Education",
    "勉強📚":                        "Education",
    "基本情報技術者試験":            "Education",
    "英語学習":                      "Education",
    "Translation":                  "Education",
    "読書":                          "Education",
    "読書📚":                        "Education",
    "本を読む":                      "Education",
    "読書、勉強":                    "Education",
    "研究":                          "Education",
    "研究 / Study":                 "Education",
    "研究室に行く":                  "Education",
    "論文第1報":                     "Education",
    "Study":                        "Education",
    "就活":                          "Education",
    # ---- LifeRoutine（生活習慣・セルフケア）----
    "感謝を伝える(または記録する)":  "LifeRoutine",  # デフォルト提供タスクだが習慣として計上
    "早起き":                        "LifeRoutine",
    "7時代起床":                     "LifeRoutine",
    "早起き(仕事)":                  "LifeRoutine",
    "昼ごはん":                      "LifeRoutine",
    "朝ごはん":                      "LifeRoutine",
    "朝ごはん食べる":                "LifeRoutine",
    "食事":                          "LifeRoutine",
    "水💧":                          "LifeRoutine",
    "水を飲む":                      "LifeRoutine",
    "コーヒー":                      "LifeRoutine",
    "Nutrition":                    "LifeRoutine",
    "寝る":                          "LifeRoutine",
    "リラックス":                    "LifeRoutine",
    "健康":                          "LifeRoutine",
    "太陽を浴びる":                  "LifeRoutine",
    "ボディケア":                    "LifeRoutine",
    "ケア":                          "LifeRoutine",
    "ダイエット🤰🏻":                "LifeRoutine",
    "自分磨き":                      "LifeRoutine",
    "誕生日":                        "LifeRoutine",
    # ---- Creative（創作・娯楽）----
    "play bass":                    "Creative",
    "音楽":                          "Creative",
    "one tear up per day":          "Creative",
    "ポケモン　レートプラス":        "Creative",
    "ポケモン":                      "Creative",
    "For Apple":                    "Creative",
    "practice":                     "Creative",   # 音楽練習と推定（play bass との関連）
    # ---- DevWork（開発・制作）----
    "V EFFECT Dev":                 "DevWork",
    "V EFFECT開発":                 "DevWork",
    "Make The World Better":        "DevWork",
    "V EFFECT":                     "DevWork",
    # ---- Onboarding（オンボーディング専用タスク）----
    "Welcome to V EFFECT":          "Onboarding",
    # ---- Other（未分類）----
    "yuj":                          "Other",
}

CATEGORIES = ["Fitness", "Education", "LifeRoutine", "Creative", "DevWork", "Onboarding", "Other"]


def classify_task(task_name: str) -> str:
    """タスク名をカテゴリに分類する。辞書未登録の場合はキーワードフォールバック。"""
    if not task_name:
        return "Other"

    direct = TASK_CATEGORY_MAP.get(task_name)
    if direct:
        return direct

    n = task_name.lower()
    if any(kw in n for kw in ["筋", "ラン", "run", "gym", "ジム", "walk",
                               "ストレッチ", "stretch", "ヨガ", "yoga", "泳", "swim",
                               "スクワット", "サイクル", "cycling", "散歩"]):
        return "Fitness"
    if any(kw in n for kw in ["勉強", "study", "読書", "read", "研究", "英語",
                               "試験", "exam", "translation", "翻訳", "就活",
                               "論文", "thesis", "資格", "toeic", "learn"]):
        return "Education"
    if any(kw in n for kw in ["起床", "早起き", "ごはん", "meal", "食", "diet",
                               "水", "water", "コーヒー", "coffee", "寝", "sleep",
                               "健康", "health", "ケア", "care", "感謝", "太陽", "sun",
                               "瞑想", "meditation"]):
        return "LifeRoutine"
    if any(kw in n for kw in ["music", "音楽", "bass", "guitar", "piano",
                               "ゲーム", "game", "ポケモン", "dance", "ダンス",
                               "art", "歌", "sing", "creative"]):
        return "Creative"
    return "Other"


def infer_primary_category(task_cats: list[str]) -> str:
    """カテゴリリストから主要カテゴリを決定する。
    Onboarding 以外のカテゴリがあれば、その最多を採用。"""
    if not task_cats:
        return "Other"
    real = [c for c in task_cats if c != "Onboarding"]
    if not real:
        return "Onboarding"
    return Counter(real).most_common(1)[0][0]


def _print(text: str) -> None:
    sys.stdout.buffer.write(text.encode("utf-8", errors="replace"))


def main():
    users = load_latest_json("users")
    posts = load_latest_json("posts")

    _print("[M5] ユーザー別タスクカテゴリを分類中（Claude手動分類辞書）...\n")
    user_rows = []
    for u in users:
        lpd = u.get("lastPostedDate")
        d = days_since(lpd, TODAY) if lpd else 999
        tasks = [
            t.get("title", "") if isinstance(t, dict) else str(t)
            for t in (u.get("tasks") or []) if t
        ]
        task_cats = [classify_task(t) for t in tasks if t]
        primary = infer_primary_category(task_cats)
        user_rows.append({
            "uid": u.get("uid"),
            "primary_category": primary,
            "streak": u.get("streak") or 0,
            "max_streak": u.get("maxStreak") or 0,
            "follower_count": len(u.get("followers") or []),
            "task_count": len(tasks),
            "days_since_last_post": d,
            "is_active_14d": int(d <= 14),
            "is_churned_30d": int(d >= 30),
        })

    df_users = pd.DataFrame(user_rows)
    _print(f"[M5] カテゴリ分布:\n{df_users['primary_category'].value_counts().to_string()}\n")

    # カテゴリ別ユーザー特性
    cat_stats = (
        df_users.groupby("primary_category")
        .agg(
            user_count=("uid", "count"),
            median_streak=("streak", "median"),
            mean_streak=("streak", "mean"),
            median_max_streak=("max_streak", "median"),
            active_rate_14d=("is_active_14d", "mean"),
            churn_rate_30d=("is_churned_30d", "mean"),
            median_followers=("follower_count", "median"),
            median_task_count=("task_count", "median"),
        )
        .round(2)
        .reset_index()
    )
    cat_stats["active_pct"] = (cat_stats["active_rate_14d"] * 100).round(1)
    cat_stats["churn_pct"] = (cat_stats["churn_rate_30d"] * 100).round(1)

    _print("\n[M5] カテゴリ別ユーザー特性:\n")
    _print(cat_stats[[
        "primary_category", "user_count", "active_pct", "churn_pct",
        "median_streak", "median_max_streak",
    ]].to_string(index=False) + "\n")

    # ストリーク箱ひげ図
    fig_box = px.box(
        df_users, x="primary_category", y="streak",
        title="タスクカテゴリ別 現在ストリーク分布",
        labels={"primary_category": "主要タスクカテゴリ", "streak": "現在ストリーク"},
        color="primary_category",
        category_orders={"primary_category": CATEGORIES},
    )
    fig_box.update_layout(showlegend=False)
    save_figure(fig_box, "m5_category_streak_boxplot")

    # アクティブ率・チャーン率棒グラフ
    cat_melt = cat_stats.melt(
        id_vars="primary_category",
        value_vars=["active_pct", "churn_pct"],
        var_name="指標",
        value_name="率 (%)",
    )
    cat_melt["指標"] = cat_melt["指標"].map({
        "active_pct": "アクティブ率(14日)",
        "churn_pct": "チャーン率(30日)",
    })
    fig_ac = px.bar(
        cat_melt, x="primary_category", y="率 (%)", color="指標", barmode="group",
        title="カテゴリ別 アクティブ率 / チャーン率",
        color_discrete_map={"アクティブ率(14日)": "steelblue", "チャーン率(30日)": "tomato"},
        category_orders={"primary_category": CATEGORIES},
    )
    save_figure(fig_ac, "m5_category_active_churn")

    # 投稿エンゲージメント（postsからカテゴリ分類）
    _print("\n[M5] 投稿のタスクカテゴリを分類中...\n")
    post_rows = []
    for p in posts:
        tn = p.get("taskName", "")
        cat = classify_task(tn)
        post_rows.append({
            "post_id": p.get("post_id"),
            "category": cat,
            "reaction_count": p.get("reactionCount") or 0,
            "emoji_count": len(p.get("emojiReactedUserIds") or []),
        })

    df_posts = pd.DataFrame(post_rows)
    eng_stats = (
        df_posts.groupby("category")
        .agg(
            post_count=("post_id", "count"),
            mean_reaction=("reaction_count", "mean"),
            mean_emoji=("emoji_count", "mean"),
            reaction_rate=("reaction_count", lambda x: (x > 0).mean()),
        )
        .round(2)
        .reset_index()
    )
    _print("\n[M5] カテゴリ別投稿エンゲージメント:\n")
    _print(eng_stats.to_string(index=False) + "\n")

    # 4象限マトリクス（アクティブ率 × 平均リアクション数）
    matrix_df = cat_stats[["primary_category", "active_pct", "user_count"]].merge(
        eng_stats[["category", "mean_reaction", "post_count"]],
        left_on="primary_category", right_on="category",
        how="left",
    ).fillna(0)
    fig_matrix = px.scatter(
        matrix_df, x="active_pct", y="mean_reaction",
        text="primary_category",
        size="user_count",
        size_max=40,
        title="タスクカテゴリ別: 継続率(X) × リアクション獲得力(Y)",
        labels={
            "active_pct": "アクティブ率 14日 (%)",
            "mean_reaction": "平均炎リアクション数/投稿",
        },
        color="mean_reaction",
        color_continuous_scale="RdYlGn",
    )
    fig_matrix.update_traces(textposition="top center")
    fig_matrix.add_vline(x=matrix_df["active_pct"].mean(), line_dash="dash", line_color="gray")
    fig_matrix.add_hline(y=matrix_df["mean_reaction"].mean(), line_dash="dash", line_color="gray")
    save_figure(fig_matrix, "m5_category_matrix")

    # エンゲージメント棒グラフ
    fig_eng = px.bar(
        eng_stats, x="category", y="mean_reaction",
        title="カテゴリ別 平均炎リアクション数",
        labels={"category": "カテゴリ", "mean_reaction": "平均炎リアクション"},
        color="mean_reaction",
        color_continuous_scale="Oranges",
    )
    save_figure(fig_eng, "m5_category_engagement")

    # CSV保存
    merged = cat_stats.merge(
        eng_stats, left_on="primary_category", right_on="category", how="left"
    )
    save_csv(merged, "m5_category_stats")


if __name__ == "__main__":
    main()

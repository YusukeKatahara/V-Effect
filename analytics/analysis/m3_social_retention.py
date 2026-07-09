import datetime
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from analysis.utils import days_since, load_latest_json, save_csv, save_figure

import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from scipy.stats import spearmanr

TODAY = datetime.date.today()

FOLLOWER_BINS = [
    (0, 0, "0人"),
    (1, 1, "1人"),
    (2, 4, "2〜4人"),
    (5, 9, "5〜9人"),
    (10, 19, "10〜19人"),
    (20, 999, "20人以上"),
]


def bin_label(count: int, bins) -> str:
    for lo, hi, label in bins:
        if lo <= count <= hi:
            return label
    return "20人以上"


def main():
    users = load_latest_json("users")
    rows = []
    for u in users:
        lpd = u.get("lastPostedDate")
        d = days_since(lpd, TODAY) if lpd else 999
        followers = list(u.get("followers") or [])
        following = list(u.get("following") or [])
        mutual = len(set(followers) & set(following))
        rows.append({
            "uid": u.get("uid"),
            "follower_count": len(followers),
            "following_count": len(following),
            "mutual_count": mutual,
            "streak": u.get("streak") or 0,
            "max_streak": u.get("maxStreak") or 0,
            "days_since_last_post": d,
            "is_active": int(d <= 14),
            "is_churned": int(d >= 30),
        })

    df = pd.DataFrame(rows)

    # フォロワー数ビン別アクティブ率
    def bin_active_rate(col, bins, order):
        df["_bin"] = df[col].apply(lambda x: bin_label(x, bins))
        stats = (
            df.groupby("_bin")
            .agg(active_rate=("is_active", "mean"), churn_rate=("is_churned", "mean"), count=("uid", "count"))
            .reindex(order).dropna()
            .reset_index()
        )
        stats["active_pct"] = stats["active_rate"] * 100
        stats["churn_pct"] = stats["churn_rate"] * 100
        return stats

    BIN_ORDER = [b[2] for b in FOLLOWER_BINS]

    fol_stats = bin_active_rate("follower_count", FOLLOWER_BINS, BIN_ORDER)
    fol_stats.rename(columns={"_bin": "bin"}, inplace=True)
    print("[M3] フォロワー数別アクティブ率:")
    print(fol_stats[["bin", "active_pct", "churn_pct", "count"]].to_string(index=False))

    fig_fol = px.bar(
        fol_stats, x="bin", y="active_pct",
        title="フォロワー数別 アクティブ率（直近14日以内に投稿）",
        labels={"bin": "フォロワー数", "active_pct": "アクティブ率 (%)"},
        text="active_pct",
        color="active_pct",
        color_continuous_scale="Greens",
        category_orders={"bin": BIN_ORDER},
    )
    fig_fol.update_traces(texttemplate="%{text:.1f}%")
    fig_fol.update_layout(showlegend=False)
    save_figure(fig_fol, "m3_follower_active_rate")

    ing_stats = bin_active_rate("following_count", FOLLOWER_BINS, BIN_ORDER)
    ing_stats.rename(columns={"_bin": "bin"}, inplace=True)
    fig_ing = px.bar(
        ing_stats, x="bin", y="active_pct",
        title="フォロー数別 アクティブ率",
        labels={"bin": "フォロー数", "active_pct": "アクティブ率 (%)"},
        text="active_pct",
        color="active_pct",
        color_continuous_scale="Blues",
        category_orders={"bin": BIN_ORDER},
    )
    fig_ing.update_traces(texttemplate="%{text:.1f}%")
    save_figure(fig_ing, "m3_following_active_rate")

    mut_stats = bin_active_rate("mutual_count", FOLLOWER_BINS, BIN_ORDER)
    mut_stats.rename(columns={"_bin": "bin"}, inplace=True)
    print("\n[M3] 相互フォロー数別アクティブ率:")
    print(mut_stats[["bin", "active_pct", "churn_pct", "count"]].to_string(index=False))
    fig_mut = px.bar(
        mut_stats, x="bin", y="active_pct",
        title="相互フォロー数別 アクティブ率",
        labels={"bin": "相互フォロー数", "active_pct": "アクティブ率 (%)"},
        text="active_pct",
        color="active_pct",
        color_continuous_scale="Purples",
        category_orders={"bin": BIN_ORDER},
    )
    fig_mut.update_traces(texttemplate="%{text:.1f}%")
    save_figure(fig_mut, "m3_mutual_active_rate")

    # Spearman 相関係数
    corr_rows = []
    for col in ("follower_count", "following_count", "mutual_count"):
        r, p = spearmanr(df[col], df["days_since_last_post"])
        print(f"[M3] Spearman相関 {col} vs days_since_last_post: r={r:.3f}, p={p:.4f}")
        corr_rows.append({"特徴量": col, "Spearman_r": round(r, 3), "p値": round(p, 4)})

    # フォロワー数1人刻みアクティブ率（閾値特定）
    threshold_rows = []
    for n in range(0, 21):
        sub = df[df["follower_count"] == n]
        if len(sub) >= 2:
            threshold_rows.append({"follower_n": n, "active_pct": sub["is_active"].mean() * 100, "count": len(sub)})
    df_thresh = pd.DataFrame(threshold_rows)
    if not df_thresh.empty:
        print("\n[M3] フォロワー数1人刻みアクティブ率:")
        print(df_thresh.to_string(index=False))

    # 散布図
    df_plot = df.copy()
    df_plot["チャーン状態"] = df_plot["is_churned"].map({1: "チャーン", 0: "アクティブ"})
    df_plot["follower_clip"] = df_plot["follower_count"].clip(upper=20)
    fig_sc = px.scatter(
        df_plot, x="follower_clip", y="streak",
        color="チャーン状態",
        size="max_streak",
        size_max=20,
        color_discrete_map={"チャーン": "red", "アクティブ": "steelblue"},
        title="フォロワー数 vs 現在ストリーク（バブルサイズ=maxStreak）",
        labels={"follower_clip": "フォロワー数（20人でクリップ）", "streak": "現在ストリーク"},
        opacity=0.7,
    )
    save_figure(fig_sc, "m3_social_streak_scatter")

    summary_df = pd.DataFrame(corr_rows)
    save_csv(summary_df, "m3_summary")


if __name__ == "__main__":
    main()

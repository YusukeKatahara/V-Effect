import datetime
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from analysis.utils import days_since, load_latest_json, save_csv, save_figure

import pandas as pd
import plotly.express as px
import plotly.graph_objects as go

TODAY = datetime.date.today()


def streak_gap_bin(gap: int) -> str:
    if gap == 0:
        return "0（損失なし）"
    elif gap <= 3:
        return "1〜3"
    elif gap <= 6:
        return "4〜6"
    elif gap <= 13:
        return "7〜13"
    elif gap <= 29:
        return "14〜29"
    else:
        return "30以上"


def max_streak_bin(ms: int) -> str:
    if ms <= 2:
        return "0〜2"
    elif ms <= 6:
        return "3〜6"
    elif ms <= 13:
        return "7〜13"
    elif ms <= 29:
        return "14〜29"
    else:
        return "30以上"


BIN_ORDER_GAP = ["0（損失なし）", "1〜3", "4〜6", "7〜13", "14〜29", "30以上"]
BIN_ORDER_MAX = ["0〜2", "3〜6", "7〜13", "14〜29", "30以上"]
SHIELD_ORDER = ["0（シールドなし）", "1〜2", "3以上"]


def main():
    users = load_latest_json("users")
    rows = []
    for u in users:
        lpd = u.get("lastPostedDate")
        if not lpd:
            continue
        d = days_since(lpd, TODAY)
        if d is None:
            continue
        streak = u.get("streak") or 0
        max_s = u.get("maxStreak") or 0
        gap = max(0, max_s - streak)
        sp = u.get("streakProtections") or 0
        rows.append({
            "uid": u.get("uid"),
            "streak": streak,
            "max_streak": max_s,
            "streak_gap": gap,
            "streak_protections": sp,
            "days_since_last_post": d,
            "is_churned": int(d >= 30),
            "is_active": int(d <= 14),
            "streak_gap_bin": streak_gap_bin(gap),
            "max_streak_bin": max_streak_bin(max_s),
            "shield_bin": "3以上" if sp >= 3 else ("1〜2" if sp >= 1 else "0（シールドなし）"),
        })

    df = pd.DataFrame(rows)
    print(f"[M2] 対象ユーザー: {len(df)}件  チャーン数: {df['is_churned'].sum()}件 ({df['is_churned'].mean()*100:.1f}%)")

    # ストリーク損失ビン別チャーン率
    gap_stats = (
        df.groupby("streak_gap_bin")
        .agg(churn_rate=("is_churned", "mean"), count=("is_churned", "count"))
        .reindex(BIN_ORDER_GAP).dropna()
        .reset_index()
    )
    gap_stats["churn_pct"] = gap_stats["churn_rate"] * 100
    print("\n[M2] ストリーク損失別チャーン率:")
    print(gap_stats[["streak_gap_bin", "churn_pct", "count"]].to_string(index=False))

    fig_gap = px.bar(
        gap_stats, x="streak_gap_bin", y="churn_pct",
        title="ストリーク損失量別 チャーン率（30日以上未投稿）",
        labels={"streak_gap_bin": "ストリーク損失（maxStreak - 現在）", "churn_pct": "チャーン率 (%)"},
        text="churn_pct",
        color="churn_pct",
        color_continuous_scale="Reds",
        category_orders={"streak_gap_bin": BIN_ORDER_GAP},
    )
    fig_gap.update_traces(texttemplate="%{text:.1f}%")
    fig_gap.update_layout(showlegend=False)
    save_figure(fig_gap, "m2_streak_gap_churn")

    # maxStreak ビン別チャーン率
    ms_stats = (
        df.groupby("max_streak_bin")
        .agg(churn_rate=("is_churned", "mean"), count=("is_churned", "count"))
        .reindex(BIN_ORDER_MAX).dropna()
        .reset_index()
    )
    ms_stats["churn_pct"] = ms_stats["churn_rate"] * 100
    print("\n[M2] maxStreak別チャーン率:")
    print(ms_stats[["max_streak_bin", "churn_pct", "count"]].to_string(index=False))
    fig_ms = px.bar(
        ms_stats, x="max_streak_bin", y="churn_pct",
        title="maxStreak別 チャーン率",
        labels={"max_streak_bin": "歴代最大ストリーク", "churn_pct": "チャーン率 (%)"},
        text="churn_pct",
        color="churn_pct",
        color_continuous_scale="Reds",
        category_orders={"max_streak_bin": BIN_ORDER_MAX},
    )
    fig_ms.update_traces(texttemplate="%{text:.1f}%")
    save_figure(fig_ms, "m2_max_streak_churn")

    # シールド保有別チャーン率
    sh_stats = (
        df.groupby("shield_bin")
        .agg(churn_rate=("is_churned", "mean"), count=("is_churned", "count"))
        .reindex(SHIELD_ORDER).dropna()
        .reset_index()
    )
    sh_stats["churn_pct"] = sh_stats["churn_rate"] * 100
    print("\n[M2] シールド保有別チャーン率:")
    print(sh_stats[["shield_bin", "churn_pct", "count"]].to_string(index=False))
    fig_sh = px.bar(
        sh_stats, x="shield_bin", y="churn_pct",
        title="シールド保有数別 チャーン率",
        labels={"shield_bin": "残シールド数", "churn_pct": "チャーン率 (%)"},
        text="churn_pct",
        color="churn_pct",
        color_continuous_scale="Blues_r",
        category_orders={"shield_bin": SHIELD_ORDER},
    )
    fig_sh.update_traces(texttemplate="%{text:.1f}%")
    save_figure(fig_sh, "m2_shield_effect")

    # 散布図
    df_plot = df.copy()
    df_plot["チャーン状態"] = df_plot["is_churned"].map({1: "チャーン（30日以上未投稿）", 0: "アクティブ"})
    fig_scatter = px.scatter(
        df_plot, x="max_streak", y="days_since_last_post",
        color="チャーン状態",
        color_discrete_map={"チャーン（30日以上未投稿）": "red", "アクティブ": "steelblue"},
        title="maxStreak vs 直近未投稿日数",
        labels={"max_streak": "歴代最大ストリーク", "days_since_last_post": "最終投稿からの日数"},
        opacity=0.7,
    )
    fig_scatter.add_hline(y=30, line_dash="dash", line_color="red", annotation_text="チャーン閾値（30日）")
    save_figure(fig_scatter, "m2_scatter")

    # CSV保存
    summary = pd.concat([
        gap_stats.assign(type="streak_gap_bin").rename(columns={"streak_gap_bin": "bin"}),
    ])
    save_csv(df[["uid", "streak", "max_streak", "streak_gap", "streak_protections",
                  "days_since_last_post", "is_churned", "is_active"]], "m2_summary")


if __name__ == "__main__":
    main()

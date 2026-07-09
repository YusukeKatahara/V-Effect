import datetime
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from analysis.utils import load_latest_json, save_csv, save_figure, ts_to_dt

import pandas as pd
import plotly.express as px
import plotly.graph_objects as go

TODAY = datetime.date.today()
RETENTION_DAYS = [1, 3, 7, 14, 30]
WINDOW = 1  # ±1日ウィンドウ


def build_user_post_dates(posts):
    user_post_dates = defaultdict(set)
    for p in posts:
        dt = ts_to_dt(p.get("createdAt"))
        uid = p.get("userId")
        if dt and uid:
            user_post_dates[uid].add(dt.date())
    return user_post_dates


def get_activation_dates(user_post_dates):
    return {uid: min(dates) for uid, dates in user_post_dates.items() if dates}


def is_retained(post_dates: set, activation: datetime.date, n_days: int) -> bool:
    target = activation + datetime.timedelta(days=n_days)
    for d in range(-WINDOW, WINDOW + 1):
        if target + datetime.timedelta(days=d) in post_dates:
            return True
    return False


def main():
    posts = load_latest_json("posts")
    user_post_dates = build_user_post_dates(posts)
    user_activation = get_activation_dates(user_post_dates)

    print(f"[M1] 投稿実績あるユーザー数: {len(user_activation)}")

    # コホート（月）別リテンション
    cohort_data = defaultdict(list)
    for uid, act_date in user_activation.items():
        cohort_key = act_date.strftime("%Y-%m")
        cohort_data[cohort_key].append((uid, act_date))

    rows = []
    for cohort, members in sorted(cohort_data.items()):
        if len(members) < 3:
            print(f"[M1] コホート {cohort}: {len(members)}件 → スキップ（<3）")
            continue
        row = {"cohort": cohort, "n": len(members)}
        for d in RETENTION_DAYS:
            retained = [
                m for m in members
                if (TODAY - m[1]).days >= d and is_retained(user_post_dates[m[0]], m[1], d)
            ]
            eligible = [m for m in members if (TODAY - m[1]).days >= d]
            row[f"D{d}"] = len(retained) / len(eligible) if eligible else None
            row[f"D{d}_n"] = len(eligible)
        rows.append(row)

    df = pd.DataFrame(rows)
    print("[M1] コホート別リテンションテーブル:")
    print(df.to_string(index=False))
    save_csv(df, "m1_retention_table")

    # 全体平均リテンション曲線
    all_users = list(user_activation.items())
    curve_rows = []
    for d in RETENTION_DAYS:
        eligible = [(uid, act) for uid, act in all_users if (TODAY - act).days >= d]
        if not eligible:
            continue
        retained = sum(
            1 for uid, act in eligible
            if is_retained(user_post_dates[uid], act, d)
        )
        curve_rows.append({"day": d, "retention": retained / len(eligible), "n": len(eligible)})
    df_curve = pd.DataFrame(curve_rows)
    print("\n[M1] 全体平均リテンション曲線:")
    print(df_curve.to_string(index=False))

    # ヒートマップ
    if not df.empty:
        z_vals, text_vals, y_labels = [], [], []
        for _, row in df.iterrows():
            z_row, t_row = [], []
            for d in RETENTION_DAYS:
                v = row.get(f"D{d}")
                n = row.get(f"D{d}_n", 0)
                z_row.append(v if v is not None else 0)
                t_row.append(f"{v*100:.0f}%\n(n={int(n)})" if v is not None else "n/a")
            z_vals.append(z_row)
            text_vals.append(t_row)
            y_labels.append(f"{row['cohort']} (n={int(row['n'])})")

        fig_heat = go.Figure(go.Heatmap(
            z=z_vals,
            x=[f"D{d}" for d in RETENTION_DAYS],
            y=y_labels,
            text=text_vals,
            texttemplate="%{text}",
            colorscale="Blues",
            zmin=0, zmax=1,
        ))
        fig_heat.update_layout(title="コホート別リテンション率ヒートマップ", height=400)
        save_figure(fig_heat, "m1_cohort_retention_heatmap")

    # リテンション曲線
    if not df_curve.empty:
        df_curve["pct"] = df_curve["retention"] * 100
        fig_curve = px.line(
            df_curve, x="day", y="pct", markers=True,
            title=f"平均リテンション曲線（全ユーザー、n={len(all_users)}人）",
            labels={"day": "初回投稿からの日数", "pct": "リテンション率 (%)"},
        )
        fig_curve.update_traces(line_color="#4c72b0")
        fig_curve.add_hline(y=20, line_dash="dash", line_color="green",
                             annotation_text="業界優秀水準 D30=20%")
        fig_curve.add_hline(y=10, line_dash="dash", line_color="orange",
                             annotation_text="業界平均 D30=10%")
        save_figure(fig_curve, "m1_retention_curve")

    # D30サマリー
    if curve_rows:
        d30 = next((r for r in curve_rows if r["day"] == 30), None)
        if d30:
            print(f"\n[M1] D30 リテンション率: {d30['retention']*100:.1f}% (n={d30['n']})")


if __name__ == "__main__":
    main()

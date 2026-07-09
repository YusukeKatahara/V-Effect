import datetime
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from analysis.utils import load_latest_json, save_csv, save_figure, to_jst, ts_to_dt

import pandas as pd
import plotly.express as px
import plotly.graph_objects as go

SESSION_GAP_MIN = 30


def assign_sessions(uid_logs: list[dict]) -> list[dict]:
    if not uid_logs:
        return []
    sorted_logs = sorted(uid_logs, key=lambda l: ts_to_dt(l.get("clientTimestamp")) or datetime.datetime.min)
    session_id = 0
    prev_dt = None
    result = []
    for log in sorted_logs:
        dt = ts_to_dt(log.get("clientTimestamp"))
        if dt is None:
            continue
        if prev_dt and (dt - prev_dt).total_seconds() > SESSION_GAP_MIN * 60:
            session_id += 1
        result.append({**log, "_session_id": session_id, "_dt": dt})
        prev_dt = dt
    return result


def main():
    logs = load_latest_json("action_logs")

    # セッション分割
    uid_logs = defaultdict(list)
    for l in logs:
        uid = l.get("uid")
        if uid:
            uid_logs[uid].append(l)

    all_sessions = []
    for uid, ulogs in uid_logs.items():
        for entry in assign_sessions(ulogs):
            entry["uid"] = uid
            all_sessions.append(entry)

    df = pd.DataFrame(all_sessions)
    if df.empty:
        print("[M8] ログデータなし")
        return

    print(f"[M8] 総セッション数: {df['_session_id'].nunique()}")
    print(f"[M8] イベント種類: {df['eventName'].value_counts().to_string()}")

    # ファネル A: ソーシャルエンゲージメント
    funnel_a_steps = ["friend_feed_viewed", "reaction_sent", "friend_request_sent"]
    funnel_a_steps_exist = [s for s in funnel_a_steps if s in df["eventName"].values]
    funnel_a_rows = []
    total_users = df["uid"].nunique()
    for step in funnel_a_steps_exist:
        users_at_step = df[df["eventName"] == step]["uid"].nunique()
        funnel_a_rows.append({
            "ステップ": step,
            "ユーザー数": users_at_step,
            "通過率(%)": round(users_at_step / total_users * 100, 1),
        })
    df_funnel_a = pd.DataFrame(funnel_a_rows)
    print(f"\n[M8] ファネルA（ソーシャルエンゲージメント）:")
    print(df_funnel_a.to_string(index=False))

    fig_fa = go.Figure(go.Funnel(
        y=df_funnel_a["ステップ"],
        x=df_funnel_a["ユーザー数"],
        textinfo="value+percent initial",
    ))
    fig_fa.update_layout(title="ソーシャルエンゲージメントファネル")
    save_figure(fig_fa, "m8_funnel_social")

    # ファネル B: 投稿完了
    funnel_b_steps = ["app_open", "post_created"]
    funnel_b_rows = []
    for step in funnel_b_steps:
        if step in df["eventName"].values:
            n = df[df["eventName"] == step]["uid"].nunique()
            funnel_b_rows.append({"ステップ": step, "ユーザー数": n,
                                   "通過率(%)": round(n / total_users * 100, 1)})
    df_funnel_b = pd.DataFrame(funnel_b_rows)
    print(f"\n[M8] ファネルB（投稿完了）:")
    print(df_funnel_b.to_string(index=False))

    fig_fb = go.Figure(go.Funnel(
        y=df_funnel_b["ステップ"],
        x=df_funnel_b["ユーザー数"],
        textinfo="value+percent initial",
    ))
    fig_fb.update_layout(title="投稿完了ファネル")
    save_figure(fig_fb, "m8_funnel_post")

    # イベント遷移マトリクス
    event_types = sorted(df["eventName"].dropna().unique())
    transition_counts = defaultdict(int)
    for uid in df["uid"].unique():
        user_df = df[df["uid"] == uid].sort_values("_dt")
        events = user_df["eventName"].dropna().tolist()
        sessions = user_df["_session_id"].tolist()
        for i in range(len(events) - 1):
            if sessions[i] == sessions[i + 1]:
                transition_counts[(events[i], events[i + 1])] += 1

    matrix = pd.DataFrame(0, index=event_types, columns=event_types)
    for (a, b), cnt in transition_counts.items():
        if a in matrix.index and b in matrix.columns:
            matrix.loc[a, b] = cnt

    fig_trans = px.imshow(
        matrix,
        title="イベント遷移マトリクス（同一セッション内の連続イベント頻度）",
        labels=dict(x="次のイベント", y="前のイベント", color="遷移回数"),
        color_continuous_scale="Blues",
        text_auto=True,
    )
    fig_trans.update_layout(height=500)
    save_figure(fig_trans, "m8_event_transition_heatmap")

    # 時間帯別活動分析（JST）
    df["hour_jst"] = df["_dt"].apply(
        lambda dt: to_jst(dt).hour if dt else None
    )
    hourly = df.dropna(subset=["hour_jst"]).groupby("hour_jst").size().reset_index(name="イベント件数")
    print(f"\n[M8] 時間帯別アクティビティ（JST）:")
    print(hourly.to_string(index=False))
    peak_hour = hourly.loc[hourly["イベント件数"].idxmax(), "hour_jst"]
    print(f"[M8] 最多アクティビティ時間帯: {int(peak_hour)}時台")

    fig_hourly = px.bar(
        hourly, x="hour_jst", y="イベント件数",
        title="時間帯別 アクティビティ（JST）",
        labels={"hour_jst": "時間帯（JST）", "イベント件数": "イベント件数"},
        color="イベント件数",
        color_continuous_scale="Viridis",
    )
    fig_hourly.update_layout(xaxis=dict(tickmode="linear", dtick=1))
    save_figure(fig_hourly, "m8_hourly_activity")

    # CSV
    funnel_all = pd.concat([
        df_funnel_a.assign(funnel="A_social"),
        df_funnel_b.assign(funnel="B_post"),
    ])
    save_csv(funnel_all, "m8_funnel_stats")


if __name__ == "__main__":
    main()

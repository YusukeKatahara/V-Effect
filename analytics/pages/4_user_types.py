import os
import sys

import pandas as pd
import plotly.express as px
import streamlit as st

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.db import init_db, read_df
from src.task_classifier import CATEGORY_DESCRIPTIONS

st.set_page_config(page_title="ユーザータイプ | V-EFFECT Analytics", page_icon="👤", layout="wide")
init_db()

st.title("👤 ユーザータイプ別分析")

df_all = read_df("SELECT * FROM user_snapshots ORDER BY date ASC")
df_posts = read_df("SELECT anon_user_id, task_name_original, category_large FROM post_snapshots")

if df_all.empty:
    st.warning("ユーザースナップショットがありません。トップページでデータ取得を実行してください。")
    st.stop()

latest_date = df_all["date"].max()
df_latest = df_all[df_all["date"] == latest_date].copy()

st.caption(f"最新スナップショット日: {latest_date}　ユーザー数: {len(df_latest):,} 人")

# --- ユーザーペルソナカード ---
st.subheader("ユーザーペルソナ")
st.caption("各タイプのユーザーがどんな人か、実際の投稿データから読み取れる特性を示します。")

CARD_COLORS = {
    "Fitness":   "#e8f5e9",
    "Education": "#e3f2fd",
    "Life":      "#fff8e1",
    "Creative":  "#fce4ec",
    "Work":      "#ede7f6",
    "Other":     "#f5f5f5",
}

type_counts = df_latest["primary_user_type"].value_counts()
total_users = len(df_latest)
streak_stats_map = (
    df_latest.groupby("primary_user_type")["streak"]
    .agg(mean="mean", median="median")
    .round(1)
    .to_dict(orient="index")
)
followers_mean = (
    df_latest.groupby("primary_user_type")["followers_count"]
    .mean().round(1).to_dict()
)

# タイプごとの代表タスク（原文）上位3件
representative_tasks: dict[str, list[str]] = {}
if not df_posts.empty:
    for utype in type_counts.index:
        user_ids = set(df_latest[df_latest["primary_user_type"] == utype]["anon_user_id"])
        tasks_for_type = df_posts[
            (df_posts["anon_user_id"].isin(user_ids)) &
            (df_posts["category_large"] != "Other")
        ]["task_name_original"].value_counts().head(3).index.tolist()
        representative_tasks[utype] = tasks_for_type

user_types = list(type_counts.index)
for row_start in range(0, len(user_types), 2):
    cols = st.columns(2)
    for i, utype in enumerate(user_types[row_start:row_start + 2]):
        count = int(type_counts.get(utype, 0))
        pct = count / total_users * 100 if total_users > 0 else 0
        stats = streak_stats_map.get(utype, {})
        avg_streak = stats.get("mean", "-")
        med_streak = stats.get("median", "-")
        avg_followers = followers_mean.get(utype, "-")
        top_tasks = representative_tasks.get(utype, [])
        desc = CATEGORY_DESCRIPTIONS.get(utype, "")
        bg = CARD_COLORS.get(utype, "#f5f5f5")

        tasks_html = " / ".join(f"<code>{t}</code>" for t in top_tasks) if top_tasks else "<i style='color:#999;'>データなし</i>"

        with cols[i]:
            st.markdown(
                f"""
                <div style="background:{bg};border-radius:10px;padding:18px;margin-bottom:12px;">
                  <div style="font-size:1.15em;font-weight:bold;">{utype} 系ユーザー</div>
                  <div style="font-size:0.9em;color:#666;margin-bottom:8px;">{count:,} 人（{pct:.1f}%）</div>
                  <div style="font-size:0.85em;color:#444;margin-bottom:10px;">{desc}</div>
                  <hr style="border:none;border-top:1px solid #ddd;margin:8px 0;">
                  <div style="font-size:0.85em;">
                    <b>代表タスク:</b> {tasks_html}<br>
                    <b>平均ストリーク:</b> {avg_streak} 日　<b>中央値:</b> {med_streak} 日<br>
                    <b>平均フォロワー数:</b> {avg_followers} 人
                  </div>
                </div>
                """,
                unsafe_allow_html=True,
            )

st.divider()

# --- ユーザータイプ分布グラフ ---
st.subheader("ユーザータイプ分布")

col_pie, col_bar = st.columns(2)

with col_pie:
    type_df = type_counts.reset_index()
    type_df.columns = ["ユーザータイプ", "人数"]
    fig_pie = px.pie(
        type_df, names="ユーザータイプ", values="人数",
        title=f"ユーザータイプ分布（{latest_date}）",
        color_discrete_sequence=px.colors.qualitative.Pastel,
    )
    st.plotly_chart(fig_pie, use_container_width=True)

with col_bar:
    fig_bar = px.bar(
        type_df.sort_values("人数", ascending=True),
        x="人数", y="ユーザータイプ", orientation="h",
        title="ユーザータイプ別 人数",
        color="人数",
        color_continuous_scale="Blues",
    )
    fig_bar.update_layout(showlegend=False)
    st.plotly_chart(fig_bar, use_container_width=True)

st.divider()

# --- ユーザータイプ別 ストリーク分布（箱ひげ図） ---
st.subheader("ユーザータイプ別 ストリーク分布")

fig_box = px.box(
    df_latest, x="primary_user_type", y="streak",
    title="ユーザータイプ別 現在ストリーク分布",
    labels={"primary_user_type": "ユーザータイプ", "streak": "ストリーク（日数）"},
    color="primary_user_type",
    color_discrete_sequence=px.colors.qualitative.Set2,
)
fig_box.update_layout(showlegend=False)
st.plotly_chart(fig_box, use_container_width=True)

streak_table = (
    df_latest.groupby("primary_user_type")["streak"]
    .agg(["mean", "median", "max", "count"])
    .reset_index()
    .rename(columns={
        "primary_user_type": "ユーザータイプ",
        "mean": "平均ストリーク",
        "median": "中央値",
        "max": "最大ストリーク",
        "count": "人数",
    })
)
streak_table["平均ストリーク"] = streak_table["平均ストリーク"].round(1)
streak_table["中央値"] = streak_table["中央値"].round(1)
st.dataframe(streak_table.sort_values("平均ストリーク", ascending=False), use_container_width=True, hide_index=True)

st.divider()

# --- maxStreak推移（複数スナップショット時のみ） ---
if df_all["date"].nunique() > 1:
    st.subheader("ユーザータイプ別 平均maxStreak推移")
    trend = (
        df_all.groupby(["date", "primary_user_type"])["max_streak"]
        .mean().round(1).reset_index()
    )
    fig_trend = px.line(
        trend, x="date", y="max_streak", color="primary_user_type",
        title="ユーザータイプ別 平均最大ストリーク推移",
        labels={"date": "日付", "max_streak": "平均maxStreak", "primary_user_type": "ユーザータイプ"},
        markers=True,
    )
    st.plotly_chart(fig_trend, use_container_width=True)
    st.divider()

# --- フォロワー数分析 ---
st.subheader("ユーザータイプ別 フォロワー数分布")
fig_followers = px.box(
    df_latest, x="primary_user_type", y="followers_count",
    title="ユーザータイプ別 フォロワー数分布",
    labels={"primary_user_type": "ユーザータイプ", "followers_count": "フォロワー数"},
    color="primary_user_type",
    color_discrete_sequence=px.colors.qualitative.Pastel,
)
fig_followers.update_layout(showlegend=False)
st.plotly_chart(fig_followers, use_container_width=True)

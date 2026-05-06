import os
import sys

import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import streamlit as st

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.db import init_db, read_df

st.set_page_config(page_title="概要 | V-EFFECT Analytics", page_icon="📊", layout="wide")
init_db()

st.title("📊 アプリ概要")

FIREBASE_FREE_READS_PER_DAY = 50_000

df = read_df("SELECT * FROM daily_app_stats ORDER BY date ASC")

if df.empty:
    st.warning("データがありません。トップページで「Firestoreからデータ取得」を実行してください。")
    st.stop()

latest = df.iloc[-1]

# --- KPI カード ---
col1, col2, col3, col4 = st.columns(4)

with col1:
    st.metric("総登録ユーザー数", f"{int(latest['total_users']):,} 人")

with col2:
    dau = int(latest["daily_active_users"])
    st.metric("DAU（最新日）", f"{dau:,} 人")

with col3:
    mau_window = df.tail(30)
    mau = int(mau_window["daily_active_users"].sum())
    st.metric("MAU（過去30日合算）", f"{mau:,} 人")

with col4:
    posts = int(latest["total_posts_today"]) if "total_posts_today" in latest else 0
    st.metric("当日投稿数", f"{posts:,} 件")

st.divider()

# --- Firebase 無料枠ゲージ ---
st.subheader("Firebase 無料枠使用率（目安）")
# DAU × 推定読み取り回数（1アクティブユーザーあたり約20読み取りと仮定）
estimated_reads = dau * 20
usage_pct = min(estimated_reads / FIREBASE_FREE_READS_PER_DAY * 100, 100)

fig_gauge = go.Figure(go.Indicator(
    mode="gauge+number+delta",
    value=usage_pct,
    number={"suffix": "%", "font": {"size": 36}},
    title={"text": f"推定読み取り数: {estimated_reads:,} / {FIREBASE_FREE_READS_PER_DAY:,}"},
    gauge={
        "axis": {"range": [0, 100]},
        "bar": {"color": "#1f77b4"},
        "steps": [
            {"range": [0, 60], "color": "#d4edda"},
            {"range": [60, 85], "color": "#fff3cd"},
            {"range": [85, 100], "color": "#f8d7da"},
        ],
        "threshold": {"line": {"color": "red", "width": 4}, "thickness": 0.75, "value": 90},
    },
))
fig_gauge.update_layout(height=250, margin=dict(t=40, b=0))
st.plotly_chart(fig_gauge, use_container_width=True)
st.caption("※ 1アクティブユーザーあたり約20読み取りで推定。実際の使用量はFirebase Consoleで確認してください。")

st.divider()

# --- DAU 推移グラフ ---
st.subheader("DAU 推移")

if len(df) > 1:
    date_range = st.slider(
        "期間選択",
        min_value=0,
        max_value=len(df) - 1,
        value=(0, len(df) - 1),
        format="",
        label_visibility="collapsed",
    )
    df_filtered = df.iloc[date_range[0]: date_range[1] + 1]
else:
    df_filtered = df

col_left, col_right = st.columns(2)

with col_left:
    fig_dau = px.line(
        df_filtered, x="date", y="daily_active_users",
        title="DAU（日次アクティブユーザー数）",
        labels={"date": "日付", "daily_active_users": "ユーザー数"},
        markers=True,
    )
    fig_dau.update_traces(line_color="#4c72b0", marker_color="#4c72b0")
    st.plotly_chart(fig_dau, use_container_width=True)

with col_right:
    fig_users = px.line(
        df_filtered, x="date", y="total_users",
        title="総登録ユーザー数推移",
        labels={"date": "日付", "total_users": "ユーザー数"},
        markers=True,
    )
    fig_users.update_traces(line_color="#dd8452", marker_color="#dd8452")
    st.plotly_chart(fig_users, use_container_width=True)

st.divider()

# --- 投稿数推移 ---
st.subheader("日次投稿数推移")
fig_posts = px.bar(
    df_filtered, x="date", y="total_posts_today",
    title="当日投稿数",
    labels={"date": "日付", "total_posts_today": "投稿数"},
    color_discrete_sequence=["#55a868"],
)
st.plotly_chart(fig_posts, use_container_width=True)

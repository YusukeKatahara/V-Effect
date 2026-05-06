import os
import sys

import pandas as pd
import plotly.express as px
import streamlit as st
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.db import init_db, read_df
from src.task_classifier import CATEGORY_DESCRIPTIONS, CATEGORY_HIERARCHY

st.set_page_config(page_title="タスク分析 | V-EFFECT Analytics", page_icon="📋", layout="wide")
init_db()

st.title("📋 タスクカテゴリ分析")

df_posts = read_df("SELECT * FROM post_snapshots ORDER BY date ASC")
df_users = read_df("SELECT anon_user_id, date, streak FROM user_snapshots ORDER BY date DESC")

if df_posts.empty:
    st.warning("投稿データがありません。トップページでデータ取得を実行してください。")
    st.stop()

# 最新スナップショット日のユーザーストリーク（カード表示に使う）
df_latest_users = pd.DataFrame()
if not df_users.empty:
    latest_date = df_users["date"].max()
    df_latest_users = df_users[df_users["date"] == latest_date][["anon_user_id", "streak"]].drop_duplicates()

# --- カテゴリ解説カード ---
st.subheader("カテゴリ別 ユーザー像")
st.caption("各カテゴリに分類されたユーザーがどんなタスクに取り組んでいるかを示します。")

CARD_COLORS = {
    "Fitness": "#e8f5e9",
    "Education": "#e3f2fd",
    "Life": "#fff8e1",
    "Creative": "#fce4ec",
    "Work": "#ede7f6",
    "Other": "#f5f5f5",
}

all_large_cats = list(CATEGORY_HIERARCHY.keys()) + ["Other"]

for row_start in range(0, len(all_large_cats), 3):
    cols = st.columns(3)
    for i, cat in enumerate(all_large_cats[row_start:row_start + 3]):
        df_cat = df_posts[df_posts["category_large"] == cat]
        post_count = len(df_cat)

        # 代表タスク（原文）上位3件
        top_tasks = (
            df_cat["task_name_original"].value_counts().head(3).index.tolist()
            if not df_cat.empty else []
        )

        # カテゴリ×ユーザーのストリーク平均
        avg_streak = None
        if not df_latest_users.empty and not df_cat.empty:
            merged = df_cat.merge(df_latest_users, on="anon_user_id", how="inner")
            if not merged.empty:
                avg_streak = merged["streak"].mean()

        bg = CARD_COLORS.get(cat, "#f5f5f5")
        with cols[i]:
            st.markdown(
                f"""
                <div style="background:{bg};border-radius:10px;padding:16px;margin-bottom:8px;min-height:160px;">
                  <b style="font-size:1.1em;">{cat}</b><br>
                  <span style="font-size:0.85em;color:#555;">{CATEGORY_DESCRIPTIONS.get(cat, '')}</span><br><br>
                  <b>投稿数:</b> {post_count:,} 件<br>
                  {"<b>平均ストリーク:</b> " + f"{avg_streak:.1f} 日<br>" if avg_streak is not None else ""}
                  {"<b>代表タスク:</b><br>" + " / ".join(f"<code>{t}</code>" for t in top_tasks) if top_tasks else "<i style='color:#999;'>タスクなし</i>"}
                </div>
                """,
                unsafe_allow_html=True,
            )

if df_posts[df_posts["category_large"] == "Other"].shape[0] > 0:
    st.info(
        f"未分類タスクが {df_posts[df_posts['category_large'] == 'Other'].shape[0]} 件あります。"
        "「5 Labeling」ページで手動分類できます。"
    )

st.divider()

# --- 期間フィルタ ---
dates = sorted(df_posts["date"].dropna().unique())
if len(dates) > 1:
    col_start, col_end = st.columns(2)
    with col_start:
        start_date = st.selectbox("開始日", dates, index=0)
    with col_end:
        end_date = st.selectbox("終了日", dates, index=len(dates) - 1)
    df_posts = df_posts[(df_posts["date"] >= start_date) & (df_posts["date"] <= end_date)]

# --- 大カテゴリ分布 ---
st.subheader("大カテゴリ分布")
col_pie, col_bar = st.columns(2)

with col_pie:
    cat_counts = df_posts["category_large"].value_counts().reset_index()
    cat_counts.columns = ["カテゴリ", "投稿数"]
    fig_pie = px.pie(
        cat_counts, names="カテゴリ", values="投稿数",
        title="大カテゴリ別投稿割合",
        color_discrete_sequence=px.colors.qualitative.Set2,
    )
    st.plotly_chart(fig_pie, use_container_width=True)

with col_bar:
    medium_counts = df_posts["category_medium"].value_counts().head(15).reset_index()
    medium_counts.columns = ["中カテゴリ", "投稿数"]
    fig_medium = px.bar(
        medium_counts, x="投稿数", y="中カテゴリ", orientation="h",
        title="中カテゴリ別投稿数（上位15）",
        color_discrete_sequence=["#4c72b0"],
    )
    fig_medium.update_layout(yaxis={"categoryorder": "total ascending"})
    st.plotly_chart(fig_medium, use_container_width=True)

st.divider()

# --- カテゴリ別投稿数/日 積み上げ棒グラフ ---
st.subheader("大カテゴリ別 日次投稿数推移")
daily_cat = df_posts.groupby(["date", "category_large"]).size().reset_index(name="投稿数")
if not daily_cat.empty:
    fig_stack = px.bar(
        daily_cat, x="date", y="投稿数", color="category_large",
        title="大カテゴリ別 日次投稿数（積み上げ）",
        labels={"date": "日付", "category_large": "カテゴリ"},
        color_discrete_sequence=px.colors.qualitative.Set2,
    )
    st.plotly_chart(fig_stack, use_container_width=True)

st.divider()

# --- カテゴリ別平均ストリーク ---
st.subheader("カテゴリ別 平均ストリーク")

if not df_latest_users.empty:
    df_merged = df_posts.merge(df_latest_users, on="anon_user_id", how="inner")
    streak_by_cat = df_merged.groupby("category_large")["streak"].mean().reset_index()
    streak_by_cat.columns = ["カテゴリ", "平均ストリーク"]
    streak_by_cat = streak_by_cat.sort_values("平均ストリーク", ascending=False)

    fig_streak = px.bar(
        streak_by_cat, x="カテゴリ", y="平均ストリーク",
        title="大カテゴリ別 平均ストリーク（日数）",
        color="平均ストリーク",
        color_continuous_scale="Blues",
    )
    st.plotly_chart(fig_streak, use_container_width=True)
else:
    st.info("ユーザースナップショットがないため、ストリーク分析をスキップしました。")

st.divider()

# --- カテゴリ間コサイン類似度ヒートマップ ---
st.subheader("大カテゴリ間コサイン類似度")
st.caption("各カテゴリのキーワードをTF-IDFベクトル化して類似度を計算。値が高いほど近い傾向のカテゴリ。")

large_cats = list(CATEGORY_HIERARCHY.keys())
corpora = [
    " ".join(kw for keywords in mediums.values() for kw in keywords)
    for mediums in CATEGORY_HIERARCHY.values()
]
vectorizer = TfidfVectorizer()
vecs = vectorizer.fit_transform(corpora)
sim_matrix = cosine_similarity(vecs).round(3)

df_sim = pd.DataFrame(sim_matrix, index=large_cats, columns=large_cats)
fig_heat = px.imshow(
    df_sim, text_auto=True, aspect="auto",
    title="カテゴリ間コサイン類似度マトリクス",
    color_continuous_scale="Blues",
    zmin=0, zmax=1,
)
st.plotly_chart(fig_heat, use_container_width=True)

st.divider()

# --- 未分類タスク一覧 ---
st.subheader("未分類タスク（Other）一覧")
st.caption("「5 Labeling」ページで手動でカテゴリを設定できます。")
df_other = (
    df_posts[df_posts["category_large"] == "Other"]["task_name_original"]
    .value_counts().head(30).reset_index()
)
df_other.columns = ["タスク名（原文）", "投稿数"]
if df_other.empty:
    st.success("未分類タスクはありません。")
else:
    st.dataframe(df_other, use_container_width=True, hide_index=True)

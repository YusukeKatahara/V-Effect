import os
import sys

import pandas as pd
import plotly.express as px
import streamlit as st

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.db import init_db, read_df

st.set_page_config(page_title="エンゲージメント | V-EFFECT Analytics", page_icon="🔥", layout="wide")
init_db()

st.title("🔥 エンゲージメント分析")

df = read_df("SELECT * FROM post_snapshots")

if df.empty:
    st.warning("投稿データがありません。トップページでデータ取得を実行してください。")
    st.stop()

st.divider()

# --- 中カテゴリ別 フォロワー1人あたりリアクション数 ---
st.subheader("中カテゴリ別 フォロワー1人あたりリアクション数")
st.caption("数値が高いほど、そのカテゴリの投稿がフォロワーから注目されやすい傾向を示します。")

rfr_by_medium = (
    df.groupby(["category_large", "category_medium"])
    .agg(
        avg_reactions_per_follower=("reactions_per_follower", "mean"),
        total_posts=("post_id", "count"),
        avg_followers=("follower_count", "mean"),
    )
    .reset_index()
    .sort_values("avg_reactions_per_follower", ascending=False)
    .head(20)
)
rfr_by_medium["表示名"] = rfr_by_medium["category_large"] + " / " + rfr_by_medium["category_medium"]
rfr_by_medium["avg_reactions_per_follower"] = rfr_by_medium["avg_reactions_per_follower"].round(2)

fig_rfr = px.bar(
    rfr_by_medium, x="avg_reactions_per_follower", y="表示名", orientation="h",
    title="フォロワー1人あたり平均リアクション数（中カテゴリ別、上位20）",
    labels={"avg_reactions_per_follower": "リアクション数/フォロワー"},
    color="avg_reactions_per_follower",
    color_continuous_scale="Oranges",
    hover_data={"total_posts": True, "avg_followers": ":.1f"},
)
fig_rfr.update_layout(yaxis={"categoryorder": "total ascending"}, showlegend=False)
st.plotly_chart(fig_rfr, use_container_width=True)

st.divider()

# --- 投稿数上位タスク名ランキング ---
st.subheader("投稿数上位タスク名ランキング")

col_orig, col_en = st.columns(2)

with col_orig:
    top_tasks_orig = (
        df["task_name_original"].value_counts().head(20).reset_index()
    )
    top_tasks_orig.columns = ["タスク名（原文）", "投稿数"]
    fig_top_orig = px.bar(
        top_tasks_orig, x="投稿数", y="タスク名（原文）", orientation="h",
        title="投稿数上位タスク（原文、上位20）",
        color_discrete_sequence=["#4c72b0"],
    )
    fig_top_orig.update_layout(yaxis={"categoryorder": "total ascending"})
    st.plotly_chart(fig_top_orig, use_container_width=True)

with col_en:
    top_tasks_en = (
        df["task_name_translated"].value_counts().head(20).reset_index()
    )
    top_tasks_en.columns = ["タスク名（英語）", "投稿数"]
    fig_top_en = px.bar(
        top_tasks_en, x="投稿数", y="タスク名（英語）", orientation="h",
        title="投稿数上位タスク（英語翻訳済み、上位20）",
        color_discrete_sequence=["#dd8452"],
    )
    fig_top_en.update_layout(yaxis={"categoryorder": "total ascending"})
    st.plotly_chart(fig_top_en, use_container_width=True)

st.divider()

# --- 炎リアクション vs 絵文字リアクション比較 ---
st.subheader("🔥 炎リアクション vs 絵文字リアクション")

col_v, col_e = st.columns(2)

with col_v:
    total_flame = int(df["reaction_count"].sum())
    total_emoji = int(df["emoji_reaction_count"].sum())

    fig_compare = px.bar(
        pd.DataFrame({
            "種別": ["🔥 炎リアクション合計", "😊 絵文字リアクション合計"],
            "件数": [total_flame, total_emoji],
        }),
        x="種別", y="件数",
        title="リアクション種別合計",
        color="種別",
        color_discrete_sequence=["#e74c3c", "#f39c12"],
    )
    st.plotly_chart(fig_compare, use_container_width=True)

with col_e:
    rfr_large = (
        df.groupby("category_large")
        .agg(
            avg_flame=("reaction_count", "mean"),
            avg_emoji=("emoji_reaction_count", "mean"),
        )
        .reset_index()
    )
    fig_rfr_large = px.bar(
        rfr_large.melt(id_vars="category_large", var_name="種別", value_name="平均数"),
        x="category_large", y="平均数", color="種別",
        barmode="group",
        title="カテゴリ別 平均リアクション数",
        labels={"category_large": "カテゴリ"},
        color_discrete_map={"avg_flame": "#e74c3c", "avg_emoji": "#f39c12"},
    )
    st.plotly_chart(fig_rfr_large, use_container_width=True)

st.divider()

# --- 詳細テーブル ---
st.subheader("中カテゴリ別 詳細集計")
detail = (
    df.groupby(["category_large", "category_medium"])
    .agg(
        投稿数=("post_id", "count"),
        炎リアクション合計=("reaction_count", "sum"),
        絵文字リアクション合計=("emoji_reaction_count", "sum"),
        平均フォロワー数=("follower_count", "mean"),
        フォロワー当たりリアクション=("reactions_per_follower", "mean"),
    )
    .reset_index()
    .rename(columns={"category_large": "大カテゴリ", "category_medium": "中カテゴリ"})
    .sort_values("投稿数", ascending=False)
)
detail["平均フォロワー数"] = detail["平均フォロワー数"].round(1)
detail["フォロワー当たりリアクション"] = detail["フォロワー当たりリアクション"].round(2)
st.dataframe(detail, use_container_width=True, hide_index=True)

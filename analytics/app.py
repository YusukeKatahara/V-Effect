import os
import sys

import streamlit as st

# src/ をパスに追加
sys.path.insert(0, os.path.dirname(__file__))

from src.db import init_db, read_df

st.set_page_config(
    page_title="V-EFFECT Analytics",
    page_icon="⚡",
    layout="wide",
)

init_db()

st.title("⚡ V-EFFECT Analytics Dashboard")
st.caption("開発者専用 ローカル分析ダッシュボード")

st.divider()

# --- データ更新セクション ---
st.subheader("データ更新")

col_btn, col_info = st.columns([1, 3])

with col_btn:
    force_update = st.checkbox("今日分を強制上書き", value=False)
    if st.button("Firestoreからデータ取得", type="primary", use_container_width=True):
        try:
            from src.snapshot_manager import run_daily_snapshot
            with st.spinner("Firestoreからデータを取得中..."):
                summary = run_daily_snapshot(force=force_update)
            if summary.get("skipped"):
                st.info(
                    f"今日（{summary['date']}）のスナップショットは取得済みです。"
                    "「今日分を強制上書き」にチェックを入れると再取得できます。"
                )
            else:
                st.success(
                    f"完了！ ユーザー {summary['total_users']} 件、"
                    f"投稿 {summary['total_posts']} 件を保存しました。"
                )
            st.rerun()
        except FileNotFoundError as e:
            st.error(str(e))
        except Exception as e:
            st.error(f"エラーが発生しました: {e}")

with col_info:
    df_latest = read_df(
        "SELECT date, captured_at, total_users, daily_active_users FROM daily_app_stats ORDER BY date DESC LIMIT 1"
    )
    if not df_latest.empty:
        row = df_latest.iloc[0]
        st.info(
            f"最終更新: **{row['date']}** ({str(row['captured_at'])[:19]})　"
            f"ユーザー数: {row['total_users']}　DAU: {row['daily_active_users']}"
        )
    else:
        st.warning("スナップショットがまだありません。「Firestoreからデータ取得」を実行してください。")

st.divider()

# --- スナップショット履歴 ---
df = read_df(
    "SELECT date, total_users, daily_active_users, total_posts_today FROM daily_app_stats ORDER BY date DESC"
)

if not df.empty:
    st.subheader("スナップショット履歴")
    st.dataframe(
        df.rename(columns={
            "date": "日付",
            "total_users": "総ユーザー数",
            "daily_active_users": "DAU",
            "total_posts_today": "当日投稿数",
        }),
        use_container_width=True,
        hide_index=True,
    )

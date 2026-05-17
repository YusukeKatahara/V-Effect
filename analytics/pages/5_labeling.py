import datetime
import os
import sys

import streamlit as st

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.db import get_conn, init_db, read_df
from src.task_classifier import CATEGORY_HIERARCHY

st.set_page_config(page_title="手動ラベリング | V-EFFECT Analytics", page_icon="🏷️", layout="wide")
init_db()

st.title("🏷️ 手動ラベリング")
st.caption("機械分類で「Other」になったタスクに、開発者が直接カテゴリを設定できます。手動ラベルは機械分類より常に優先されます。")

# --- セクション1: 未ラベルタスク一覧 ---
st.subheader("未ラベルタスク一覧")

df_other = read_df("""
    SELECT
        p.task_name_original,
        p.task_name_translated,
        COUNT(*) AS post_count
    FROM post_snapshots p
    WHERE p.category_large = 'Other'
    GROUP BY p.task_name_original, p.task_name_translated
    ORDER BY post_count DESC
""")

if df_other.empty:
    st.success("未ラベルのタスクはありません。全タスクが分類済みです。")
else:
    st.dataframe(
        df_other.rename(columns={
            "task_name_original": "タスク名（原文）",
            "task_name_translated": "翻訳",
            "post_count": "投稿数",
        }),
        use_container_width=True,
        hide_index=True,
    )
    st.caption(f"合計 {len(df_other)} 件の未ラベルタスクがあります。")

st.divider()

# --- セクション2: ラベル付与フォーム ---
st.subheader("ラベルを付与する")

if df_other.empty:
    st.info("未ラベルタスクがないため、ラベル付与フォームは表示されません。")
else:
    task_options = df_other["task_name_original"].tolist()

    selected_task = st.selectbox("タスクを選択", task_options, key="label_task")

    # 選択中のタスクの翻訳を表示
    selected_row = df_other[df_other["task_name_original"] == selected_task]
    if not selected_row.empty:
        st.caption(f"翻訳: {selected_row.iloc[0]['task_name_translated']}")

    large_cats = list(CATEGORY_HIERARCHY.keys())
    selected_large = st.selectbox("大カテゴリ", large_cats, key="label_large")

    # 大カテゴリ変更時に中カテゴリを連動させるため form の外に置く
    medium_cats = list(CATEGORY_HIERARCHY[selected_large].keys())
    selected_medium = st.selectbox("中カテゴリ", medium_cats, key="label_medium")

    submitted = st.button("保存する", type="primary")

    if submitted:
        now_str = datetime.datetime.now().isoformat()
        translated_val = (
            selected_row.iloc[0]["task_name_translated"]
            if not selected_row.empty else selected_task
        )

        with get_conn() as conn:
            # task_category_cache を手動ラベルで上書き
            conn.execute(
                """INSERT OR REPLACE INTO task_category_cache
                   (task_name_original, task_name_translated, category_large, category_medium, classified_at, is_manual)
                   VALUES (?, ?, ?, ?, ?, 1)""",
                (selected_task, translated_val, selected_large, selected_medium, now_str),
            )
            # post_snapshots の該当タスクも一括更新
            updated = conn.execute(
                """UPDATE post_snapshots
                   SET category_large = ?, category_medium = ?
                   WHERE task_name_original = ?""",
                (selected_large, selected_medium, selected_task),
            ).rowcount

        st.success(
            f"「{selected_task}」を **{selected_large} / {selected_medium}** に分類しました。"
            f"（{updated} 件の投稿を更新）"
        )
        st.rerun()

st.divider()

# --- セクション3: 手動ラベル済み一覧 ---
st.subheader("手動ラベル済みタスク")

df_manual = read_df("""
    SELECT task_name_original, task_name_translated, category_large, category_medium, classified_at
    FROM task_category_cache
    WHERE is_manual = 1
    ORDER BY classified_at DESC
""")

if df_manual.empty:
    st.info("まだ手動ラベルはありません。")
else:
    st.caption(f"{len(df_manual)} 件のタスクに手動ラベルが設定されています。")

    for _, row in df_manual.iterrows():
        col_info, col_btn = st.columns([5, 1])
        with col_info:
            st.markdown(
                f"**{row['task_name_original']}**　→　"
                f"`{row['category_large']} / {row['category_medium']}`　"
                f"<span style='color:#999;font-size:0.8em;'>（{str(row['classified_at'])[:10]}）</span>",
                unsafe_allow_html=True,
            )
        with col_btn:
            if st.button("取り消し", key=f"undo_{row['task_name_original']}"):
                with get_conn() as conn:
                    conn.execute(
                        """UPDATE task_category_cache
                           SET category_large = 'Other', category_medium = 'Other', is_manual = 0
                           WHERE task_name_original = ?""",
                        (row["task_name_original"],),
                    )
                    conn.execute(
                        """UPDATE post_snapshots
                           SET category_large = 'Other', category_medium = 'Other'
                           WHERE task_name_original = ?""",
                        (row["task_name_original"],),
                    )
                st.rerun()

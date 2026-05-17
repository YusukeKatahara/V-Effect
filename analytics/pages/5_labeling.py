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
st.caption("誤分類・未分類のタスクに手動でカテゴリを設定します。手動ラベルは機械分類より常に優先されます。")

# ── カテゴリフィルター ────────────────────────────────────────────────────
all_large = ["Other"] + list(CATEGORY_HIERARCHY.keys())
filter_large = st.selectbox(
    "表示するカテゴリ（誤分類の修正はここでカテゴリを選択して対象タスクを探してください）",
    all_large,
    key="filter_large",
)

# ── セクション1: タスク一覧 ───────────────────────────────────────────────
label = "未ラベルタスク一覧" if filter_large == "Other" else f"「{filter_large}」に分類されているタスク一覧"
st.subheader(label)

df_tasks = read_df(
    """
    SELECT
        p.task_name_original,
        p.task_name_translated,
        p.category_large,
        p.category_medium,
        COUNT(*) AS post_count
    FROM post_snapshots p
    WHERE p.category_large = ?
    GROUP BY p.task_name_original, p.task_name_translated, p.category_large, p.category_medium
    ORDER BY post_count DESC
    """,
    (filter_large,),
)

if df_tasks.empty:
    if filter_large == "Other":
        st.success("未ラベルのタスクはありません。全タスクが分類済みです。")
    else:
        st.info(f"「{filter_large}」に分類されているタスクはありません。")
else:
    col_rename = {
        "task_name_original": "タスク名（原文）",
        "task_name_translated": "翻訳",
        "category_large": "大カテゴリ",
        "category_medium": "中カテゴリ",
        "post_count": "投稿数",
    }
    show_cols = ["task_name_original", "task_name_translated", "post_count"] if filter_large == "Other" \
        else ["task_name_original", "task_name_translated", "category_large", "category_medium", "post_count"]
    st.dataframe(
        df_tasks[show_cols].rename(columns=col_rename),
        use_container_width=True,
        hide_index=True,
    )
    st.caption(f"合計 {len(df_tasks)} 件")

st.divider()

# ── セクション2: ラベル付与フォーム ─────────────────────────────────────
st.subheader("ラベルを付与 / 修正する")

if df_tasks.empty:
    st.info("対象タスクがありません。")
else:
    task_options = df_tasks["task_name_original"].tolist()
    selected_task = st.selectbox("タスクを選択", task_options, key="label_task")

    selected_row = df_tasks[df_tasks["task_name_original"] == selected_task]
    if not selected_row.empty:
        r = selected_row.iloc[0]
        st.caption(
            f"翻訳: {r['task_name_translated']}　／　"
            f"現在の分類: **{r['category_large']} / {r['category_medium']}**"
        )

    large_cats = list(CATEGORY_HIERARCHY.keys())
    # 現在の分類を初期値にする
    current_large = selected_row.iloc[0]["category_large"] if not selected_row.empty else large_cats[0]
    default_large_idx = large_cats.index(current_large) if current_large in large_cats else 0
    selected_large = st.selectbox("大カテゴリ", large_cats, index=default_large_idx, key="label_large")

    medium_cats = list(CATEGORY_HIERARCHY[selected_large].keys())
    current_medium = selected_row.iloc[0]["category_medium"] if not selected_row.empty else medium_cats[0]
    default_medium_idx = medium_cats.index(current_medium) if current_medium in medium_cats else 0
    selected_medium = st.selectbox("中カテゴリ", medium_cats, index=default_medium_idx, key="label_medium")

    submitted = st.button("保存する", type="primary")

    if submitted:
        now_str = datetime.datetime.now().isoformat()
        translated_val = (
            selected_row.iloc[0]["task_name_translated"]
            if not selected_row.empty else selected_task
        )

        with get_conn() as conn:
            conn.execute(
                """INSERT OR REPLACE INTO task_category_cache
                   (task_name_original, task_name_translated, category_large, category_medium, classified_at, is_manual)
                   VALUES (?, ?, ?, ?, ?, 1)""",
                (selected_task, translated_val, selected_large, selected_medium, now_str),
            )
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

# ── セクション3: 手動ラベル済み一覧 ─────────────────────────────────────
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

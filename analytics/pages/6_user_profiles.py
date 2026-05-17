import os
import sys

import streamlit as st

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.db import init_db
from src.firebase_client import FirebaseClient

st.set_page_config(
    page_title="ユーザー詳細 | V-EFFECT Analytics",
    page_icon="👤",
    layout="wide",
)
init_db()

st.title("👤 ユーザー詳細")
st.caption("analytics_users コレクションのユーザー別プロフィール・ログデータ")


@st.cache_data(ttl=300)
def load_all_profiles() -> list[dict]:
    db = FirebaseClient.db()
    docs = db.collection("analytics_users").stream()
    users = []
    for doc in docs:
        data = doc.to_dict() or {}
        data["_anon_id"] = doc.id
        users.append(data)
    return users


try:
    users = load_all_profiles()
except Exception as exc:
    st.error(f"Firestore 接続エラー: {exc}")
    st.stop()

if not users:
    st.warning(
        "analytics_users コレクションにデータがありません。"
        "トップページで「Firestoreからデータ取得」を実行してください。"
    )
    st.stop()

# ── ユーザー選択 ─────────────────────────────────────────────────────────
anon_ids = [u["_anon_id"] for u in users]
selected_id = st.selectbox(
    f"ユーザーを選択（{len(users)} 人）",
    anon_ids,
    format_func=lambda x: f"User {x}",
)

user = next((u for u in users if u["_anon_id"] == selected_id), None)
if user is None:
    st.stop()

# ── プロフィール ──────────────────────────────────────────────────────────
st.subheader("プロフィール")

col1, col2, col3, col4 = st.columns(4)
with col1:
    st.metric("登録日", user.get("sign_up_date") or "—")
    st.metric("フォロワー数", user.get("followers", 0))
with col2:
    st.metric("年齢", user.get("age") or "—")
    rate = user.get("monthly_active_rate")
    st.metric("月次アクティブ率", f"{rate:.0%}" if rate is not None else "—")
with col3:
    st.metric("性別", user.get("gender") or "—")
    st.metric("職業", user.get("job") or "—")
with col4:
    updated = user.get("updated_at")
    st.metric("最終更新", str(updated)[:10] if updated else "—")

tasks = user.get("tasks") or []
if tasks:
    st.markdown("**現在のタスク**: " + "　/　".join(tasks))

persona = user.get("persona")
if persona:
    st.info(f"**ペルソナ**: {persona}")

st.divider()

# ── サブコレクション取得 ─────────────────────────────────────────────────
db = FirebaseClient.db()
user_ref = db.collection("analytics_users").document(selected_id)

tab_posts, tab_streaks, tab_tasks = st.tabs(["📝 投稿ログ", "🔥 ストリーク履歴", "✅ タスク変化"])

with tab_posts:
    raw = [d.to_dict() for d in user_ref.collection("posts").stream()]
    posts = sorted(raw, key=lambda x: x.get("posted_at", ""), reverse=True)
    if posts:
        st.dataframe(
            posts,
            column_order=["posted_at", "task_name", "reactions", "comments"],
            use_container_width=True,
            hide_index=True,
        )
        st.caption(f"計 {len(posts)} 件")
    else:
        st.info("投稿記録なし")

with tab_streaks:
    raw = [d.to_dict() for d in user_ref.collection("streaks").stream()]
    streaks = sorted(raw, key=lambda x: x.get("date", ""), reverse=True)
    if streaks:
        st.dataframe(
            streaks,
            column_order=["date", "streak", "action"],
            use_container_width=True,
            hide_index=True,
        )
        st.caption(f"計 {len(streaks)} 件")
    else:
        st.info("ストリークイベントなし（スナップショット2日目以降から記録されます）")

with tab_tasks:
    raw = [d.to_dict() for d in user_ref.collection("tasks").stream()]
    task_events = sorted(raw, key=lambda x: x.get("timestamp", ""), reverse=True)
    if task_events:
        st.dataframe(
            task_events,
            column_order=["timestamp", "action", "task_name"],
            use_container_width=True,
            hide_index=True,
        )
        st.caption(f"計 {len(task_events)} 件")
    else:
        st.info("タスク変化なし（スナップショット2日目以降から記録されます）")

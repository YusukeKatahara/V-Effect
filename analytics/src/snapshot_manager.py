import datetime
import json
from typing import Optional

from .anonymizer import anonymize_uid, anonymize_user
from .db import get_conn, init_db
from .firebase_client import FirebaseClient
from .firestore_analytics_writer import write_analytics_snapshot
from .task_classifier import TaskClassifier
from .translator import translate_batch
from .user_typer import infer_user_type


def run_daily_snapshot(target_date: Optional[datetime.date] = None, force: bool = False) -> dict:
    """
    Firestoreから必要最小限のデータを取得し、スナップショットをSQLiteに保存する。

    - 同日に既に取得済みの場合は force=True を指定しない限りスキップする（二重課金防止）
    - postsは直近90日分のみ取得（全件取得によるコスト増大を防ぐ）
    戻り値: 処理件数の集計dict
    """
    init_db()
    today = target_date or datetime.date.today()
    date_str = today.isoformat()
    now_str = datetime.datetime.now().isoformat()

    # 今日のスナップショットが既に存在する場合はスキップ
    if not force:
        with get_conn() as conn:
            existing = conn.execute(
                "SELECT captured_at FROM daily_app_stats WHERE date = ?", (date_str,)
            ).fetchone()
        if existing:
            print(f"[snapshot] {date_str} のスナップショットは既に存在します（{existing['captured_at'][:19]}）。スキップします。force=True で上書きできます。")
            with get_conn() as conn:
                row = conn.execute(
                    "SELECT total_users, daily_active_users, total_posts_today FROM daily_app_stats WHERE date = ?",
                    (date_str,)
                ).fetchone()
            return {
                "date": date_str,
                "total_users": row["total_users"],
                "dau": row["daily_active_users"],
                "total_posts": row["total_posts_today"],
                "posts_today": row["total_posts_today"],
                "skipped": True,
            }

    print(f"[snapshot] {date_str} のスナップショットを取得中...")

    users = FirebaseClient.fetch_all_users()
    # 直近90日分の投稿のみ取得（全件取得は避ける）
    posts = FirebaseClient.fetch_posts_since(days=90)

    print(f"[snapshot] ユーザー {len(users)} 件、投稿 {len(posts)} 件を取得")

    # UID → 現在アクティブなタスク名セット（Firestoreのtasks[]が正）
    uid_to_active_tasks: dict[str, set[str]] = {}
    for u in users:
        titles = {
            t.get("title", "") if isinstance(t, dict) else str(t)
            for t in (u.get("tasks") or [])
            if t
        }
        uid_to_active_tasks[u["uid"]] = titles

    # UID→フォロワー数のマップ（投稿時点のフォロワー数として近似）
    uid_to_followers: dict[str, int] = {
        u["uid"]: len(u.get("followers", [])) for u in users
    }

    # --- 1. 投稿スナップショット（アクティブなタスクのみ） ---
    # ユーザーが既に削除したタスク名の投稿は除外する
    active_posts = [
        p for p in posts
        if p.get("taskName", "") in uid_to_active_tasks.get(p.get("userId", ""), set())
    ]
    skipped = len(posts) - len(active_posts)
    if skipped > 0:
        print(f"[snapshot] 削除済みタスクの投稿 {skipped} 件を除外しました")

    post_task_names = list({p.get("taskName", "") for p in active_posts if p.get("taskName")})
    translation_map = translate_batch(post_task_names)

    classifier = TaskClassifier()
    post_rows = []

    for post in active_posts:
        task_orig = post.get("taskName", "")
        task_en = translation_map.get(task_orig, task_orig)
        category = classifier.classify_with_cache(task_orig, task_en)

        uid = post.get("userId", "")
        follower_count = uid_to_followers.get(uid, 0)
        reaction_count = post.get("reactionCount", 0)
        emoji_count = len(post.get("emojiReactedUserIds", []))
        reactions_per_follower = reaction_count / max(follower_count, 1)

        created_at = _ts_to_iso(post.get("createdAt"))
        post_date = created_at[:10] if created_at else date_str

        post_rows.append((
            post["post_id"],
            anonymize_uid(uid),
            task_orig,
            task_en,
            category["large"],
            category["medium"],
            reaction_count,
            emoji_count,
            follower_count,
            reactions_per_follower,
            created_at,
            post_date,
        ))

    with get_conn() as conn:
        conn.executemany(
            """INSERT OR REPLACE INTO post_snapshots
               (post_id, anon_user_id, task_name_original, task_name_translated,
                category_large, category_medium, reaction_count, emoji_reaction_count,
                follower_count, reactions_per_follower, created_at, date)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            post_rows,
        )

    # --- SQLiteの過去データもクリーンアップ ---
    # 今回のFirestore取得で確認できた全ユーザーについて、
    # 現在のtasks[]に存在しないタスク名のpost_snapshotsを削除する
    _cleanup_stale_posts(uid_to_active_tasks)

    # --- 2. ユーザースナップショット ---
    # タスク分類のため全ユーザーのtasksを翻訳・分類
    all_task_names = list({
        t for u in users for t in [task.get("title", "") if isinstance(task, dict) else str(task)
                                   for task in u.get("tasks", [])]
        if t
    })
    task_translation_map = translate_batch(all_task_names)

    anon_users = {}  # uid -> anonymize_user() の結果（Firestore analytics 書き込みで使用）
    user_rows = []
    for user in users:
        anon = anonymize_user(user)
        anon_users[user["uid"]] = anon
        task_titles_en = [task_translation_map.get(t, t) for t in anon["tasks"]]
        task_categories = [classifier.classify(t)["large"] for t in task_titles_en]
        primary_type = infer_user_type(task_categories)

        user_rows.append((
            date_str,
            anon["anon_user_id"],
            anon["streak"],
            anon["max_streak"],
            anon["following_count"],
            anon["followers_count"],
            primary_type,
            anon["last_posted_date"],
            anon.get("streak_protections", 0),
            json.dumps(anon["tasks"], ensure_ascii=False),
        ))

    with get_conn() as conn:
        conn.executemany(
            """INSERT OR REPLACE INTO user_snapshots
               (date, anon_user_id, streak, max_streak, following_count, followers_count,
                primary_user_type, last_posted_date, streak_protections, task_names)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            user_rows,
        )

    # --- 3. 日次アプリ統計 ---
    dau = sum(1 for u in users if u.get("lastPostedDate") == date_str)
    # アクティブなタスクの投稿のみカウント（削除済みタスクは除外）
    posts_today = sum(1 for p in active_posts if (p.get("createdAt") and _ts_to_iso(p["createdAt"])[:10] == date_str))

    with get_conn() as conn:
        conn.execute(
            """INSERT OR REPLACE INTO daily_app_stats
               (date, total_users, daily_active_users, total_posts_today, captured_at)
               VALUES (?, ?, ?, ?, ?)""",
            (date_str, len(users), dau, posts_today, now_str),
        )

    summary = {
        "date": date_str,
        "total_users": len(users),
        "dau": dau,
        "total_posts": len(active_posts),
        "posts_today": posts_today,
    }
    print(f"[snapshot] 完了: {summary}")

    # --- 4. Firestore analytics コレクションへの書き込み ---
    analytics_result = write_analytics_snapshot(
        users=users,
        active_posts=active_posts,
        anon_users=anon_users,
        date_str=date_str,
        dau=dau,
        total_users=len(users),
    )
    summary["firestore_analytics"] = analytics_result

    return summary


def _cleanup_stale_posts(uid_to_active_tasks: dict[str, set[str]]) -> None:
    """SQLiteのpost_snapshotsから、削除済みタスクの投稿を除去する。

    Firestoreで確認できた全ユーザーのアクティブなタスク名を正として、
    現在のtasks[]に存在しないタスク名の投稿を削除する。
    """
    deleted_total = 0
    with get_conn() as conn:
        for uid, active_tasks in uid_to_active_tasks.items():
            anon_uid = anonymize_uid(uid)
            if active_tasks:
                placeholders = ",".join("?" * len(active_tasks))
                deleted = conn.execute(
                    f"DELETE FROM post_snapshots WHERE anon_user_id = ? AND task_name_original NOT IN ({placeholders})",
                    [anon_uid, *active_tasks],
                ).rowcount
            else:
                # タスクが一つもないユーザーは全投稿を削除
                deleted = conn.execute(
                    "DELETE FROM post_snapshots WHERE anon_user_id = ?",
                    (anon_uid,),
                ).rowcount
            deleted_total += deleted

    if deleted_total > 0:
        print(f"[snapshot] 削除済みタスクの過去データ {deleted_total} 件をSQLiteから除去しました")


def _ts_to_iso(ts) -> str:
    """FirestoreのTimestampをISO8601文字列に変換する。"""
    if ts is None:
        return ""
    if hasattr(ts, "isoformat"):
        return ts.isoformat()
    if hasattr(ts, "_seconds"):
        return datetime.datetime.fromtimestamp(ts._seconds).isoformat()
    return str(ts)

"""
Firestore analytics コレクションへの書き込みモジュール。

- analytics_users/{anon_id}            : ユーザープロフィール
- analytics_users/{anon_id}/posts      : 投稿ログ
- analytics_users/{anon_id}/streaks    : ストリークイベントログ
- analytics_users/{anon_id}/tasks      : タスク変化ログ
- analytics_app_state/dau              : 日次アクティブユーザー数
- analytics_app_state/mau              : 月次アクティブユーザー数

追加の Firestore 読み取りはゼロ（SQLite の前日スナップショットと比較）。
変化のないユーザーはスキップし、書き込みコストを最小化する。
"""

import datetime
import json
import logging
from typing import Optional

from .anonymizer import anonymize_uid
from .db import (
    ensure_user_first_seen,
    get_all_first_seen_dates,
    get_analytics_meta,
    get_conn,
    set_analytics_meta,
)

logger = logging.getLogger(__name__)

_MAX_BATCH = 450  # Firestore batch 上限 500 に余裕を持たせる


def write_analytics_snapshot(
    users: list,
    active_posts: list,
    anon_users: dict,  # uid -> anonymize_user() の結果
    date_str: str,     # YYYY-MM-DD
    dau: int,
    total_users: int,
) -> dict:
    """
    スナップショットデータを Firestore analytics コレクションに書き込む。
    エラーが発生しても例外は上位に伝播させず、ログを出してサマリーを返す。
    """
    try:
        return _write(users, active_posts, anon_users, date_str, dau, total_users)
    except Exception as exc:
        logger.error("[analytics_writer] Firestore 書き込みエラー: %s", exc, exc_info=True)
        print(f"[analytics_writer] Firestore 書き込みエラー（スナップショット自体は完了済み）: {exc}")
        return {"error": str(exc)}


def _write(
    users: list,
    active_posts: list,
    anon_users: dict,
    date_str: str,
    dau: int,
    total_users: int,
) -> dict:
    from .firebase_client import FirebaseClient
    from google.api_core.exceptions import NotFound  # noqa: F401

    db = FirebaseClient.db()
    today = datetime.date.fromisoformat(date_str)
    date_display = f"{today.day:02d}-{today.month:02d}-{today.year}"   # DD-MM-YYYY
    month_display = f"{today.month:02d}-{today.year}"                   # MM-YYYY

    # SQLite から前日スナップショットを取得（追加 Firestore 読み取りなし）
    prev_snapshots = _get_prev_snapshots(date_str)

    # 初回見取り日の登録と取得
    for anon in anon_users.values():
        ensure_user_first_seen(anon["anon_user_id"], date_str)
    first_seen_dates = get_all_first_seen_dates()

    # 前回の投稿同期タイムスタンプ（これより古い投稿は書き込みスキップ）
    last_sync_at = get_analytics_meta("last_post_sync_at") or ""
    new_last_sync_at = last_sync_at

    batch_ops: list = []  # (op_type, doc_ref, data) のリスト
    profile_writes = 0
    post_writes = 0
    streak_writes = 0
    task_writes = 0

    # ── 1. ユーザープロフィール / イベント ──────────────────────────────
    for user in users:
        uid = user["uid"]
        anon = anon_users.get(uid)
        if anon is None:
            continue

        anon_id = anon["anon_user_id"]
        prev = prev_snapshots.get(anon_id)

        curr_streak = anon["streak"]
        curr_protections = anon.get("streak_protections", 0)
        curr_tasks = sorted(anon["tasks"])
        curr_followers = anon["followers_count"]

        prev_streak = prev["streak"] if prev else None
        prev_protections = prev.get("streak_protections") if prev else None
        prev_tasks_json = prev.get("task_names") if prev else None
        prev_tasks = json.loads(prev_tasks_json) if prev_tasks_json else None

        is_active_today = (anon.get("last_posted_date") == date_str)
        profile_changed = (
            prev is None
            or curr_streak != prev_streak
            or curr_tasks != (sorted(prev_tasks) if prev_tasks is not None else None)
            or curr_followers != (prev["followers_count"] if prev else None)
        )

        if profile_changed or is_active_today:
            sign_up = first_seen_dates.get(anon_id, date_str)
            profile_data = {
                "sign_up_date": _to_display_date(sign_up),
                "age": _calc_age(anon.get("birth_year"), today.year),
                "gender": anon.get("gender") or None,
                "job": anon.get("occupation") or None,
                "followers": curr_followers,
                "tasks": curr_tasks,
                "monthly_active_rate": _calc_monthly_active_rate(anon_id, date_str),
                "updated_at": datetime.datetime.now(datetime.timezone.utc),
            }
            if prev is None:
                profile_data["persona"] = None

            doc_ref = db.collection("analytics_users").document(anon_id)
            batch_ops.append(("set_merge", doc_ref, profile_data))
            profile_writes += 1

        # ストリークイベント検出
        streak_event = _detect_streak_event(
            curr_streak, curr_protections, prev_streak, prev_protections
        )
        if streak_event:
            streak_event["date"] = date_display
            streak_ref = (
                db.collection("analytics_users").document(anon_id)
                .collection("streaks").document(date_display)
            )
            batch_ops.append(("set", streak_ref, streak_event))
            streak_writes += 1

        # タスク変化イベント検出（前日データがある場合のみ）
        if prev_tasks is not None and curr_tasks != sorted(prev_tasks):
            for ev in _detect_task_events(curr_tasks, prev_tasks, date_str):
                ev_id = f"{date_str}_{ev['action']}_{ev['task_name'].replace(' ', '_')}"
                task_ref = (
                    db.collection("analytics_users").document(anon_id)
                    .collection("tasks").document(ev_id)
                )
                batch_ops.append(("set", task_ref, ev))
                task_writes += 1

    # ── 2. 新規投稿（前回同期時刻以降のみ） ────────────────────────────
    for post in active_posts:
        created_iso = _ts_to_iso(post.get("createdAt"))
        if created_iso and created_iso <= last_sync_at:
            continue

        uid = post.get("userId", "")
        anon_id = anonymize_uid(uid)
        post_id = post.get("post_id", "")

        dt = _parse_dt(created_iso)
        posted_at = dt.strftime("%d-%m-%Y %H:%M") if dt else date_display

        post_data = {
            "task_name": post.get("taskName", ""),
            "posted_at": posted_at,
            "reactions": post.get("reactionCount", 0),
            "comments": post.get("caption") or None,
        }
        post_ref = (
            db.collection("analytics_users").document(anon_id)
            .collection("posts").document(post_id)
        )
        batch_ops.append(("set", post_ref, post_data))
        post_writes += 1

        if created_iso and created_iso > new_last_sync_at:
            new_last_sync_at = created_iso

    # ── 3. バッチ実行 ───────────────────────────────────────────────────
    _execute_batches(db, batch_ops)

    # ── 4. DAU / MAU 更新（バッチ外: update 失敗時に set にフォールバック） ──
    mau = _calc_mau(date_str)
    _upsert_stat_entry(db, "dau", date_display, dau)
    _upsert_stat_entry(db, "mau", month_display, mau)

    # ── 5. SQLite メタ更新 ──────────────────────────────────────────────
    if new_last_sync_at > last_sync_at:
        set_analytics_meta("last_post_sync_at", new_last_sync_at)

    summary = {
        "profile_writes": profile_writes,
        "post_writes": post_writes,
        "streak_event_writes": streak_writes,
        "task_event_writes": task_writes,
    }
    print(f"[analytics_writer] Firestore 書き込み完了: {summary}")
    return summary


# ── ヘルパー ────────────────────────────────────────────────────────────


def _get_prev_snapshots(today_str: str) -> dict:
    """前日の user_snapshots を anon_user_id → dict で返す。前日なければ最新日を使う。"""
    today = datetime.date.fromisoformat(today_str)
    yesterday = (today - datetime.timedelta(days=1)).isoformat()
    with get_conn() as conn:
        rows = conn.execute(
            """SELECT anon_user_id, streak, streak_protections, task_names, followers_count
               FROM user_snapshots WHERE date = ?""",
            (yesterday,),
        ).fetchall()
        if not rows:
            rows = conn.execute(
                """SELECT anon_user_id, streak, streak_protections, task_names, followers_count
                   FROM user_snapshots
                   WHERE date = (SELECT MAX(date) FROM user_snapshots WHERE date < ?)""",
                (today_str,),
            ).fetchall()
    return {r["anon_user_id"]: dict(r) for r in rows}


def _detect_streak_event(
    curr_streak: int,
    curr_protections: int,
    prev_streak: Optional[int],
    prev_protections: Optional[int],
) -> Optional[dict]:
    if prev_streak is None:
        return None
    # streak が減少 → break
    if curr_streak < prev_streak:
        return {"streak": curr_streak, "action": "break"}
    # streak は維持されたが streakProtections が減少 → shield 使用
    if (
        prev_protections is not None
        and curr_protections < prev_protections
        and curr_streak >= prev_streak
    ):
        return {"streak": curr_streak, "action": "shield"}
    return None


def _detect_task_events(curr_tasks: list, prev_tasks: list, date_str: str) -> list:
    curr_set = set(curr_tasks)
    prev_set = set(prev_tasks)
    today = datetime.date.fromisoformat(date_str)
    timestamp = f"{today.year}-{today.month:02d}-{today.day:02d} 00:00"
    events = []
    for t in sorted(curr_set - prev_set):
        events.append({"timestamp": timestamp, "action": "add", "task_name": t})
    for t in sorted(prev_set - curr_set):
        events.append({"timestamp": timestamp, "action": "delete", "task_name": t})
    return events


def _calc_monthly_active_rate(anon_id: str, date_str: str) -> Optional[float]:
    """今月の投稿日数 / 今月の経過日数（post_snapshots から算出）。"""
    year, month, day = date_str.split("-")
    day_of_month = int(day)
    with get_conn() as conn:
        row = conn.execute(
            "SELECT COUNT(DISTINCT date) as active_days FROM post_snapshots"
            " WHERE anon_user_id = ? AND date LIKE ?",
            (anon_id, f"{year}-{month}-%"),
        ).fetchone()
    active_days = row["active_days"] if row else 0
    return round(active_days / day_of_month, 2) if day_of_month > 0 else None


def _calc_mau(date_str: str) -> int:
    """今月に1件以上投稿した distinct ユーザー数（post_snapshots から算出）。"""
    year, month, _ = date_str.split("-")
    with get_conn() as conn:
        row = conn.execute(
            "SELECT COUNT(DISTINCT anon_user_id) as mau FROM post_snapshots WHERE date LIKE ?",
            (f"{year}-{month}-%",),
        ).fetchone()
    return row["mau"] if row else 0


def _calc_age(birth_year: Optional[int], current_year: int) -> Optional[int]:
    if birth_year is None:
        return None
    return current_year - birth_year


def _to_display_date(iso_date: str) -> str:
    """YYYY-MM-DD → DD-MM-YYYY 変換。失敗時はそのまま返す。"""
    try:
        d = datetime.date.fromisoformat(iso_date)
        return f"{d.day:02d}-{d.month:02d}-{d.year}"
    except Exception:
        return iso_date


def _ts_to_iso(ts) -> str:
    if ts is None:
        return ""
    if hasattr(ts, "isoformat"):
        return ts.isoformat()
    if hasattr(ts, "_seconds"):
        return datetime.datetime.fromtimestamp(
            ts._seconds, tz=datetime.timezone.utc
        ).isoformat()
    return str(ts)


def _parse_dt(iso_str: str) -> Optional[datetime.datetime]:
    if not iso_str:
        return None
    try:
        return datetime.datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
    except Exception:
        return None


def _execute_batches(db, ops: list) -> None:
    """ops を _MAX_BATCH 件ずつ Firestore batch に分割してコミットする。"""
    if not ops:
        return
    for i in range(0, len(ops), _MAX_BATCH):
        chunk = ops[i: i + _MAX_BATCH]
        batch = db.batch()
        for item in chunk:
            op_type, ref, data = item
            if op_type == "set_merge":
                batch.set(ref, data, merge=True)
            else:
                batch.set(ref, data)
        batch.commit()


def _upsert_stat_entry(db, doc_name: str, key: str, value: int) -> None:
    """analytics_app_state/{doc_name} の entries.{key} を upsert する。"""
    from google.api_core.exceptions import NotFound

    ref = db.collection("analytics_app_state").document(doc_name)
    try:
        ref.update({f"entries.{key}": value})
    except NotFound:
        ref.set({"entries": {key: value}})

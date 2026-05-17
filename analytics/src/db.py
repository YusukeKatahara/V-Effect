import os
import sqlite3
from contextlib import contextmanager
from typing import Optional

import pandas as pd

DB_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "data", "veffect_analytics.db"))

CREATE_TABLES_SQL = """
CREATE TABLE IF NOT EXISTS daily_app_stats (
    date TEXT PRIMARY KEY,
    total_users INTEGER,
    daily_active_users INTEGER,
    total_posts_today INTEGER,
    captured_at TEXT
);

CREATE TABLE IF NOT EXISTS post_snapshots (
    post_id TEXT PRIMARY KEY,
    anon_user_id TEXT,
    task_name_original TEXT,
    task_name_translated TEXT,
    category_large TEXT,
    category_medium TEXT,
    reaction_count INTEGER,
    emoji_reaction_count INTEGER,
    follower_count INTEGER,
    reactions_per_follower REAL,
    created_at TEXT,
    date TEXT
);

CREATE TABLE IF NOT EXISTS user_snapshots (
    date TEXT,
    anon_user_id TEXT,
    streak INTEGER,
    max_streak INTEGER,
    following_count INTEGER,
    followers_count INTEGER,
    primary_user_type TEXT,
    last_posted_date TEXT,
    streak_protections INTEGER DEFAULT 0,
    task_names TEXT DEFAULT NULL,
    PRIMARY KEY (date, anon_user_id)
);

CREATE TABLE IF NOT EXISTS task_category_cache (
    task_name_original TEXT PRIMARY KEY,
    task_name_translated TEXT,
    category_large TEXT,
    category_medium TEXT,
    classified_at TEXT,
    is_manual INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS analytics_sync_meta (
    key TEXT PRIMARY KEY,
    value TEXT
);

CREATE TABLE IF NOT EXISTS analytics_user_meta (
    anon_user_id TEXT PRIMARY KEY,
    first_seen_date TEXT
);
"""


def init_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    with sqlite3.connect(DB_PATH) as conn:
        conn.executescript(CREATE_TABLES_SQL)
        # 既存DBへの is_manual カラム追加（既にある場合は無視）
        try:
            conn.execute("ALTER TABLE task_category_cache ADD COLUMN is_manual INTEGER DEFAULT 0")
        except Exception:
            pass
        # 既存DBへの streak_protections / task_names カラム追加
        try:
            conn.execute("ALTER TABLE user_snapshots ADD COLUMN streak_protections INTEGER DEFAULT 0")
        except Exception:
            pass
        try:
            conn.execute("ALTER TABLE user_snapshots ADD COLUMN task_names TEXT DEFAULT NULL")
        except Exception:
            pass
        conn.commit()


@contextmanager
def get_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def get_analytics_meta(key: str) -> Optional[str]:
    with get_conn() as conn:
        row = conn.execute(
            "SELECT value FROM analytics_sync_meta WHERE key = ?", (key,)
        ).fetchone()
    return row["value"] if row else None


def set_analytics_meta(key: str, value: str) -> None:
    with get_conn() as conn:
        conn.execute(
            "INSERT OR REPLACE INTO analytics_sync_meta (key, value) VALUES (?, ?)",
            (key, value),
        )


def ensure_user_first_seen(anon_user_id: str, date_str: str) -> None:
    with get_conn() as conn:
        conn.execute(
            "INSERT OR IGNORE INTO analytics_user_meta (anon_user_id, first_seen_date) VALUES (?, ?)",
            (anon_user_id, date_str),
        )


def get_all_first_seen_dates() -> dict:
    with get_conn() as conn:
        rows = conn.execute(
            "SELECT anon_user_id, first_seen_date FROM analytics_user_meta"
        ).fetchall()
    return {r["anon_user_id"]: r["first_seen_date"] for r in rows}


def read_df(query: str, params: tuple = ()) -> pd.DataFrame:
    """SQLクエリの結果をDataFrameとして返す。読み取り専用操作用。"""
    conn = sqlite3.connect(DB_PATH)
    try:
        return pd.read_sql_query(query, conn, params=params)
    finally:
        conn.close()

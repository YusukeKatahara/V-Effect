import os
import sqlite3
from contextlib import contextmanager

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


def read_df(query: str, params: tuple = ()) -> pd.DataFrame:
    """SQLクエリの結果をDataFrameとして返す。読み取り専用操作用。"""
    conn = sqlite3.connect(DB_PATH)
    try:
        return pd.read_sql_query(query, conn, params=params)
    finally:
        conn.close()

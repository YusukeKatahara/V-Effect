import datetime
import os
from typing import Optional

import firebase_admin
from dotenv import load_dotenv
from firebase_admin import credentials, firestore

load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

_ANALYTICS_DIR = os.path.join(os.path.dirname(__file__), "..")
_DEFAULT_KEY_PATH = os.path.join(_ANALYTICS_DIR, "config", "firebase_admin_key.json")


class FirebaseClient:
    _app = None
    _db = None

    @classmethod
    def _init(cls):
        if cls._app is not None:
            return
        key_path = os.getenv("FIREBASE_ADMIN_KEY_PATH", _DEFAULT_KEY_PATH)
        if not os.path.exists(key_path):
            raise FileNotFoundError(
                f"Firebase Admin SDK キーが見つかりません: {key_path}\n"
                "Firebase Console > プロジェクトの設定 > サービスアカウント > "
                "「新しい秘密鍵を生成」でJSONをダウンロードし、analytics/config/firebase_admin_key.json に配置してください。"
            )
        try:
            # 既に initialize_app() 済みの場合（Streamlit のページ遷移など）はそのまま使う
            cls._app = firebase_admin.get_app()
        except ValueError:
            cred = credentials.Certificate(key_path)
            cls._app = firebase_admin.initialize_app(cred)
        cls._db = firestore.client()

    @classmethod
    def db(cls):
        cls._init()
        return cls._db

    @classmethod
    def fetch_all_users(cls) -> list[dict]:
        docs = cls.db().collection("users").stream()
        result = []
        for doc in docs:
            data = doc.to_dict() or {}
            data["uid"] = doc.id
            result.append(data)
        return result

    @classmethod
    def fetch_all_posts(cls) -> list[dict]:
        """投稿を全件取得する（Firestore読み取りコストに注意）。"""
        docs = cls.db().collection("posts").stream()
        result = []
        for doc in docs:
            data = doc.to_dict() or {}
            data["post_id"] = doc.id
            result.append(data)
        return result

    @classmethod
    def fetch_posts_since(cls, days: int = 90) -> list[dict]:
        """直近N日分の投稿のみ取得する。Firestore読み取りコスト削減のため全件取得を避ける。"""
        since = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=days)
        docs = (
            cls.db()
            .collection("posts")
            .where("createdAt", ">=", since)
            .stream()
        )
        result = []
        for doc in docs:
            data = doc.to_dict() or {}
            data["post_id"] = doc.id
            result.append(data)
        return result

    @classmethod
    def fetch_action_logs(
        cls,
        days: Optional[int] = None,
        event_name: Optional[str] = None,
    ) -> list[dict]:
        """action_logs（行動ログ）を取得する。

        - days 指定時は clientTimestamp で直近N日に限定（全件取得による読み取りコスト増を防ぐ）
        - event_name 指定時は eventName で絞り込む
        """
        query = cls.db().collection("action_logs")
        if days is not None:
            since = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=days)
            query = query.where("clientTimestamp", ">=", since)
        if event_name:
            query = query.where("eventName", "==", event_name)
        result = []
        for doc in query.stream():
            data = doc.to_dict() or {}
            data["doc_id"] = doc.id
            result.append(data)
        return result

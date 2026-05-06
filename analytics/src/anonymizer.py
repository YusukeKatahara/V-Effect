import hashlib
import hmac
import os

from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

_SALT = os.getenv("ANONYMIZER_SALT", "default_dev_salt_change_in_production")


def anonymize_uid(uid: str) -> str:
    digest = hmac.new(_SALT.encode(), uid.encode(), hashlib.sha256).hexdigest()
    return digest[:16]


def anonymize_user(user_doc: dict) -> dict:
    """Firestoreのusersドキュメントから分析に不要な個人情報を除去する。"""
    birth_year = None
    if user_doc.get("birthDate"):
        try:
            birth_year = int(str(user_doc["birthDate"])[:4])
        except (ValueError, TypeError):
            pass

    return {
        "anon_user_id": anonymize_uid(user_doc["uid"]),
        "birth_year": birth_year,
        "occupation": user_doc.get("occupation"),
        "gender": user_doc.get("gender"),
        "streak": user_doc.get("streak", 0),
        "max_streak": user_doc.get("maxStreak", 0),
        "streak_protections": user_doc.get("streakProtections", 0),
        "last_posted_date": user_doc.get("lastPostedDate"),
        "following_count": len(user_doc.get("following", [])),
        "followers_count": len(user_doc.get("followers", [])),
        "tasks": [
            t.get("title", "") if isinstance(t, dict) else str(t)
            for t in (user_doc.get("tasks") or [])
            if t
        ],
        "is_private": user_doc.get("isPrivateAccount", False),
    }

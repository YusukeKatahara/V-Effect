import datetime
import glob
import json
import os

import pandas as pd
import plotly.graph_objects as go

_ANALYTICS_DIR = os.path.join(os.path.dirname(__file__), "..")
_RAW_DIR = os.path.join(_ANALYTICS_DIR, "data", "raw")
_OUT_DIR = os.path.join(_ANALYTICS_DIR, "data", "analysis")

JST = datetime.timezone(datetime.timedelta(hours=9))


def load_latest_json(collection: str) -> list[dict]:
    pattern = os.path.join(_RAW_DIR, f"{collection}_*.json")
    files = sorted(glob.glob(pattern))
    if not files:
        raise FileNotFoundError(f"{collection} の JSON が見つかりません: {pattern}")
    path = files[-1]
    print(f"[utils] 読み込み: {os.path.basename(path)}")
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def ts_to_dt(value) -> datetime.datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime.datetime):
        return value
    if isinstance(value, str):
        try:
            s = value.replace("Z", "+00:00")
            return datetime.datetime.fromisoformat(s)
        except Exception:
            return None
    if isinstance(value, dict):
        # Firestore Timestamp が {"_seconds": N, "_nanoseconds": N} 形式でシリアライズされた場合
        if "_seconds" in value:
            return datetime.datetime.fromtimestamp(value["_seconds"], tz=datetime.timezone.utc)
    return None


def to_jst(dt: datetime.datetime) -> datetime.datetime:
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=datetime.timezone.utc)
    return dt.astimezone(JST)


def save_csv(df: pd.DataFrame, name: str) -> str:
    os.makedirs(_OUT_DIR, exist_ok=True)
    path = os.path.join(_OUT_DIR, f"{name}.csv")
    df.to_csv(path, index=False, encoding="utf-8-sig")
    print(f"[utils] CSV 保存: {path}")
    return path


def save_figure(fig: go.Figure, name: str) -> str:
    os.makedirs(_OUT_DIR, exist_ok=True)
    path = os.path.join(_OUT_DIR, f"{name}.html")
    fig.write_html(path)
    print(f"[utils] HTML 保存: {path}")
    return path


def save_text(text: str, name: str) -> str:
    os.makedirs(_OUT_DIR, exist_ok=True)
    path = os.path.join(_OUT_DIR, f"{name}.txt")
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"[utils] TXT 保存: {path}")
    return path


def days_since(date_str: str, today: datetime.date | None = None) -> int | None:
    if not date_str:
        return None
    today = today or datetime.date.today()
    try:
        d = datetime.date.fromisoformat(date_str[:10])
        return (today - d).days
    except Exception:
        return None

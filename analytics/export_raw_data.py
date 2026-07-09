"""Firestoreの action_logs / posts / users から生データを取得してローカルに保存するスクリプト。

使い方（analytics ディレクトリ内で実行）:
  python export_raw_data.py                              # 全コレクション・全件を JSON で保存
  python export_raw_data.py --collections users posts    # 指定コレクションのみ
  python export_raw_data.py --days 30                    # 直近30日分のみ（posts / action_logs）
  python export_raw_data.py --format csv                 # CSV 形式で保存（Excel で開ける BOM 付き UTF-8）
  python export_raw_data.py --format both               # JSON と CSV の両方を保存
  python export_raw_data.py --out-dir data/raw           # 出力ディレクトリを指定

出力先（デフォルト）:
  analytics/data/raw/<collection>_YYYYMMDD_HHMMSS.json
"""

import argparse
import datetime
import json
import os
import sys

import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from src.firebase_client import FirebaseClient  # noqa: E402

_DEFAULT_OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "raw")
_RUN_TS = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")


class _FirestoreEncoder(json.JSONEncoder):
    """FirestoreのTimestamp / datetime をJSONシリアライズ可能な形式に変換する。"""

    def default(self, obj):
        if isinstance(obj, (datetime.datetime, datetime.date)):
            return obj.isoformat()
        if hasattr(obj, "_seconds"):  # google.cloud.firestore DatetimeWithNanoseconds
            return datetime.datetime.fromtimestamp(
                obj._seconds, tz=datetime.timezone.utc
            ).isoformat()
        return super().default(obj)


def _flatten_value(v):
    """CSVに書き出せるよう、ネストした値をISO文字列またはJSON文字列に変換する。"""
    if isinstance(v, datetime.datetime):
        return v.isoformat()
    if isinstance(v, datetime.date):
        return v.isoformat()
    if hasattr(v, "_seconds"):
        return datetime.datetime.fromtimestamp(
            v._seconds, tz=datetime.timezone.utc
        ).isoformat()
    if isinstance(v, (dict, list)):
        return json.dumps(v, ensure_ascii=False, cls=_FirestoreEncoder)
    return v


def _save_json(records: list[dict], collection: str, out_dir: str) -> str:
    path = os.path.join(out_dir, f"{collection}_{_RUN_TS}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(records, f, ensure_ascii=False, indent=2, cls=_FirestoreEncoder)
    return path


def _save_csv(records: list[dict], collection: str, out_dir: str) -> str:
    flat = [{k: _flatten_value(v) for k, v in r.items()} for r in records]
    df = pd.DataFrame(flat)
    path = os.path.join(out_dir, f"{collection}_{_RUN_TS}.csv")
    df.to_csv(path, index=False, encoding="utf-8-sig")
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description="Firestoreの生データをローカルにエクスポートする")
    parser.add_argument(
        "--collections",
        nargs="+",
        choices=["action_logs", "posts", "users"],
        default=["action_logs", "posts", "users"],
        metavar="COLLECTION",
        help="エクスポートするコレクション（action_logs / posts / users、デフォルト: 全件）",
    )
    parser.add_argument(
        "--days",
        type=int,
        default=None,
        help="直近N日分のみ取得（posts / action_logs に適用。未指定なら全件）",
    )
    parser.add_argument(
        "--format",
        choices=["json", "csv", "both"],
        default="json",
        help="出力フォーマット（デフォルト: json）",
    )
    parser.add_argument(
        "--out-dir",
        type=str,
        default=_DEFAULT_OUT_DIR,
        help=f"出力ディレクトリ（デフォルト: {_DEFAULT_OUT_DIR}）",
    )
    args = parser.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)

    for collection in args.collections:
        print(f"\n[export] {collection} を取得中...")

        if collection == "users":
            records = FirebaseClient.fetch_all_users()
        elif collection == "posts":
            if args.days is not None:
                records = FirebaseClient.fetch_posts_since(days=args.days)
            else:
                records = FirebaseClient.fetch_all_posts()
        else:  # action_logs
            records = FirebaseClient.fetch_action_logs(days=args.days)

        print(f"[export] {len(records)} 件取得")

        if not records:
            print(f"[export] {collection}: データが 0 件のためスキップします")
            continue

        if args.format in ("json", "both"):
            path = _save_json(records, collection, args.out_dir)
            print(f"[export] JSON -> {path}")

        if args.format in ("csv", "both"):
            path = _save_csv(records, collection, args.out_dir)
            print(f"[export] CSV  -> {path}")

    print(f"\n[export] 完了（出力先: {args.out_dir}）")


if __name__ == "__main__":
    main()

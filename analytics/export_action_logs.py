"""action_logs（行動ログ）を Firestore から取得して CSV に保存する CLI スクリプト。

設計（analytics_framework.md 準拠）:
  - action_logs は uid + 可変パラメータのみを保持する正規化済みデータ。
  - 静的属性（生年・性別・職業・ストリーク等）は users コレクション側にあるため、
    --join-users で uid を JOIN して 1 枚の CSV にまとめられる。
  - parameters マップは param_* 列にフラット展開する。
  - Timestamp は ISO8601 文字列に変換する（clientTimestamp = イベント発生時刻 / timestamp = 書き込み時刻）。

事前準備:
  1. analytics/config/firebase_admin_key.json にサービスアカウント鍵を配置
     （Firebase Console > プロジェクトの設定 > サービスアカウント > 新しい秘密鍵を生成）
  2. 依存インストール:  pip install -r requirements.txt

使い方（analytics ディレクトリ内で実行）:
  python export_action_logs.py                         # 全件を data/action_logs.csv に出力
  python export_action_logs.py --days 30               # 直近30日分のみ（読み取りコスト削減）
  python export_action_logs.py --event reaction_sent   # 特定イベントのみ
  python export_action_logs.py --join-users            # users の静的属性を uid で JOIN
  python export_action_logs.py --anonymize             # uid を匿名化（既存パイプラインと同じソルト）
  python export_action_logs.py --out data/my_logs.csv  # 出力先を指定
"""

import argparse
import datetime
import os
import sys

import pandas as pd

# src パッケージを import できるようにする
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from src.anonymizer import anonymize_uid, anonymize_user  # noqa: E402
from src.firebase_client import FirebaseClient  # noqa: E402

_DEFAULT_OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "action_logs.csv")


def _ts_to_iso(value) -> str:
    """Firestore の Timestamp を ISO8601 文字列に変換する。"""
    if value is None:
        return ""
    if hasattr(value, "isoformat"):
        return value.isoformat()
    if hasattr(value, "_seconds"):
        return datetime.datetime.fromtimestamp(value._seconds).isoformat()
    return str(value)


def main() -> None:
    parser = argparse.ArgumentParser(description="action_logs を CSV にエクスポートする")
    parser.add_argument("--days", type=int, default=None,
                        help="直近N日分のみ取得（clientTimestamp 基準。未指定なら全件）")
    parser.add_argument("--event", type=str, default=None,
                        help="eventName で絞り込む（例: reaction_sent）")
    parser.add_argument("--join-users", action="store_true",
                        help="users コレクションの静的属性を uid で JOIN する")
    parser.add_argument("--anonymize", action="store_true",
                        help="uid と param_target_uid を匿名化する（既存パイプラインと同一ソルト）")
    parser.add_argument("--out", type=str, default=_DEFAULT_OUT,
                        help=f"出力先 CSV パス（既定: {_DEFAULT_OUT}）")
    args = parser.parse_args()

    print("[export] action_logs を取得中...")
    logs = FirebaseClient.fetch_action_logs(days=args.days, event_name=args.event)
    if not logs:
        print("[export] 対象データが 0 件でした。新バージョンのアプリで行動ログが生成されているか確認してください。")
        return
    print(f"[export] {len(logs)} 件取得")

    # parameters マップを param_* 列に展開
    df = pd.json_normalize(logs)
    df.columns = [c.replace("parameters.", "param_") for c in df.columns]

    # Timestamp を ISO 文字列へ
    for col in ("clientTimestamp", "timestamp"):
        if col in df.columns:
            df[col] = df[col].apply(_ts_to_iso)

    # users の静的属性を uid で JOIN（匿名化より前に、生 uid で結合する）
    if args.join_users and "uid" in df.columns:
        print("[export] users を取得して JOIN 中...")
        users = FirebaseClient.fetch_all_users()
        user_rows = []
        for u in users:
            a = anonymize_user(u)
            user_rows.append({
                "uid": u["uid"],
                "user_birth_year": a["birth_year"],
                "user_gender": a["gender"],
                "user_occupation": a["occupation"],
                "user_streak": a["streak"],
                "user_max_streak": a["max_streak"],
                "user_followers_count": a["followers_count"],
                "user_following_count": a["following_count"],
            })
        df = df.merge(pd.DataFrame(user_rows), on="uid", how="left")

    # 匿名化（JOIN 後に実施。uid はそのままだと個人特定につながるため）
    if args.anonymize:
        for col in ("uid", "param_target_uid"):
            if col in df.columns:
                df[col] = df[col].apply(
                    lambda x: anonymize_uid(x) if isinstance(x, str) and x else x
                )

    # メタ列を先頭に並べ替え（残りはそのまま後ろへ）
    meta_first = [c for c in ("doc_id", "uid", "eventName", "clientTimestamp",
                              "timestamp", "appVersion", "platform") if c in df.columns]
    others = [c for c in df.columns if c not in meta_first]
    df = df[meta_first + others]

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    # Excel で日本語が文字化けしないよう BOM 付き UTF-8
    df.to_csv(args.out, index=False, encoding="utf-8-sig")
    print(f"[export] {len(df)} 行を書き出しました -> {args.out}")


if __name__ == "__main__":
    main()

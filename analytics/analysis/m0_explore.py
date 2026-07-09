import os
import sys
from collections import Counter, defaultdict

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from analysis.utils import load_latest_json, save_text, ts_to_dt

import pandas as pd


def explore_users(users: list[dict]) -> str:
    lines = [f"=== users ({len(users)} 件) ===\n"]

    # フィールド非null率
    all_keys = set()
    for u in users:
        all_keys.update(u.keys())
    lines.append("-- フィールド非null率 --")
    for k in sorted(all_keys):
        non_null = sum(1 for u in users if u.get(k) not in (None, "", [], {}))
        lines.append(f"  {k}: {non_null}/{len(users)} ({non_null/len(users)*100:.1f}%)")

    # streak 分布
    streaks = [u.get("streak", 0) or 0 for u in users]
    s = pd.Series(streaks)
    lines.append(f"\n-- streak 分布 --\n{s.describe().to_string()}")

    # maxStreak 分布
    maxs = [u.get("maxStreak", 0) or 0 for u in users]
    lines.append(f"\n-- maxStreak 分布 --\n{pd.Series(maxs).describe().to_string()}")

    # streakProtections 分布
    prots = [u.get("streakProtections", 0) or 0 for u in users]
    lines.append(f"\n-- streakProtections 分布 --\n{pd.Series(prots).describe().to_string()}")

    # lastPostedDate の範囲
    dates = [u.get("lastPostedDate") for u in users if u.get("lastPostedDate")]
    if dates:
        lines.append(f"\n-- lastPostedDate 範囲 --\n  最古: {min(dates)}  最新: {max(dates)}")

    # tasks 件数分布
    task_counts = [len(u.get("tasks") or []) for u in users]
    tc = Counter(task_counts)
    lines.append("\n-- tasks 件数分布 --")
    for k in sorted(tc):
        lines.append(f"  {k}件: {tc[k]}人")

    # followers / following 長さ分布
    fol_counts = [len(u.get("followers") or []) for u in users]
    ing_counts = [len(u.get("following") or []) for u in users]
    lines.append(f"\n-- followers 長さ分布 --\n{pd.Series(fol_counts).describe().to_string()}")
    lines.append(f"\n-- following 長さ分布 --\n{pd.Series(ing_counts).describe().to_string()}")

    # isPrivateAccount
    private = sum(1 for u in users if u.get("isPrivateAccount"))
    lines.append(f"\n-- isPrivateAccount --\n  True: {private}  False: {len(users)-private}")

    # gender / occupation
    genders = Counter(u.get("gender") or "未設定" for u in users)
    lines.append(f"\n-- gender 分布 --\n  {dict(genders)}")
    occs = Counter(u.get("occupation") or "未設定" for u in users)
    lines.append(f"\n-- occupation 分布（上位10） --")
    for k, v in occs.most_common(10):
        lines.append(f"  {k}: {v}")

    return "\n".join(lines)


def explore_posts(posts: list[dict]) -> str:
    lines = [f"\n=== posts ({len(posts)} 件) ===\n"]

    all_keys = set()
    for p in posts:
        all_keys.update(p.keys())
    lines.append("-- フィールド非null率 --")
    for k in sorted(all_keys):
        non_null = sum(1 for p in posts if p.get(k) not in (None, "", [], {}))
        lines.append(f"  {k}: {non_null}/{len(posts)} ({non_null/len(posts)*100:.1f}%)")

    # createdAt 範囲
    dts = [ts_to_dt(p.get("createdAt")) for p in posts]
    dts = [d for d in dts if d]
    if dts:
        lines.append(f"\n-- createdAt 範囲 --\n  最古: {min(dts)}  最新: {max(dts)}")

    # reactionCount 分布
    rc = [p.get("reactionCount", 0) or 0 for p in posts]
    lines.append(f"\n-- reactionCount 分布 --\n{pd.Series(rc).describe().to_string()}")

    # emojiReactedUserIds 長さ分布
    em = [len(p.get("emojiReactedUserIds") or []) for p in posts]
    lines.append(f"\n-- emojiReactedUserIds 長さ分布 --\n{pd.Series(em).describe().to_string()}")

    # ユニーク投稿者数
    users_who_posted = len({p.get("userId") for p in posts if p.get("userId")})
    lines.append(f"\n-- 投稿したことがあるユニークユーザー数: {users_who_posted} 人 --")

    # taskName 上位20
    task_counts = Counter(p.get("taskName", "") for p in posts)
    lines.append("\n-- taskName 上位20 --")
    for t, c in task_counts.most_common(20):
        lines.append(f"  {t}: {c}件")

    return "\n".join(lines)


def explore_action_logs(logs: list[dict]) -> str:
    lines = [f"\n=== action_logs ({len(logs)} 件) ===\n"]

    # eventName 種類と件数
    event_counts = Counter(l.get("eventName", "unknown") for l in logs)
    lines.append("-- eventName 一覧（件数順） --")
    for e, c in event_counts.most_common():
        lines.append(f"  {e}: {c}件")

    # clientTimestamp 範囲
    dts = [ts_to_dt(l.get("clientTimestamp")) for l in logs]
    dts = [d for d in dts if d]
    if dts:
        lines.append(f"\n-- clientTimestamp 範囲 --\n  最古: {min(dts)}  最新: {max(dts)}")

    # uid ユニーク数
    uids = {l.get("uid") for l in logs if l.get("uid")}
    lines.append(f"\n-- ユニークユーザー数（行動ログあり）: {len(uids)} 人 --")

    # platform 別
    plat = Counter(l.get("platform", "unknown") for l in logs)
    lines.append(f"\n-- platform 別 --\n  {dict(plat)}")

    # appVersion 別
    ver = Counter(l.get("appVersion", "unknown") for l in logs)
    lines.append("\n-- appVersion 別 --")
    for v, c in ver.most_common():
        lines.append(f"  {v}: {c}件")

    # 各 eventName の parameters キー
    event_param_keys: dict[str, set] = defaultdict(set)
    for l in logs:
        en = l.get("eventName", "unknown")
        params = l.get("parameters") or {}
        if isinstance(params, dict):
            event_param_keys[en].update(params.keys())
    lines.append("\n-- 各 eventName の parameters キー --")
    for e in sorted(event_param_keys):
        lines.append(f"  {e}: {sorted(event_param_keys[e])}")

    return "\n".join(lines)


def main():
    users = load_latest_json("users")
    posts = load_latest_json("posts")
    logs = load_latest_json("action_logs")

    report = ""
    report += explore_users(users)
    report += explore_posts(posts)
    report += explore_action_logs(logs)

    sys.stdout.buffer.write(report.encode("utf-8", errors="replace"))
    sys.stdout.buffer.write(b"\n")
    save_text(report, "m0_schema_report")


if __name__ == "__main__":
    main()

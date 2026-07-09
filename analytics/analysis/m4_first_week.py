import datetime
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from analysis.utils import days_since, load_latest_json, save_csv, save_figure, ts_to_dt

import pandas as pd
import plotly.express as px

TODAY = datetime.date.today()
WINDOW = 1


def build_user_post_dates(posts):
    user_post_dates = defaultdict(set)
    for p in posts:
        dt = ts_to_dt(p.get("createdAt"))
        uid = p.get("userId")
        if dt and uid:
            user_post_dates[uid].add(dt.date())
    return user_post_dates


def is_retained_d30(post_dates, activation):
    target = activation + datetime.timedelta(days=30)
    for delta in range(-WINDOW, WINDOW + 1):
        if target + datetime.timedelta(days=delta) in post_dates:
            return True
    return False


def main():
    posts = load_latest_json("posts")
    logs = load_latest_json("action_logs")

    user_post_dates = build_user_post_dates(posts)
    user_activation = {uid: min(dates) for uid, dates in user_post_dates.items() if dates}
    print(f"[M4] activation ユーザー数: {len(user_activation)}")

    # 各ユーザーの初週ログを抽出
    first_week_logs = defaultdict(list)
    for log in logs:
        uid = log.get("uid")
        activation = user_activation.get(uid)
        if activation is None:
            continue
        dt = ts_to_dt(log.get("clientTimestamp"))
        if dt is None:
            continue
        days_diff = (dt.date() - activation).days
        if 0 <= days_diff <= 6:
            first_week_logs[uid].append(log)

    print(f"[M4] 初週ログありユーザー: {len(first_week_logs)}人")

    # D30 継続判定（今日から30日以上前に activation したユーザーのみ）
    retained_uids, churned_uids = set(), set()
    for uid, activation in user_activation.items():
        if (TODAY - activation).days < 30:
            continue
        if is_retained_d30(user_post_dates[uid], activation):
            retained_uids.add(uid)
        else:
            churned_uids.add(uid)

    print(f"[M4] D30 評価対象: retained={len(retained_uids)}, churned={len(churned_uids)}")

    all_event_types = list({l.get("eventName") for l in logs if l.get("eventName")})

    # 特徴量抽出
    feature_rows = []
    for uid in (retained_uids | churned_uids):
        logs_u = first_week_logs.get(uid, [])
        active_dates = {ts_to_dt(l.get("clientTimestamp")).date()
                        for l in logs_u if ts_to_dt(l.get("clientTimestamp"))}
        row = {
            "uid": uid,
            "group": "継続（D30+）" if uid in retained_uids else "離脱",
            "total_events": len(logs_u),
            "unique_event_types": len({l.get("eventName") for l in logs_u}),
            "days_with_activity": len(active_dates),
        }
        for ev in all_event_types:
            row[f"ev_{ev}"] = sum(1 for l in logs_u if l.get("eventName") == ev)
        feature_rows.append(row)

    if not feature_rows:
        print("[M4] D30 評価対象ユーザーが不足しています（action_logs の期間が短い）")
        print("[M4] 代替: 全 action_logs ユーザーのイベント分布を出力します")
        _fallback_analysis(logs, all_event_types, user_activation)
        return

    df = pd.DataFrame(feature_rows)
    print("\n[M4] グループ別特徴量平均:")
    numeric_cols = [c for c in df.columns if c not in ("uid", "group")]
    print(df.groupby("group")[numeric_cols].mean().T.to_string())

    # グループ比較棒グラフ
    compare_cols = ["total_events", "days_with_activity", "unique_event_types"] + [f"ev_{e}" for e in all_event_types]
    melted = df.melt(id_vars=["uid", "group"], value_vars=[c for c in compare_cols if c in df.columns])
    avg = melted.groupby(["variable", "group"])["value"].mean().reset_index()
    fig_cmp = px.bar(
        avg, x="variable", y="value", color="group", barmode="group",
        title="初週行動比較: 継続ユーザー vs 離脱ユーザー",
        labels={"variable": "指標", "value": "平均値", "group": "グループ"},
    )
    fig_cmp.update_xaxes(tickangle=30)
    save_figure(fig_cmp, "m4_first_week_feature_comparison")

    # Magic moment: 各イベントの「実施あり」vs「なし」でのリテンション差分
    magic_rows = []
    for ev in all_event_types:
        col = f"ev_{ev}"
        if col not in df.columns:
            continue
        did = df[df[col] > 0]
        didnt = df[df[col] == 0]
        if len(did) < 2 or len(didnt) < 2:
            continue
        r_did = (did["group"] == "継続（D30+）").mean()
        r_didnt = (didnt["group"] == "継続（D30+）").mean()
        magic_rows.append({
            "eventName": ev,
            "did_d30_pct": round(r_did * 100, 1),
            "didnt_d30_pct": round(r_didnt * 100, 1),
            "retention_diff_pt": round((r_did - r_didnt) * 100, 1),
            "n_did": len(did),
        })

    if not magic_rows:
        print("\n[M4] magic moment 計算対象なし（サンプル不足）。フォールバック分析を実行します。")
        _fallback_analysis(logs, all_event_types, user_activation)
        return

    df_magic = pd.DataFrame(magic_rows)
    df_magic = df_magic.sort_values("retention_diff_pt", ascending=False)
    print("\n[M4] Magic moment（イベント別リテンション寄与度）:")
    print(df_magic.to_string(index=False))
    save_csv(df_magic, "m4_magic_moments")

    fig_magic = px.bar(
        df_magic, x="retention_diff_pt", y="eventName", orientation="h",
        title="初週イベント別 D30リテンション押上げ効果",
        labels={"eventName": "イベント名", "retention_diff_pt": "継続率差分 (pt)"},
        color="retention_diff_pt",
        color_continuous_scale="RdYlGn",
    )
    fig_magic.update_layout(yaxis={"categoryorder": "total ascending"})
    save_figure(fig_magic, "m4_magic_moments")

    save_csv(df.drop(columns=["uid"]), "m4_first_week_features")


def _fallback_analysis(logs, all_event_types, user_activation):
    """action_logs期間が短い場合の代替分析: 直近ユーザー別イベント分布"""
    rows = []
    uid_logs = defaultdict(list)
    for l in logs:
        uid = l.get("uid")
        if uid:
            uid_logs[uid].append(l)
    for uid, ulogs in uid_logs.items():
        row = {"uid": uid}
        for ev in all_event_types:
            row[ev] = sum(1 for l in ulogs if l.get("eventName") == ev)
        rows.append(row)
    df = pd.DataFrame(rows)
    print("\n[M4] ユーザー別イベント分布（直近11日）:")
    print(df.describe().to_string())
    save_csv(df, "m4_event_distribution_fallback")

    # イベント別ユニークユーザー数
    for ev in all_event_types:
        n = (df[ev] > 0).sum()
        pct = n / len(df) * 100 if len(df) > 0 else 0
        print(f"  {ev}: {n}/{len(df)} ({pct:.1f}%) のユーザーが実施")


if __name__ == "__main__":
    main()

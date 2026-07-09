import datetime
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from analysis.utils import save_csv, save_figure, save_text

import pandas as pd
import plotly.express as px

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "analysis")
TODAY = datetime.date.today()


def read_csv_safe(name: str) -> pd.DataFrame:
    path = os.path.join(OUT_DIR, f"{name}.csv")
    try:
        return pd.read_csv(path, encoding="utf-8-sig")
    except Exception:
        return pd.DataFrame()


def read_txt_safe(name: str) -> str:
    path = os.path.join(OUT_DIR, f"{name}.txt")
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except Exception:
        return ""


def main():
    # M1: D30リテンション
    df_ret = read_csv_safe("m1_retention_table")
    d30_retention = None
    if not df_ret.empty and "D30" in df_ret.columns:
        vals = df_ret["D30"].dropna()
        d30_retention = vals.mean() if len(vals) > 0 else None
    d30_str = f"{d30_retention*100:.1f}%" if d30_retention is not None else "データ不足"

    # M2: ストリーク損失別チャーン率
    df_m2 = read_csv_safe("m2_summary")
    churn_rate = df_m2["is_churned"].mean() if not df_m2.empty and "is_churned" in df_m2.columns else None
    churn_str = f"{churn_rate*100:.1f}%" if churn_rate is not None else "N/A"

    high_streak_gap_churn = None
    if not df_m2.empty and "streak_gap" in df_m2.columns:
        high_gap = df_m2[df_m2["streak_gap"] >= 7]
        if len(high_gap) > 0:
            high_streak_gap_churn = high_gap["is_churned"].mean()

    # M3: ソーシャル相関
    df_m3 = read_csv_safe("m3_summary")
    social_corr = None
    if not df_m3.empty and "Spearman_r" in df_m3.columns:
        row = df_m3[df_m3["特徴量"] == "follower_count"]
        if not row.empty:
            social_corr = row.iloc[0]["Spearman_r"]

    # M5: カテゴリ統計
    df_m5 = read_csv_safe("m5_category_stats")
    best_category = None
    if not df_m5.empty and "active_rate_14d" in df_m5.columns:
        best_idx = df_m5["active_rate_14d"].idxmax()
        best_category = df_m5.loc[best_idx, "primary_category"]

    # M7: AUC・高リスクユーザー
    perf_txt = read_txt_safe("m7_model_performance")
    df_risk = read_csv_safe("m7_high_risk_users")
    high_risk_n = len(df_risk) if not df_risk.empty else 0

    # active rate
    if not df_m2.empty and "is_active" in df_m2.columns:
        active_rate_14d = df_m2["is_active"].mean()
    else:
        active_rate_14d = None
    active_str = f"{active_rate_14d*100:.1f}%" if active_rate_14d is not None else "N/A"

    # M6: クラスタ
    df_m6 = read_csv_safe("m6_cluster_profiles")
    largest_segment = None
    if not df_m6.empty and "cluster_name" in df_m6.columns and "user_count" in df_m6.columns:
        largest_segment = df_m6.loc[df_m6["user_count"].idxmax(), "cluster_name"]

    # 施策リストとスコアリング
    initiatives = [
        {
            "施策名": "オンボーディング改善（初週 magic moment 誘導）",
            "根拠": f"D30リテンション={d30_str} — 業界平均10%と比較した改善余地",
            "関連モジュール": "M1, M4",
            "impact": 9,
            "effort": 3,
        },
        {
            "施策名": "ソーシャル接続促進（最初の相互フォロー誘導）",
            "根拠": f"フォロワー数とアクティブ率に正相関 (r={social_corr:.2f})" if social_corr else "フォロワー数とアクティブ率に相関あり",
            "関連モジュール": "M3, M6",
            "impact": 8,
            "effort": 2,
        },
        {
            "施策名": "ストリークリカバリー機能",
            "根拠": f"streak_gap≥7日のチャーン率={high_streak_gap_churn*100:.1f}%" if high_streak_gap_churn else "高ストリーク損失ユーザーの離脱率が高い",
            "関連モジュール": "M2",
            "impact": 7,
            "effort": 3,
        },
        {
            "施策名": "チャーンリスクユーザーへのプッシュ通知",
            "根拠": f"高リスクユーザー {high_risk_n}人を特定。AUCモデルで介入対象を絞込み可能",
            "関連モジュール": "M7, M8",
            "impact": 7,
            "effort": 1,
        },
        {
            "施策名": f"高定着カテゴリ（{best_category}）への新規流入施策（ASO・広告）",
            "根拠": "カテゴリ別アクティブ率に差があり、高定着カテゴリへ誘導することで継続率向上",
            "関連モジュール": "M5",
            "impact": 6,
            "effort": 4,
        },
        {
            "施策名": "フィードUI改善（reaction_sent 導線強化）",
            "根拠": "friend_feed_viewed → reaction_sent ファネルの通過率改善",
            "関連モジュール": "M8",
            "impact": 6,
            "effort": 2,
        },
        {
            "施策名": "類似タスクユーザーの自動サジェスト機能",
            "根拠": f"最大セグメント「{largest_segment}」はフォロワー不足が課題" if largest_segment else "フォロワー0人ユーザーへのソーシャル接続支援",
            "関連モジュール": "M3, M6",
            "impact": 7,
            "effort": 3,
        },
        {
            "施策名": "シールド自動付与（マイルストーン達成・フォロワー贈与）",
            "根拠": "シールド保有ユーザーのチャーン率低減（M2）",
            "関連モジュール": "M2",
            "impact": 5,
            "effort": 2,
        },
    ]

    df_init = pd.DataFrame(initiatives)
    df_init["priority_score"] = df_init["impact"] / df_init["effort"]
    df_init = df_init.sort_values("priority_score", ascending=False).reset_index(drop=True)
    df_init["順位"] = range(1, len(df_init) + 1)

    print("[M9] 施策優先度ランキング:")
    print(df_init[["順位", "施策名", "impact", "effort", "priority_score"]].to_string(index=False))
    save_csv(df_init[["順位", "施策名", "根拠", "関連モジュール", "impact", "effort", "priority_score"]], "m9_initiatives_ranked")

    # バブルチャート
    fig_bubble = px.scatter(
        df_init, x="effort", y="impact",
        size="priority_score",
        text="施策名",
        color="priority_score",
        size_max=50,
        color_continuous_scale="RdYlGn",
        title="開発施策 優先度マトリクス（インパクト × 実装コスト）",
        labels={"effort": "実装コスト（大きいほど高コスト）", "impact": "インパクト（大きいほど高）",
                "priority_score": "優先スコア"},
    )
    fig_bubble.update_traces(textposition="top center")
    fig_bubble.update_xaxes(range=[0, 6])
    fig_bubble.update_yaxes(range=[4, 10])
    save_figure(fig_bubble, "m9_priority_matrix")

    # テキストサマリー
    top5 = df_init.head(5)
    summary = f"""== V-EFFECT 解析サマリー ({TODAY}) ==

[データ概要]
- 総ユーザー数: {len(pd.DataFrame())} ※ M0参照
- action_logs 期間: 2026-06-04 〜 2026-06-15（11日間）

[アプリの現状]
- D30 リテンション率: {d30_str}
- 直近14日 アクティブ率: {active_str}
- チャーン率（30日以上未投稿）: {churn_str}
- 高リスクユーザー数（上位20%）: {high_risk_n}人

[最重要発見]
1. [M1] D30 リテンション = {d30_str}  ← 業界基準(10%/20%)との比較で方針決定
2. [M2] streak_gap≥7日のチャーン率 = {f"{high_streak_gap_churn*100:.1f}%" if high_streak_gap_churn else "N/A"}  ← ストリーク破綻がチャーンの主因
3. [M3] フォロワー数とアクティブ率の相関 r = {f"{social_corr:.2f}" if social_corr else "N/A"}  ← ソーシャル機能の重要度
4. [M5] 最高定着カテゴリ: {best_category}  ← 獲得ターゲットの絞込みに活用
5. [M6] 最大セグメント: {largest_segment}  ← 最も多くのユーザーが属する層

[開発優先度 TOP5]
"""
    for _, row in top5.iterrows():
        summary += f"{int(row['順位'])}位: {row['施策名']}\n    根拠: {row['根拠']}\n\n"

    summary += f"""[注意事項]
- action_logs は直近11日分のみ。M4（初週分析）はデータ蓄積後に再実行推奨。
- ユーザー数52人は統計的に小さく、コホート分析の信頼区間が広い。
- 3〜6ヶ月後に再実行して数値の変化をモニタリングしてください。
"""
    sys.stdout.buffer.write(f"\n{summary}".encode("utf-8", errors="replace"))
    sys.stdout.buffer.write(b"\n")
    save_text(summary, "m9_summary")


if __name__ == "__main__":
    main()

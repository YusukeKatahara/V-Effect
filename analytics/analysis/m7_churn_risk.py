import datetime
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from analysis.utils import days_since, load_latest_json, save_csv, save_figure, save_text

import pandas as pd
import plotly.express as px
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import cross_val_score
from sklearn.preprocessing import StandardScaler

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from src.anonymizer import anonymize_uid

TODAY = datetime.date.today()


def calc_churn_risk_score(row) -> float:
    score = 0.0
    d = row["days_silent"]
    score += min(d / 30 * 40, 40)
    max_s = max(row["max_streak"], 1)
    curr_s = row["streak"]
    loss_ratio = max(0, (max_s - curr_s) / max_s)
    score += loss_ratio * 30
    followers = row["follower_count"]
    score += max(0, 20 - followers * 2)
    if row["task_count"] == 0:
        score += 10
    return min(score, 100)


def main():
    users = load_latest_json("users")
    rows = []
    for u in users:
        lpd = u.get("lastPostedDate")
        if not lpd:
            continue
        d = days_since(lpd, TODAY)
        if d is None:
            continue
        followers = list(u.get("followers") or [])
        rows.append({
            "uid": u.get("uid"),
            "anon_uid": anonymize_uid(u.get("uid") or ""),
            "streak": u.get("streak") or 0,
            "max_streak": u.get("maxStreak") or 0,
            "streak_protections": u.get("streakProtections") or 0,
            "follower_count": len(followers),
            "task_count": len(u.get("tasks") or []),
            "days_silent": d,
            "is_churned": int(d >= 30),
        })

    df = pd.DataFrame(rows)
    df["streak_loss_ratio"] = df.apply(
        lambda r: max(0, (r["max_streak"] - r["streak"]) / max(r["max_streak"], 1)), axis=1
    )
    df["churn_risk_score"] = df.apply(calc_churn_risk_score, axis=1)

    print(f"[M7] 対象: {len(df)}人 / チャーン率: {df['is_churned'].mean()*100:.1f}%")
    print(f"[M7] チャーンリスクスコア分布:")
    print(df["churn_risk_score"].describe().round(1).to_string())

    # リスクスコア分布ヒストグラム
    fig_hist = px.histogram(
        df, x="churn_risk_score", nbins=20,
        title="チャーンリスクスコア分布（0=安全, 100=危険）",
        labels={"churn_risk_score": "チャーンリスクスコア", "count": "ユーザー数"},
        color_discrete_sequence=["tomato"],
    )
    fig_hist.add_vline(x=df["churn_risk_score"].quantile(0.8), line_dash="dash",
                        line_color="red", annotation_text="上位20%閾値")
    save_figure(fig_hist, "m7_churn_risk_distribution")

    # 高リスクユーザー（上位20%）
    threshold = df["churn_risk_score"].quantile(0.8)
    high_risk = df[df["churn_risk_score"] >= threshold].sort_values("churn_risk_score", ascending=False)
    print(f"\n[M7] 高リスクユーザー（上位20%, n={len(high_risk)}）:")
    print(high_risk[["anon_uid", "churn_risk_score", "days_silent", "streak",
                       "max_streak", "follower_count", "task_count"]].head(10).to_string(index=False))
    save_csv(high_risk[["anon_uid", "churn_risk_score", "days_silent", "streak",
                          "max_streak", "streak_loss_ratio", "follower_count",
                          "task_count", "is_churned"]], "m7_high_risk_users")

    # ロジスティック回帰
    feature_cols = ["days_silent", "streak_loss_ratio", "follower_count", "task_count", "streak_protections"]
    X = df[feature_cols].fillna(0)
    y = df["is_churned"]

    if y.nunique() < 2 or len(df) < 10:
        print("\n[M7] サンプル不足のためロジスティック回帰をスキップ")
        perf_text = f"サンプル数: {len(df)}\nチャーン率: {y.mean()*100:.1f}%\n※ サンプル不足のため回帰分析をスキップ"
    else:
        scaler = StandardScaler()
        X_scaled = scaler.fit_transform(X)
        lr = LogisticRegression(random_state=42, max_iter=1000)
        cv_aucs = cross_val_score(lr, X_scaled, y, cv=min(5, y.sum()), scoring="roc_auc")
        print(f"\n[M7] ロジスティック回帰 AUC: {cv_aucs.mean():.3f} ± {cv_aucs.std():.3f}")

        lr.fit(X_scaled, y)
        coef_df = pd.DataFrame({
            "特徴量": feature_cols,
            "係数（正=チャーン要因）": lr.coef_[0].round(3),
        }).sort_values("係数（正=チャーン要因）", ascending=False)
        print("\n[M7] 特徴量別 チャーン寄与係数:")
        print(coef_df.to_string(index=False))

        fig_coef = px.bar(
            coef_df, x="係数（正=チャーン要因）", y="特徴量", orientation="h",
            title="チャーン要因の重要度（ロジスティック回帰係数）",
            color="係数（正=チャーン要因）",
            color_continuous_scale="RdBu_r",
        )
        fig_coef.update_layout(yaxis={"categoryorder": "total ascending"})
        save_figure(fig_coef, "m7_feature_importance")

        perf_text = (
            f"サンプル数: {len(df)}\n"
            f"チャーン率: {y.mean()*100:.1f}%\n"
            f"5-fold CV AUC: {cv_aucs.mean():.3f} ± {cv_aucs.std():.3f}\n\n"
            f"特徴量別係数:\n{coef_df.to_string(index=False)}"
        )

    save_text(perf_text, "m7_model_performance")


if __name__ == "__main__":
    main()

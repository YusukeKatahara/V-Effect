import datetime
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from analysis.utils import days_since, load_latest_json, save_csv, save_figure

import numpy as np
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from sklearn.cluster import KMeans
from sklearn.decomposition import PCA
from sklearn.metrics import silhouette_score
from sklearn.preprocessing import StandardScaler

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from src.anonymizer import anonymize_uid

TODAY = datetime.date.today()

FEATURE_COLS = [
    "streak", "max_streak", "streak_ratio",
    "follower_count", "following_count", "mutual_count",
    "task_count", "days_since_last_post", "streak_protections",
]

CLUSTER_NAMES = {
    0: "クラスタ0", 1: "クラスタ1", 2: "クラスタ2",
    3: "クラスタ3", 4: "クラスタ4", 5: "クラスタ5",
}


def main():
    users = load_latest_json("users")
    rows = []
    for u in users:
        lpd = u.get("lastPostedDate")
        d = days_since(lpd, TODAY) if lpd else 999
        followers = list(u.get("followers") or [])
        following = list(u.get("following") or [])
        streak = u.get("streak") or 0
        max_s = u.get("maxStreak") or 0
        rows.append({
            "uid": u.get("uid"),
            "streak": streak,
            "max_streak": max_s,
            "streak_ratio": streak / max(max_s, 1),
            "follower_count": len(followers),
            "following_count": len(following),
            "mutual_count": len(set(followers) & set(following)),
            "task_count": len(u.get("tasks") or []),
            "days_since_last_post": d,
            "streak_protections": u.get("streakProtections") or 0,
        })

    df = pd.DataFrame(rows)

    # 前処理
    X = df[FEATURE_COLS].copy()
    for col in FEATURE_COLS:
        X[col] = X[col].fillna(X[col].median())
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    # 最適k選択（シルエットスコア）
    print("[M6] シルエットスコアでk選択中...")
    sil_scores = {}
    for k in range(2, min(9, len(df) - 1)):
        km = KMeans(n_clusters=k, random_state=42, n_init=10)
        labels = km.fit_predict(X_scaled)
        sil = silhouette_score(X_scaled, labels)
        sil_scores[k] = sil
        print(f"  k={k}: silhouette={sil:.3f}")

    best_k = max(sil_scores, key=sil_scores.get)
    print(f"[M6] 最適 k = {best_k}")

    km_final = KMeans(n_clusters=best_k, random_state=42, n_init=10)
    df["cluster"] = km_final.fit_predict(X_scaled)

    # クラスタプロファイル
    profiles = df.groupby("cluster")[FEATURE_COLS].mean().round(2)
    print("\n[M6] クラスタ別特徴量平均:")
    print(profiles.T.to_string())

    # クラスタ命名（特性から自動推定）
    def name_cluster(row):
        if row["days_since_last_post"] > 30 and row["streak"] < 3:
            return "休眠ユーザー"
        elif row["streak"] >= 10 and row["follower_count"] >= 5:
            return "パワーユーザー"
        elif row["streak"] >= 5 and row["follower_count"] < 2:
            return "孤独な継続者"
        elif row["following_count"] >= 5 and row["streak"] < 5:
            return "ソーシャル活動型"
        elif row["max_streak"] < 3 and row["days_since_last_post"] < 30:
            return "新規ユーザー"
        else:
            return "中間層"

    cluster_labels = {i: name_cluster(profiles.loc[i]) for i in range(best_k)}
    df["cluster_name"] = df["cluster"].map(cluster_labels)
    print("\n[M6] クラスタ命名:")
    for i, name in cluster_labels.items():
        cnt = (df["cluster"] == i).sum()
        print(f"  クラスタ{i} ({name}): {cnt}人")

    # クラスタサイズ棒グラフ
    size_df = df.groupby("cluster_name").size().reset_index(name="人数")
    fig_size = px.bar(
        size_df, x="cluster_name", y="人数",
        title="セグメント別ユーザー数",
        labels={"cluster_name": "セグメント", "人数": "ユーザー数"},
        color="cluster_name",
    )
    save_figure(fig_size, "m6_cluster_size")

    # PCA散布図
    pca = PCA(n_components=2, random_state=42)
    X_pca = pca.fit_transform(X_scaled)
    df["pca_x"] = X_pca[:, 0]
    df["pca_y"] = X_pca[:, 1]
    fig_pca = px.scatter(
        df, x="pca_x", y="pca_y", color="cluster_name",
        title=f"ユーザーセグメント (PCA 2D, k={best_k})",
        labels={"pca_x": "PC1", "pca_y": "PC2", "cluster_name": "セグメント"},
        opacity=0.8,
    )
    save_figure(fig_pca, "m6_cluster_pca_scatter")

    # レーダーチャート
    feature_labels = {
        "streak": "ストリーク", "max_streak": "最大ストリーク", "streak_ratio": "ストリーク維持率",
        "follower_count": "フォロワー", "following_count": "フォロー中",
        "mutual_count": "相互フォロー", "task_count": "タスク数",
        "days_since_last_post": "未投稿日数", "streak_protections": "シールド数",
    }
    # 正規化（0〜1）
    profiles_norm = (profiles - profiles.min()) / (profiles.max() - profiles.min() + 1e-9)
    fig_radar = go.Figure()
    angles = list(feature_labels.values())
    for i in range(best_k):
        vals = profiles_norm.loc[i].tolist()
        vals += [vals[0]]  # 閉じる
        fig_radar.add_trace(go.Scatterpolar(
            r=vals,
            theta=angles + [angles[0]],
            fill="toself",
            name=f"{cluster_labels[i]} (n={int((df['cluster']==i).sum())})",
        ))
    fig_radar.update_layout(
        polar=dict(radialaxis=dict(visible=True, range=[0, 1])),
        title="セグメント別 特徴量レーダーチャート",
    )
    save_figure(fig_radar, "m6_cluster_radar")

    # CSV保存
    profiles_out = profiles.copy()
    profiles_out["cluster_name"] = profiles_out.index.map(cluster_labels)
    profiles_out["user_count"] = df.groupby("cluster").size().values
    save_csv(profiles_out.reset_index(), "m6_cluster_profiles")

    df_out = df[["uid", "cluster", "cluster_name"]].copy()
    df_out["uid"] = df_out["uid"].apply(lambda x: anonymize_uid(x) if x else "")
    save_csv(df_out, "m6_user_clusters")


if __name__ == "__main__":
    main()

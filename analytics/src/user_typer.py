from collections import Counter


def infer_user_type(task_categories: list[str]) -> str:
    """タスクの大カテゴリ一覧から主要ユーザータイプを推定する。"""
    if not task_categories:
        return "Other"
    counts = Counter(c for c in task_categories if c and c != "Other")
    if not counts:
        return "Other"
    return counts.most_common(1)[0][0]


def infer_user_types_detail(task_categories: list[str]) -> dict:
    """主タイプとサブタイプを返す。"""
    if not task_categories:
        return {"primary": "Other", "sub": []}
    counts = Counter(c for c in task_categories if c and c != "Other")
    if not counts:
        return {"primary": "Other", "sub": []}
    ordered = counts.most_common()
    primary = ordered[0][0]
    sub = [cat for cat, _ in ordered[1:3]]
    return {"primary": primary, "sub": sub}

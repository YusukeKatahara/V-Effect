import datetime
from typing import Optional

import nltk
from nltk.stem import PorterStemmer
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

from .db import get_conn

try:
    nltk.data.find("tokenizers/punkt")
except LookupError:
    nltk.download("punkt", quiet=True)

CATEGORY_HIERARCHY: dict[str, dict[str, list[str]]] = {
    "Fitness": {
        "Running":    ["run", "jog", "sprint", "marathon", "jogging", "running", "treadmill", "pace"],
        "Gym":        ["gym", "weight", "bench", "squat", "deadlift", "workout", "lift", "muscle", "training", "dumbbell", "barbell", "rep", "weighttraining", "weightlifting"],
        "Yoga":       ["yoga", "stretch", "pilates", "flexibility", "meditation"],
        "Cardio":     ["swim", "swimming", "cycle", "cycling", "bike", "rowing", "row", "elliptical", "cardio", "aerobic"],
        "Bodyweight": ["pushup", "pullup", "plank", "burpee", "calisthenics", "situp", "crunch", "warmup", "cooldown"],
        "Combat":     ["shadowboxing", "boxing", "kickboxing", "martial", "karate", "judo", "mma", "sparring", "punch"],
    },
    "Education": {
        "Language":   ["english", "japanese", "spanish", "french", "chinese", "vocabulary", "toeic", "toefl", "grammar", "listening"],
        "Math":       ["math", "mathematics", "calculus", "algebra", "statistics", "arithmetic", "geometry"],
        "Coding":     ["code", "coding", "program", "programming", "python", "algorithm", "software", "develop", "debug", "javascript", "dart", "flutter"],
        "Study":      ["study", "exam", "review", "reading", "book", "textbook", "note", "quiz", "learn", "lecture", "flashcard"],
    },
    "Life": {
        "Cooking":    ["cook", "cooking", "recipe", "meal", "bake", "baking", "kitchen", "food", "diet", "nutrition", "mealprep"],
        "Cleaning":   ["clean", "cleaning", "organize", "tidy", "laundry", "wash", "sweep", "room"],
        "SkinCare":   ["skincare", "skin", "face", "beauty", "moisturize", "sunscreen", "moisturizer"],
        "Sleep":      ["sleep", "wakeup", "morning", "routine", "night", "bed", "rest", "nap"],
        "Walking":    ["walk", "walking", "stroll", "outdoor", "nature", "hiking", "hike"],
    },
    "Creative": {
        "Art":        ["draw", "drawing", "paint", "painting", "sketch", "illustration", "art", "design", "graphic"],
        "Music":      ["guitar", "piano", "drum", "violin", "song", "sing", "music", "instrument", "practice", "compose"],
        "Writing":    ["blog", "journal", "diary", "write", "writing", "essay", "novel", "poem", "story"],
        "Craft":      ["craft", "diy", "knit", "sew", "origami", "handmade", "pottery"],
    },
    "Work": {
        # "business" を除去（SideJobとBusinessの混同を防ぐ）
        "Business":   ["meeting", "email", "project", "report", "office", "client", "presentation", "deadline", "schedule", "corporate"],
        "SideJob":    ["freelance", "sidejob", "income", "sell", "sales", "startup", "invest", "hustle", "monetize", "profit"],
    },
}

CATEGORY_DESCRIPTIONS: dict[str, str] = {
    "Fitness": "毎日の運動・トレーニングを継続しているユーザー。ランニング・筋トレ・ヨガなどが中心。",
    "Education": "学習・資格取得・スキルアップに取り組むユーザー。英語・コーディング・試験勉強など。",
    "Life": "日常生活の質を高める習慣を持つユーザー。料理・睡眠・スキンケアなどを記録。",
    "Creative": "クリエイティブな趣味・制作活動を続けるユーザー。絵・音楽・ライティングなど。",
    "Work": "仕事・副業・キャリアに向き合うユーザー。業務改善・フリーランスなど。",
    "Other": "まだ分類されていないタスク。手動ラベリングページで分類を設定できます。",
}

# スペースやハイフン区切りの複合語を1語に正規化するマッピング。
# 「work out」→「workout」のように、分割されると誤分類される語を事前に統合する。
PHRASE_NORMALIZE: dict[str, str] = {
    # Fitness
    "work out":   "workout",
    "work-out":   "workout",
    "push up":    "pushup",
    "push-up":    "pushup",
    "pull up":    "pullup",
    "pull-up":    "pullup",
    "sit up":     "situp",
    "sit-up":     "situp",
    "chin up":    "pullup",
    "chin-up":    "pullup",
    "warm up":    "warmup",
    "warm-up":    "warmup",
    "cool down":  "cooldown",
    "cool-down":  "cooldown",
    "weight training": "weighttraining",
    "weight lift":     "weightlifting",
    "shadow boxing":   "shadowboxing",
    "shadow box":      "shadowboxing",
    # Life
    "wake up":    "wakeup",
    "wake-up":    "wakeup",
    "skin care":  "skincare",
    "skin-care":  "skincare",
    "meal prep":  "mealprep",
    "meal-prep":  "mealprep",
    "go to bed":  "sleep",
    "go to sleep": "sleep",
    # Education
    "flash card":  "flashcard",
    "flash-card":  "flashcard",
    # Work
    "side job":   "sidejob",
    "side-job":   "sidejob",
    "side hustle": "sidejob",
}

SIMILARITY_THRESHOLD = 0.12

_stemmer = PorterStemmer()


class TaskClassifier:
    def __init__(self):
        self._vectorizer: Optional[TfidfVectorizer] = None
        self._category_vectors = None
        self._category_labels: list[tuple[str, str]] = []
        self._build_index()

    def _build_index(self):
        corpus: list[str] = []
        labels: list[tuple[str, str]] = []

        for large, mediums in CATEGORY_HIERARCHY.items():
            for medium, keywords in mediums.items():
                stemmed = " ".join(_stem(w) for w in keywords)
                corpus.append(stemmed)
                labels.append((large, medium))

        self._vectorizer = TfidfVectorizer(analyzer="word", token_pattern=r"[a-z]+")
        self._category_vectors = self._vectorizer.fit_transform(corpus)
        self._category_labels = labels

    def classify(self, task_name_en: str) -> dict[str, str]:
        """英語のタスク名を大カテゴリ・中カテゴリに分類する。"""
        tokens = _tokenize_and_stem(task_name_en)
        if not tokens:
            return {"large": "Other", "medium": "Other"}

        vec = self._vectorizer.transform([tokens])
        sims = cosine_similarity(vec, self._category_vectors)[0]
        best_idx = int(sims.argmax())

        if sims[best_idx] < SIMILARITY_THRESHOLD:
            return {"large": "Other", "medium": "Other"}

        large, medium = self._category_labels[best_idx]
        return {"large": large, "medium": medium}

    def classify_with_cache(self, task_name_original: str, task_name_translated: str) -> dict[str, str]:
        """キャッシュを参照し、なければ分類してキャッシュに保存する。"""
        with get_conn() as conn:
            row = conn.execute(
                "SELECT category_large, category_medium FROM task_category_cache WHERE task_name_original = ?",
                (task_name_original,),
            ).fetchone()
            if row:
                return {"large": row["category_large"], "medium": row["category_medium"]}

        result = self.classify(task_name_translated)

        with get_conn() as conn:
            conn.execute(
                """INSERT OR REPLACE INTO task_category_cache
                   (task_name_original, task_name_translated, category_large, category_medium, classified_at)
                   VALUES (?, ?, ?, ?, ?)""",
                (task_name_original, task_name_translated, result["large"], result["medium"],
                 datetime.datetime.now().isoformat()),
            )
        return result


def _tokenize_and_stem(text: str) -> str:
    normalized = _apply_phrase_normalize(text.lower())
    stemmed = [_stem(t) for t in normalized.split() if t.isalpha()]
    return " ".join(stemmed)


def _apply_phrase_normalize(text: str) -> str:
    """複合語（スペース・ハイフン区切り）を正規化する。長いフレーズから先に適用する。"""
    for phrase, replacement in sorted(PHRASE_NORMALIZE.items(), key=lambda x: -len(x[0])):
        text = text.replace(phrase, replacement)
    return text


def _stem(word: str) -> str:
    return _stemmer.stem(word.lower())

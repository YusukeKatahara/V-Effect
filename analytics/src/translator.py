import time
from typing import Optional

from googletrans import Translator

_translator = Translator(service_urls=["translate.google.co.jp", "translate.google.com"])


def translate_to_english(text: str, retries: int = 2) -> Optional[str]:
    """テキストを英語に翻訳する。失敗時はNoneを返す。"""
    if not text or not text.strip():
        return text
    if _is_ascii(text):
        return text.strip()

    for attempt in range(retries + 1):
        try:
            result = _translator.translate(text, dest="en")
            return result.text.strip() if result and result.text else None
        except Exception:
            if attempt < retries:
                time.sleep(1.0)
    return None


def translate_batch(task_names: list[str]) -> dict[str, str]:
    """複数タスク名をまとめて翻訳する。失敗したものは原文をそのまま使う。"""
    result: dict[str, str] = {}
    batch_size = 30
    for i in range(0, len(task_names), batch_size):
        batch = task_names[i : i + batch_size]
        for name in batch:
            translated = translate_to_english(name)
            result[name] = translated if translated else name
        if i + batch_size < len(task_names):
            time.sleep(0.5)
    return result


def _is_ascii(text: str) -> bool:
    try:
        text.encode("ascii")
        return True
    except UnicodeEncodeError:
        return False

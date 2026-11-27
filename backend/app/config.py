from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

BACKEND_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BACKEND_DIR / "data"
MEDIA_DIR = DATA_DIR / "images"

load_dotenv(BACKEND_DIR / ".env")

DATA_DIR.mkdir(parents=True, exist_ok=True)
MEDIA_DIR.mkdir(parents=True, exist_ok=True)

DB_PATH = DATA_DIR / "app.db"
SEED_PATH = BACKEND_DIR / "app" / "data" / "words_seed.json"
POLICY_PATH = BACKEND_DIR / "app" / "data" / "policy.json"

DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY", "").strip()
DEEPSEEK_BASE_URL = os.getenv("DEEPSEEK_BASE_URL", "https://api.deepseek.com").rstrip("/")
DEEPSEEK_MODEL = os.getenv("DEEPSEEK_MODEL", "deepseek-chat")

DASHSCOPE_API_KEY = os.getenv("DASHSCOPE_API_KEY", "").strip()
DASHSCOPE_BASE_URL = os.getenv(
    "DASHSCOPE_BASE_URL", "https://dashscope.aliyuncs.com"
).rstrip("/")
IMAGE_MODEL = os.getenv("IMAGE_MODEL", "qwen-image-3.0")
IMAGE_SIZE = os.getenv("IMAGE_SIZE", "768*768")

# 本地 Stable Diffusion（Forge）配置；LOCAL_SD_URL 非空时优先走本地
LOCAL_SD_URL = os.getenv("LOCAL_SD_URL", "").strip().rstrip("/")
LOCAL_SD_MODEL = os.getenv(
    "LOCAL_SD_MODEL", "NoobAI-XL-v1.1.safetensors"
)
LOCAL_SD_STYLE = os.getenv(
    "LOCAL_SD_STYLE",
    "amazing quality, very aesthetic, safe, bright colors, clear lighting",
)
LOCAL_SD_STEPS = int(os.getenv("LOCAL_SD_STEPS", "28"))
LOCAL_SD_CFG = float(os.getenv("LOCAL_SD_CFG", "5"))
LOCAL_SD_WIDTH = int(os.getenv("LOCAL_SD_WIDTH", "832"))
LOCAL_SD_HEIGHT = int(os.getenv("LOCAL_SD_HEIGHT", "832"))
LOCAL_SD_SAMPLER = os.getenv("LOCAL_SD_SAMPLER", "Euler a")

# auto: 有 Key 就调真实模型，没有就走 Mock
AI_MODE = os.getenv("AI_MODE", "auto").strip().lower()


def use_real_llm() -> bool:
    if AI_MODE == "mock":
        return False
    if AI_MODE == "real":
        return True
    return bool(DEEPSEEK_API_KEY)


def use_real_image() -> bool:
    if AI_MODE == "mock":
        return False
    if AI_MODE == "real":
        return True
    return bool(DASHSCOPE_API_KEY)

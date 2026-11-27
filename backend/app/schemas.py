from __future__ import annotations

from pydantic import BaseModel, Field


class WordOut(BaseModel):
    id: int
    word: str
    rank: int
    sfi: float | None = None
    freq: int | None = None
    definition_en: str = ""
    h0: float
    d0: float


class WordPage(BaseModel):
    total: int
    offset: int
    limit: int
    items: list[WordOut]


class ReviewPlanRequest(BaseModel):
    h: float = Field(gt=0, description="当前记忆半衰期（天）")
    d: float = Field(ge=1, le=18, description="当前记忆难度（官方 1~18）")
    days_since_review: float = Field(default=0, ge=0)
    recalled: bool | None = Field(
        default=None,
        description="本次复习结果；不传表示只查询当前回忆概率和下一次间隔",
    )
    last_interval: float | None = Field(
        default=None,
        description="上一次实际使用的间隔（天），用于平滑间隔增长",
    )


class ReviewPlanResponse(BaseModel):
    recall_probability: float
    interval_days: int
    next_h: float
    next_d: float
    next_due_in_days: float


class GraphRequest(BaseModel):
    word: str = Field(min_length=1, max_length=64)
    force: bool = False


class LookupRequest(BaseModel):
    word: str = Field(min_length=1, max_length=64)


class ContextRequest(BaseModel):
    words: list[str] = Field(min_length=1, max_length=12)
    mode: str = Field(default="story", pattern="^(story|dialogue)$")
    force: bool = False

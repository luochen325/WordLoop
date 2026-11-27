"""DHP / DSR 记忆模型（按官方 maimemo/SSP-MMC 实现复刻）。

官方参数来自：
- model/utils.py: cal_start_halflife / cal_recall_halflife / cal_forget_halflife
- algo/main.cpp: 半衰期网格 base=1.05、难度 1~18、失败后难度 +2

状态:
  h: 记忆半衰期（天）
  d: 记忆难度（1~18 的整数，越大越难）
"""

from __future__ import annotations

import math
from dataclasses import dataclass

H_MIN = 0.05
H_MAX = 3650.0
D_MIN = 1.0
D_MAX = 18.0

# 官方 algo/main.cpp: d_offset = 2，回忆失败后难度 +2
D_FAIL_STEP = 2.0

# 官方终止状态：1.05^121 ≈ 365 天
TARGET_H = 365.0

# 官方 algo/main.cpp: recall_cost=3.0, forget_cost=9.0
COST_SUCCESS = 3.0
COST_FAIL = 9.0


@dataclass(frozen=True)
class MemoryState:
    h: float
    d: float


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _round_half_up(value: float) -> int:
    return int(math.floor(value + 0.5))


def start_halflife(difficulty: float) -> float:
    """官方 cal_start_halflife(d)。"""
    p = max(0.925 - 0.05 * difficulty, 0.025)
    return -1.0 / math.log2(p)


def recall_probability(h: float, delta_days: float) -> float:
    """官方公式 p = 2^(-Δt/h)。"""
    if h <= 0:
        return 0.0
    return 2.0 ** (-max(delta_days, 0.0) / h)


def next_state(state: MemoryState, delta_days: float, recalled: bool) -> MemoryState:
    """官方 cal_next_recall_halflife 的状态转移。"""
    h = _clamp(state.h, H_MIN, H_MAX)
    d = _clamp(state.d, D_MIN, D_MAX)
    p = recall_probability(h, delta_days)
    forgetting = max(1.0 - p, 1e-4)

    if recalled:
        h_next = h * (
            1.0
            + math.exp(3.81)
            * d ** -0.534
            * h ** -0.127
            * forgetting ** 0.97
        )
        d_next = d
    else:
        h_next = (
            math.exp(-0.041)
            * d ** -0.041
            * h ** 0.377
            * forgetting ** -0.227
        )
        d_next = min(D_MAX, d + D_FAIL_STEP)

    return MemoryState(_clamp(h_next, H_MIN, H_MAX), _clamp(d_next, D_MIN, D_MAX))


def initial_difficulty(rank: int, total: int) -> float:
    """无真实学习数据时，用词频排名映射到官方 1~18 难度。"""
    if total <= 1:
        return 9.0
    percentile = (rank - 1) / (total - 1)
    return _clamp(1 + _round_half_up(17 * percentile), D_MIN, D_MAX)


def initial_stability(rank: int, total: int) -> float:
    """由难度按官方 cal_start_halflife 推导初始半衰期。"""
    return start_halflife(initial_difficulty(rank, total))

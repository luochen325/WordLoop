"""SSP-MMC 官方参数复刻版。

对应 maimemo/SSP-MMC：
- algo/main.cpp：base=1.05，半衰期索引 -30..121，难度 1..18，失败 +2
- model/utils.py：DHP 状态转移公式
- 目标终止状态：1.05^121 ≈ 365 天
- 回忆成本 3s，遗忘成本 9s

策略表用值迭代求解，结果导出为 policy.json，App 端直接查表。
"""

from __future__ import annotations

import json
import math
import time
from dataclasses import dataclass
from pathlib import Path

import numpy as np

from .memory import (
    COST_FAIL,
    COST_SUCCESS,
    D_FAIL_STEP,
    D_MAX,
    D_MIN,
    TARGET_H,
    start_halflife,
)

# 官方 algo/main.cpp 参数
H_BASE = 1.05
H_MIN_INDEX = -30
H_MAX_INDEX = 122  # 指数范围 [-30, 121]，共 152 个状态
H_VALUES = [H_BASE ** i for i in range(H_MIN_INDEX, H_MAX_INDEX)]
TERMINAL_INDEX = len(H_VALUES) - 1
D_COUNT = int(D_MAX - D_MIN) + 1
D_VALUES = [float(i) for i in range(int(D_MIN), int(D_MAX) + 1)]

# 官方 actions：间隔 1..round(h * log(0.3)/log(0.5))
INTERVAL_FACTOR = math.log(0.3) / math.log(0.5)


@dataclass
class PolicyTable:
    h_values: list[float]
    d_values: list[float]
    policy: list[list[int]]
    expected_cost: list[list[float]]


def _round_half_up(value: float) -> int:
    return int(math.floor(value + 0.5))


def _h_index(h: float, h_values: list[float]) -> int:
    """官方 cal_halflife_index。"""
    if h <= h_values[0]:
        return 0
    if h >= TARGET_H:
        return TERMINAL_INDEX
    idx = _round_half_up(math.log(h) / math.log(H_BASE)) - H_MIN_INDEX
    return max(0, min(TERMINAL_INDEX - 1, idx))


def _d_index(d: float, d_values: list[float]) -> int:
    idx = _round_half_up(d) - int(D_MIN)
    return max(0, min(len(d_values) - 1, idx))


def _max_interval_for(h: float) -> int:
    return max(1, _round_half_up(h * INTERVAL_FACTOR))


def solve(
    max_sweeps: int = 20000,
    tolerance: float = 0.1,
    verbose: bool = True,
) -> PolicyTable:
    """按官方状态/动作空间做值迭代。"""
    h = np.asarray(H_VALUES, dtype=np.float64)
    max_interval = np.array([_max_interval_for(v) for v in H_VALUES], dtype=np.int32)
    max_action = int(max_interval.max())

    cost = np.full((D_COUNT, len(H_VALUES)), 2000.0, dtype=np.float64)
    cost[:, TERMINAL_INDEX] = 0.0
    policy = np.zeros((D_COUNT, len(H_VALUES)), dtype=np.int32)

    h_col = h[:, None]
    actions = np.arange(1, max_action + 1, dtype=np.float64)[None, :]
    action_mask = actions <= max_interval[:, None]

    started = time.time()
    for d in range(int(D_MAX), int(D_MIN) - 1, -1):
        d_idx = d - int(D_MIN)
        fail_idx = min(d_idx + int(D_FAIL_STEP), D_COUNT - 1)
        h0_idx = _h_index(start_halflife(d), H_VALUES)
        d_power = d ** -0.534
        d_forget = d ** -0.041

        converged = False
        for sweep in range(max_sweeps):
            before = cost[d_idx, h0_idx]

            p = np.exp2(-actions / h_col)
            forgetting = np.maximum(1.0 - p, 1e-4)
            recall_h = h_col * (
                1.0
                + math.exp(3.81) * d_power * h_col ** -0.127 * forgetting ** 0.97
            )
            forget_h = math.exp(-0.041) * d_forget * h_col ** 0.377 * forgetting ** -0.227

            recall_idx = np.clip(
                np.floor(np.log(recall_h) / math.log(H_BASE) + 0.5).astype(np.int32)
                - H_MIN_INDEX,
                0,
                TERMINAL_INDEX,
            )
            forget_idx = np.clip(
                np.floor(np.log(forget_h) / math.log(H_BASE) + 0.5).astype(np.int32)
                - H_MIN_INDEX,
                0,
                TERMINAL_INDEX,
            )

            expected = p * (cost[d_idx][recall_idx] + COST_SUCCESS) + (
                1.0 - p
            ) * (cost[fail_idx][forget_idx] + COST_FAIL)
            expected = np.where(action_mask, expected, np.inf)

            best_action = np.argmin(expected, axis=1)
            best_cost = expected[np.arange(len(H_VALUES)), best_action]
            better = best_cost < cost[d_idx]
            cost[d_idx][better] = best_cost[better]
            policy[d_idx][better] = best_action[better] + 1

            diff = before - cost[d_idx, h0_idx]
            if sweep >= 500 and diff < tolerance:
                converged = True
                break
            if verbose and sweep % 2000 == 0:
                print(
                    f"d={d:>2} sweep={sweep:>5} diff={diff:8.4f} "
                    f"cost={cost[d_idx, h0_idx]:8.2f} elapsed={time.time()-started:6.0f}s",
                    flush=True,
                )

        if verbose:
            print(
                f"d={d:>2} {'converged' if converged else 'max sweeps'} "
                f"sweeps={sweep} cost={cost[d_idx, h0_idx]:.2f}",
                flush=True,
            )

    policy[:, TERMINAL_INDEX] = 0
    return PolicyTable(
        h_values=[round(v, 4) for v in H_VALUES],
        d_values=D_VALUES,
        policy=policy.tolist(),
        expected_cost=cost.tolist(),
    )


def lookup_interval(table: PolicyTable, h: float, d: float) -> int:
    return table.policy[_d_index(d, table.d_values)][_h_index(h, table.h_values)]


def save(table: PolicyTable, path: str | Path) -> None:
    payload = {
        "version": 2,
        "source": "maimemo/SSP-MMC",
        "h_base": H_BASE,
        "h_min_index": H_MIN_INDEX,
        "terminal_index": TERMINAL_INDEX,
        "h_values": table.h_values,
        "d_values": table.d_values,
        "policy": table.policy,
        "expected_cost": [[round(v, 2) for v in row] for row in table.expected_cost],
    }
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")


def load(path: str | Path) -> PolicyTable:
    payload = json.loads(Path(path).read_text(encoding="utf-8"))
    return PolicyTable(
        h_values=payload["h_values"],
        d_values=payload["d_values"],
        policy=payload["policy"],
        expected_cost=payload["expected_cost"],
    )


if __name__ == "__main__":
    table = solve(verbose=True)
    out = Path(__file__).resolve().parent.parent / "data" / "policy.json"
    save(table, out)
    print(f"policy saved to {out}")

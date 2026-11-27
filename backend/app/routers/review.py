from __future__ import annotations

from functools import lru_cache

from fastapi import APIRouter
from fastapi.responses import JSONResponse

from ..config import POLICY_PATH
from ..schemas import ReviewPlanRequest, ReviewPlanResponse
from ..services import ssp_mmc
from ..services.memory import (
    TARGET_H,
    MemoryState,
    next_state,
    recall_probability,
)

router = APIRouter(prefix="/api/review", tags=["review"])

MAX_INTERVAL_DAYS = 730
MAINTENANCE_INTERVAL_DAYS = 365


@lru_cache(maxsize=1)
def get_policy() -> ssp_mmc.PolicyTable:
    if POLICY_PATH.exists():
        return ssp_mmc.load(POLICY_PATH)
    table = ssp_mmc.solve()
    ssp_mmc.save(table, POLICY_PATH)
    return table


@router.get("/policy")
def policy():
    table = get_policy()
    return JSONResponse(
        {
            "version": 1,
            "h_values": table.h_values,
            "d_values": table.d_values,
            "actions": table.actions,
            "policy": table.policy,
        }
    )


@router.post("/plan", response_model=ReviewPlanResponse)
def plan(body: ReviewPlanRequest):
    table = get_policy()
    state = MemoryState(body.h, body.d)
    probability = recall_probability(state.h, body.days_since_review)

    if body.recalled is not None:
        state = next_state(state, body.days_since_review, body.recalled)

    if state.h >= TARGET_H:
        # 官方策略表的终止状态：不再高频复习，进入一年维护
        interval = MAINTENANCE_INTERVAL_DAYS
    else:
        interval = ssp_mmc.lookup_interval(table, state.h, state.d)
        if interval <= 0:
            interval = MAINTENANCE_INTERVAL_DAYS
        else:
            interval = max(1, min(MAX_INTERVAL_DAYS, interval))
    return ReviewPlanResponse(
        recall_probability=round(probability, 4),
        interval_days=interval,
        next_h=round(state.h, 4),
        next_d=round(state.d, 4),
        next_due_in_days=interval,
    )

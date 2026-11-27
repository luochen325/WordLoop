from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .config import MEDIA_DIR, use_real_image, use_real_llm
from .database import init_db
from .routers import ai, graph, review, words


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


app = FastAPI(
    title="WordLoop API",
    description="基于 SSP-MMC 记忆算法与大模型智能体的背单词应用后端",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/api/media", StaticFiles(directory=str(MEDIA_DIR)), name="media")

app.include_router(words.router)
app.include_router(ai.router)
app.include_router(graph.router)
app.include_router(review.router)


@app.get("/")
def root():
    return {
        "name": "WordLoop API",
        "docs": "/docs",
        "health": "/api/health",
    }


@app.get("/api/health")
def health():
    return {
        "status": "ok",
        "llm": "real" if use_real_llm() else "mock",
        "image": "real" if use_real_image() else "mock",
    }

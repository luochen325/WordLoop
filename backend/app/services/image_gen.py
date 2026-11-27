from __future__ import annotations

import base64
import re
from pathlib import Path

import httpx

from . import llm
from ..config import (
    DASHSCOPE_API_KEY,
    DASHSCOPE_BASE_URL,
    IMAGE_MODEL,
    IMAGE_SIZE,
    LOCAL_SD_CFG,
    LOCAL_SD_HEIGHT,
    LOCAL_SD_MODEL,
    LOCAL_SD_SAMPLER,
    LOCAL_SD_STEPS,
    LOCAL_SD_STYLE,
    LOCAL_SD_URL,
    LOCAL_SD_WIDTH,
    MEDIA_DIR,
    use_real_image,
)


class ImageError(RuntimeError):
    pass


_shared_client: httpx.AsyncClient | None = None
_local_prompt_cache: dict[str, str] = {}


def _client() -> httpx.AsyncClient:
    """复用 HTTP 连接，避免每次生成都重新做 TCP/TLS 握手。"""
    global _shared_client
    if _shared_client is None or _shared_client.is_closed:
        _shared_client = httpx.AsyncClient(
            timeout=httpx.Timeout(240, connect=10),
            limits=httpx.Limits(
                max_connections=10,
                max_keepalive_connections=5,
            ),
        )
    return _shared_client


async def generate_word_image(
    word_id: int,
    word: str,
    prompt: str,
    filename_stem: str | None = None,
    card: dict | None = None,
) -> str:
    """生成配图：优先本地 Forge，失败时回退到百炼。"""
    if LOCAL_SD_URL:
        try:
            content = await _generate_local(prompt, word, card)
        except Exception as exc:  # noqa: BLE001 - 本地失败要能回退云端
            print(f"local image failed, fallback to cloud: {exc}")
            if not use_real_image():
                raise ImageError(f"本地生图失败: {exc}") from exc
            content = await _generate_cloud(prompt)
    else:
        if not use_real_image():
            raise ImageError("未配置 DASHSCOPE_API_KEY，无法生成图片")
        content = await _generate_cloud(prompt)

    filename = f"{filename_stem or f'word_{word_id}'}.png"
    target: Path = MEDIA_DIR / filename
    target.write_bytes(content)
    return filename


async def _generate_local(
    prompt: str,
    word: str,
    card: dict | None = None,
) -> bytes:
    client = _client()
    scene = ""
    if card:
        if card.get("local_prompt_version") == llm.LOCAL_PROMPT_VERSION:
            scene = str(card.get("image_prompt_local") or "").strip()
        if not scene:
            cache_key = word.lower()
            scene = _local_prompt_cache.get(cache_key, "")
            if not scene:
                try:
                    scene = await llm.generate_local_image_prompt(word, card)
                    if scene:
                        _local_prompt_cache[cache_key] = scene
                except Exception as exc:  # noqa: BLE001 - 失败就退回卡片原描述
                    print(f"local prompt rewrite failed: {exc}")
    final_prompt = (
        f"masterpiece, best quality, {LOCAL_SD_STYLE}, "
        f"{_cartoon_prompt(prompt, word, card, scene)}"
    )
    print(f"[local sd] {word}: {final_prompt}")
    payload = {
        "prompt": final_prompt,
        "negative_prompt": (
            "worst quality, low quality, bad anatomy, bad hands, extra digits, "
            "text, letters, words, numbers, digits, captions, watermark, logo, "
            "signboard, signage, banner, chinese characters, english letters, "
            "chart, bar chart, diagram, infographic, graph, symbol, "
            "statue, sculpture, geometric shapes, abstract shapes, "
            "generic portrait, standing still, looking at viewer, "
            "multiple people, crowd, unrelated background, "
            "abstract art, psychedelic, surreal, chaotic, "
            "oversaturated, melted, distorted, colorful explosion, "
            "nsfw, explicit, nude, blurry, "
            "realistic photo, photorealistic"
        ),
        "width": LOCAL_SD_WIDTH,
        "height": LOCAL_SD_HEIGHT,
        "steps": LOCAL_SD_STEPS,
        "cfg_scale": LOCAL_SD_CFG,
        "sampler_name": LOCAL_SD_SAMPLER,
        "batch_size": 1,
        "n_iter": 1,
        "override_settings": {
            "sd_model_checkpoint": LOCAL_SD_MODEL,
            "CLIP_stop_at_last_layers": 2,
        },
        "send_images": True,
        "save_images": False,
    }
    resp = await client.post(
        f"{LOCAL_SD_URL}/sdapi/v1/txt2img",
        json=payload,
        timeout=240,
    )
    if resp.status_code >= 400:
        raise ImageError(f"Forge 返回 {resp.status_code}: {resp.text[:300]}")

    images = resp.json().get("images") or []
    if not images:
        raise ImageError("Forge 没有返回图片")
    try:
        return base64.b64decode(images[0])
    except Exception as exc:
        raise ImageError(f"图片解码失败: {exc}") from exc


def _clean_prompt(text: str) -> str:
    """去掉中文、写实词和冗长说明，只保留画面描述。"""
    text = re.sub(r"[\u4e00-\u9fff]+", " ", text)
    text = re.sub(
        r"(?i)realistic|photograph|photo|editorial|35mm|high detail|"
        r"natural light|literally|english word|core meaning|no text|"
        r"no letters|no watermark|viewer can guess",
        " ",
        text,
    )
    return re.sub(r"\s+", " ", text).strip(" .;,")


def _cartoon_prompt(
    prompt: str,
    word: str,
    card: dict | None = None,
    scene_override: str = "",
) -> str:
    """用单词卡里的具体画面描述，构造简短、可画出来的卡通提示词。"""
    scene = scene_override.strip()
    if not scene and card:
        scene = str(card.get("image_prompt") or "")
    if not scene:
        scene = prompt
    scene = _clean_prompt(scene)
    if len(scene) > 360:
        scene = scene[:360].rsplit(",", 1)[0]
    framing = ""
    if scene.lower().startswith(("a girl", "a boy", "a person", "a woman", "a man")):
        framing = ", full body"
    return f"{scene}{framing}, clear subject, no text"


async def _generate_cloud(prompt: str) -> bytes:
    payload = {
        "model": IMAGE_MODEL,
        "input": {
            "messages": [
                {
                    "role": "user",
                    "content": [{"text": prompt}],
                }
            ]
        },
        "parameters": {
            "negative_prompt": (
                "text, letters, words, captions, watermark, logo, "
                "diagram, chart, UI, abstract concept, unrelated scene, "
                "deformed hands, extra fingers, low quality, blurry"
            ),
            "size": IMAGE_SIZE,
            # 我们的 image_prompt 已经足够具体，关闭提示词扩写可以省一次模型调用。
            "prompt_extend": False,
            "watermark": False,
        },
    }
    headers = {
        "Authorization": f"Bearer {DASHSCOPE_API_KEY}",
        "Content-Type": "application/json",
    }

    client = _client()
    resp = await client.post(
        f"{DASHSCOPE_BASE_URL}/api/v1/services/aigc/multimodal-generation/generation",
        headers=headers,
        json=payload,
    )
    if resp.status_code >= 400:
        raise ImageError(f"百炼返回 {resp.status_code}: {resp.text[:300]}")

    data = resp.json()
    url = _extract_image_url(data)
    if not url:
        raise ImageError(f"未从响应中找到图片地址: {str(data)[:300]}")

    image_resp = await client.get(url)
    image_resp.raise_for_status()
    return image_resp.content


def _extract_image_url(data: dict) -> str | None:
    choices = (data.get("output") or {}).get("choices") or []
    for choice in choices:
        message = choice.get("message") or {}
        for item in message.get("content") or []:
            if isinstance(item, dict):
                for key in ("image", "image_url", "url"):
                    value = item.get(key)
                    if isinstance(value, str) and value.startswith("http"):
                        return value
    return None

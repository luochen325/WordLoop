from __future__ import annotations

import json
import random
import re
from typing import Any

import httpx

from ..config import (
    DEEPSEEK_API_KEY,
    DEEPSEEK_BASE_URL,
    DEEPSEEK_MODEL,
    use_real_llm,
)


class LLMError(RuntimeError):
    pass


def _strip_fences(text: str) -> str:
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```[a-zA-Z]*\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    return text.strip()


async def _chat_json(system: str, user: str, temperature: float = 0.6) -> dict[str, Any]:
    if not DEEPSEEK_API_KEY:
        raise LLMError("DEEPSEEK_API_KEY 未配置")

    payload = {
        "model": DEEPSEEK_MODEL,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "temperature": temperature,
        "response_format": {"type": "json_object"},
    }
    headers = {
        "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
        "Content-Type": "application/json",
    }

    last_error: Exception | None = None
    for _ in range(3):
        try:
            async with httpx.AsyncClient(timeout=90) as client:
                resp = await client.post(
                    f"{DEEPSEEK_BASE_URL}/chat/completions",
                    headers=headers,
                    json=payload,
                )
            resp.raise_for_status()
            content = resp.json()["choices"][0]["message"]["content"]
            return json.loads(_strip_fences(content))
        except Exception as exc:  # noqa: BLE001 - 需要把网络/解析错误统一抛出
            last_error = exc

    raise LLMError(f"大模型调用失败: {last_error}")


WORD_SYSTEM_PROMPT = """你是一位资深的英语词汇教学专家，服务对象是准备在日常生活中使用英语的大学生和职场人。
请针对给定单词输出严格的 JSON，不要输出 Markdown 代码块，不要输出 JSON 之外的任何文字。
所有中文解释要自然、适合中文母语者理解；英文例句必须地道、贴近真实生活场景。"""

WORD_USER_TEMPLATE = """请为单词 "{word}" 生成学习资料。
参考英文释义：{definition}

输出 JSON，字段要求：
{{
  "word": "单词原形",
  "phonetic_us": "美式音标，含斜杠",
  "phonetic_uk": "英式音标，含斜杠",
  "part_of_speech": ["v.", "n."],
  "meanings": [{{"pos": "词性", "zh": "中文释义", "en": "英文释义"}}],
  "examples": [{{"en": "英文例句", "zh": "中文翻译"}}],
  "collocations": [{{"phrase": "常见搭配", "zh": "中文意思"}}],
  "word_family": [{{"word": "派生词", "pos": "词性", "zh": "中文意思"}}],
  "synonyms": ["同义词1", "同义词2"],
  "antonyms": ["反义词1"],
  "etymology": "词源或构词法讲解，50字以内",
  "memory_tip": "记忆技巧，50字以内",
  "scenario": "一个最典型的使用场景，30字以内",
  "image_prompt": "用于文生图的英文提示词（25词以内）：只描述一个具体场景，写清主体、动作、关键物体和地点；主体和动作要直接体现该词含义，避免泛泛的人像、站立、看镜头；不要抽象、不要比喻、画面中不要出现任何文字",
  "image_prompt_local": "给 SDXL 动漫模型用的英文 Danbooru 标签（15-25 个，逗号分隔）：人物场景以 1girl, solo 或 1boy, solo 开头，纯物体/地点以 no humans 开头；包含 full body/upper body 构图标签和环境光线标签；用一个明确动作或前后对比表达词义；不要图表、箭头、文字、多人、复杂背景"
}}

要求：meanings 2-3 条，examples 3 条，collocations 4 条，word_family 2-4 条，synonyms/antonyms 各 1-3 个。
image_prompt 必须让一个没看过这个单词的人，仅凭画面就能猜出它的意思。"""

GRAPH_SYSTEM_PROMPT = """你是一位英语词汇网络构建专家。请输出严格的 JSON，不要输出 Markdown 代码块或额外文字。
你构建的词与词之间的关系必须真实、常用，适合日常英语学习者。"""

GRAPH_USER_TEMPLATE = """以单词 "{word}" 为中心，生成 8-10 个与它有明确关系的英文单词，构建知识网络。
关系类型只能是：synonym（同义）、antonym（反义）、word_family（派生词）、collocation（常见搭配）、scene（同一生活场景）、root（同词根）。

输出 JSON：
{{
  "center": "{word}",
  "nodes": [
    {{"word": "关联词", "relation": "synonym", "zh": "中文意思", "strength": 0.9}}
  ],
  "edges": [
    {{"source": "{word}", "target": "关联词", "relation": "synonym", "strength": 0.9}}
  ]
}}

要求：
1. nodes 只要关联词，不要包含中心词本身；
2. word 必须是单个英文单词或不超过 3 个词的常用短语；
3. strength 是 0-1 的浮点数，表示关系强度；
4. 不要重复节点。"""


CONTEXT_SYSTEM_PROMPT = """你是一位擅长编写英语学习材料的作者。请输出严格的 JSON，不要输出 Markdown 代码块或任何额外文字。
内容要自然连贯、贴近真实生活，不要为了塞入单词而写成生硬的定义罗列。
每次写作都要换新的生活场景和叙述角度，避免千篇一律。"""

# 随机场景池：每次生成时抽一个，强迫模型换主题，而不是反复写“第一天上班”之类。
CONTEXT_SCENES = [
    "早高峰的地铁通勤",
    "周末在超市采购",
    "朋友聚餐点菜",
    "第一次去健身房",
    "搬家后整理新家",
    "在咖啡馆赶一份报告",
    "旅行途中向路人问路",
    "一次线上视频会议",
    "在图书馆复习备考",
    "露营的夜晚",
    "陪家人去医院复诊",
    "网购后申请退货",
    "学做一道新菜",
    "参加社区志愿活动",
    "现场看一场球赛",
    "手机坏了去维修店",
    "和室友商量家务分工",
    "在机场办理登机",
    "公司团建活动",
    "带宠物去宠物医院",
    "在银行办理业务",
    "音乐节现场",
    "雨天等公交",
    "周末逛二手市场",
    "在健身房遇到熟人",
    "深夜点外卖",
    "参加朋友的生日聚会",
    "在书店挑书",
]

CONTEXT_STORY_STYLES = [
    "第一人称日记",
    "第三人称小故事",
    "轻松幽默的叙述",
    "带一点悬念的叙述",
    "旅行手记式的叙述",
    "新闻报道式的叙述",
]

CONTEXT_DIALOGUE_STYLES = [
    "同事在午休时聊天",
    "朋友之间打电话",
    "店员和顾客的对话",
    "家人吃晚饭时的聊天",
    "同学在图书馆小声讨论",
    "邻居在电梯里闲聊",
]

_last_context_scene: str | None = None


def _pick_context_scene() -> str:
    """随机取一个场景，并避免和上一次生成重复。"""
    global _last_context_scene
    choices = [
        scene for scene in CONTEXT_SCENES if scene != _last_context_scene
    ]
    scene = random.choice(choices or CONTEXT_SCENES)
    _last_context_scene = scene
    return scene

CONTEXT_USER_TEMPLATE = """请用下面的目标单词，写一段适合英语学习者的{mode_cn}。
本次必须围绕这个具体场景展开：{scene}
叙述方式：{style}
目标单词：{words}

输出 JSON：
{{
  "title": "中文标题",
  "paragraphs": [
    {{"en": "英文段落或对话", "zh": "对应中文翻译"}}
  ],
  "used": ["实际用到的目标词"]
}}

要求：
1. 每个目标词至少自然出现一次，可以改变时态或单复数；
2. 英文难度 B1-B2，总长度 120-200 词，分 2-4 段；
3. 如果是对话，用 A: / B: 开头，保持口语自然；
4. 每段必须配准确的中文翻译；
5. 不要出现拼音、单词表或语法讲解；
6. 标题和内容必须体现上面指定的场景，不要写成“第一天上班”“新学期”“面试”这类默认题材，除非场景正好是它；
7. 换一个新的、具体的场景来写，不要重复常见模板。"""


async def generate_context(words: list[str], mode: str = "story") -> dict[str, Any]:
    mode = "dialogue" if mode == "dialogue" else "story"
    if not use_real_llm():
        return _mock_context(words, mode)

    mode_cn = "英语短文" if mode == "story" else "两人英语对话"
    scene = _pick_context_scene()
    style = random.choice(
        CONTEXT_STORY_STYLES if mode == "story" else CONTEXT_DIALOGUE_STYLES
    )
    data = await _chat_json(
        CONTEXT_SYSTEM_PROMPT,
        CONTEXT_USER_TEMPLATE.format(
            mode_cn=mode_cn,
            scene=scene,
            style=style,
            words="、".join(words),
        ),
        temperature=0.95,
    )
    result = _normalize_context(words, mode, data)
    if not result["paragraphs"]:
        raise LLMError("生成内容为空，请重试")
    result["scene"] = scene
    return result


def _normalize_context(
    words: list[str],
    mode: str,
    data: dict[str, Any],
) -> dict[str, Any]:
    paragraphs = []
    for item in data.get("paragraphs") or []:
        if not isinstance(item, dict):
            continue
        en = str(item.get("en") or "").strip()
        zh = str(item.get("zh") or "").strip()
        if en:
            paragraphs.append({"en": en, "zh": zh})
    used = [
        str(word).strip()
        for word in (data.get("used") or [])
        if str(word).strip()
    ]
    return {
        "title": str(
            data.get("title")
            or ("语境短文" if mode == "story" else "语境对话")
        ).strip(),
        "mode": mode,
        "words": words,
        "paragraphs": paragraphs,
        "used": used,
    }


def _mock_context(words: list[str], mode: str) -> dict[str, Any]:
    return {
        "title": "Mock 语境",
        "mode": mode,
        "words": words,
        "paragraphs": [
            {
                "en": f"Today we practice these words: {', '.join(words)}.",
                "zh": "今天我们练习这些单词。",
            }
        ],
        "used": words,
    }


async def generate_word_card(word: str, definition_en: str = "") -> dict[str, Any]:
    if not use_real_llm():
        return _mock_card(word, definition_en)

    data = await _chat_json(
        WORD_SYSTEM_PROMPT,
        WORD_USER_TEMPLATE.format(word=word, definition=definition_en or "无"),
    )
    return _normalize_card(word, data)


LOCAL_IMAGE_SYSTEM_PROMPT = """你是一位给 SDXL 动漫模型写 Danbooru 标签提示词的美术指导。
只输出严格 JSON，不要输出 Markdown 或 JSON 之外的文字。
提示词必须是英文标签、逗号分隔、具体可画，让学习者看图就能猜到单词。"""

LOCAL_IMAGE_USER_TEMPLATE = """单词：{word}
中文释义：{zh}
英文释义：{en}
词性：{pos}
使用场景：{scenario}
例句：{example}

请写一段适合 SDXL 动漫模型出图的英文标签提示词，要求：
1. 用逗号分隔的 Danbooru 风格标签，15–25 个，不要整句自然语言；
2. 只允许一个主要人物；不要出现第二个人（不要 mother、child 等关系人物）；有人物的场景以 "1girl, solo" 或 "1boy, solo" 开头；
3. 具体名词（如 institution、apple）和抽象/程度/比较词（如 increase、ability）优先用 "no humans"，只画主体物体或地点，并让主体占画面 80%；比较词用两个物体的大小或数量对比；
4. 动词：一个人物 + 一个明确动作 + 一个关键物体，不要旁观者；
5. 必须包含构图标签：full body、upper body 或 close-up 三选一；
6. 包含环境与光线标签，例如 outdoors, day / indoors, classroom / night, rain；
5. 优先画例句里的关键物品和动作；例句不适合时，用最能体现词义的动作或前后对比；
6. 参考示例（只学思路）：
   increase → no humans, two stacks of coins on wooden table, left pile short, right pile tall, indoors, close-up
   protect → 1girl, solo, holding umbrella over a small cat, rain, outdoors, full body
   eventually → 1girl, solo, on stage, holding golden trophy, confetti, smiling, indoors, full body
7. 禁止出现：chart, arrow, diagram, text, signboard, engraved seal, brand name, university name, multiple people, simple background, centered composition, photorealistic, nsfw；也不要同时写 1girl 和 no humans；
8. 不要只画局部身体或孤立符号；物体要完整、清晰可辨。

输出 JSON：{{"prompt": "..."}}"""

# 本地生图提示词版本：规则调整后递增，旧卡片会在生图时重新改写
LOCAL_PROMPT_VERSION = "6"


async def generate_local_image_prompt(word: str, card: dict[str, Any]) -> str:
    """为本地卡通模型生成简短、具体的画面提示词。"""
    if not use_real_llm():
        return ""

    meanings = card.get("meanings") or []
    first = meanings[0] if meanings and isinstance(meanings[0], dict) else {}
    examples = card.get("examples") or []
    example = ""
    if examples and isinstance(examples[0], dict):
        example = str(examples[0].get("en") or "")
    data = await _chat_json(
        LOCAL_IMAGE_SYSTEM_PROMPT,
        LOCAL_IMAGE_USER_TEMPLATE.format(
            word=word,
            zh=str(first.get("zh") or ""),
            en=str(first.get("en") or ""),
            pos=", ".join(card.get("part_of_speech") or []) or "unknown",
            scenario=str(card.get("scenario") or ""),
            example=example or "(none)",
        ),
        temperature=0.6,
    )
    return str(data.get("prompt") or "").strip()


async def generate_graph(word: str) -> dict[str, Any]:
    if not use_real_llm():
        return _mock_graph(word)

    data = await _chat_json(GRAPH_SYSTEM_PROMPT, GRAPH_USER_TEMPLATE.format(word=word))
    return _normalize_graph(word, data)


def _normalize_card(word: str, data: dict[str, Any]) -> dict[str, Any]:
    card = {
        "word": data.get("word") or word,
        "phonetic_us": data.get("phonetic_us") or "",
        "phonetic_uk": data.get("phonetic_uk") or "",
        "part_of_speech": data.get("part_of_speech") or [],
        "meanings": data.get("meanings") or [],
        "examples": data.get("examples") or [],
        "collocations": data.get("collocations") or [],
        "word_family": data.get("word_family") or [],
        "synonyms": data.get("synonyms") or [],
        "antonyms": data.get("antonyms") or [],
        "etymology": data.get("etymology") or "",
        "memory_tip": data.get("memory_tip") or "",
        "scenario": data.get("scenario") or "",
        "image_prompt": data.get("image_prompt")
        or f"a realistic everyday scene that literally shows the meaning of {word}",
        "image_prompt_local": data.get("image_prompt_local") or "",
        "local_prompt_version": LOCAL_PROMPT_VERSION,
    }
    return card


def _normalize_graph(word: str, data: dict[str, Any]) -> dict[str, Any]:
    nodes = []
    seen: set[str] = set()
    for item in data.get("nodes") or []:
        related = str(item.get("word", "")).strip()
        if not related or related.lower() == word.lower() or related.lower() in seen:
            continue
        seen.add(related.lower())
        nodes.append(
            {
                "word": related,
                "relation": item.get("relation") or "scene",
                "zh": item.get("zh") or "",
                "strength": float(item.get("strength") or 0.5),
            }
        )
    edges = [
        {
            "source": word,
            "target": node["word"],
            "relation": node["relation"],
            "strength": node["strength"],
        }
        for node in nodes
    ]
    return {"center": word, "nodes": nodes, "edges": edges}


def _mock_card(word: str, definition_en: str) -> dict[str, Any]:
    definition = definition_en or f"the meaning of {word}"
    return {
        "word": word,
        "phonetic_us": "",
        "phonetic_uk": "",
        "part_of_speech": [],
        "meanings": [{"pos": "", "zh": "（Mock 模式：配置 API Key 后生成真实释义）", "en": definition}],
        "examples": [
            {
                "en": f"I use the word \"{word}\" in everyday conversation.",
                "zh": f"我在日常对话中会用到 {word} 这个词。",
            }
        ],
        "collocations": [],
        "word_family": [],
        "synonyms": [],
        "antonyms": [],
        "etymology": "",
        "memory_tip": "在真实场景中反复使用，比孤立背诵更容易记住。",
        "scenario": "日常交流",
        "image_prompt": f"a realistic everyday scene illustrating the word {word}, no text",
    }


def _mock_graph(word: str) -> dict[str, Any]:
    return {"center": word, "nodes": [], "edges": []}

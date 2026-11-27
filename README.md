# WordLoop 智能背单词

面向大学生与职场人的背单词应用：基于 SSP-MMC 记忆算法安排复习，由大模型生成单词卡、例句语音与场景配图，并提供可交互的单词网络和语境阅读。

- 客户端：Flutter（Android / Web）
- 后端：FastAPI + SQLite
- 词库：NGSL 高频词约 2800 个
- 文本模型：任意 OpenAI 兼容接口（当前使用阿里云百炼 `qwen-plus`）
- 配图：本地 Stable Diffusion Forge（NoobAI-XL）优先，云端 `qwen-image` 兜底

---

## 一、目录结构

```
WordLoop/
├── app/                 Flutter 客户端
│   ├── lib/             页面、状态、调度与 API 封装
│   ├── android/         Android 工程
│   └── web/             Web 入口
├── backend/             FastAPI 后端
│   ├── app/
│   │   ├── routers/     words / ai / graph / review 接口
│   │   ├── services/    llm、image_gen、ssp_mmc、memory
│   │   └── data/        words_seed.json、policy.json
│   ├── scripts/         NGSL 导入、预生成脚本
│   └── tests/
├── NGSL/                NGSL 原始词表
├── share/               网页版 APK 下载页
├── benchmarks/          提示词/模型对比页
└── sd-models/           本地生图模型目录（不进仓库）
```

---

## 二、环境要求

| 组件 | 版本 / 说明 |
|---|---|
| 操作系统 | Windows 10/11（macOS/Linux 同理，命令自行替换） |
| Python（后端） | 3.12，建议单独建虚拟环境 |
| Flutter | 需 Dart `>= 3.14`，建议最新 stable |
| Java | JDK 17（仅打 Android 包需要） |
| 显卡（可选） | 本地生图建议 NVIDIA 8GB 显存以上，本项目在 RTX 4060 Laptop 8G 验证 |
| Python（本地生图） | 3.10.x，与 Forge 配套 |

> 路径尽量使用纯英文。项目路径含中文时 Web 构建正常，但 Android Gradle 打包可能失败，可将 `app` 复制到 `D:\dev\wordloop_build` 等纯英文目录再打包。

---

## 三、启动后端

```powershell
cd backend

# 1. 创建虚拟环境
python -m venv .venv
.venv\Scripts\activate

# 2. 安装依赖
pip install -r requirements.txt

# 3. 准备配置
copy .env.example .env
# 编辑 .env，填入下面的配置
```

### `.env` 推荐配置

```ini
# 文本模型（变量名沿用 DEEPSEEK_*，可指向任意 OpenAI 兼容服务）
DEEPSEEK_API_KEY=你的百炼_API_Key
DEEPSEEK_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
DEEPSEEK_MODEL=qwen-plus

# 云端生图（可选，本地 Forge 不可用时兜底）
DASHSCOPE_API_KEY=你的百炼_API_Key
DASHSCOPE_BASE_URL=https://dashscope.aliyuncs.com
IMAGE_MODEL=qwen-image-3.0
IMAGE_SIZE=768*768

# 本地生图（不启用本地就留空）
LOCAL_SD_URL=http://127.0.0.1:7860
LOCAL_SD_MODEL=NoobAI-XL-v1.1.safetensors
LOCAL_SD_STYLE=amazing quality, very aesthetic, safe, bright colors, clear lighting
LOCAL_SD_STEPS=28
LOCAL_SD_CFG=5
LOCAL_SD_WIDTH=832
LOCAL_SD_HEIGHT=832
LOCAL_SD_SAMPLER=Euler a

# auto：有 Key 调真实模型；mock：强制本地模拟；real：强制真实模型
AI_MODE=auto
```

> `.env` 含密钥，**不要提交到 Git**。仓库只保留 `.env.example`。
> 没有文本 Key 时后端以 mock 模式返回示例数据，方便前端联调。

### 启动

```powershell
.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

- 接口文档：<http://127.0.0.1:8000/docs>
- 健康检查：<http://127.0.0.1:8000/api/health>
- 首次启动会自动建表，并从 `app/data/words_seed.json` 导入词库。

---

## 四、启动客户端

### 1. Web 版

```powershell
cd app
flutter pub get
flutter run -d chrome
```

或构建后本地静态托管：

```powershell
flutter build web --release
python -m http.server 8080 --directory build/web
# 打开 http://127.0.0.1:8080
```

### 2. Android APK

```powershell
cd app
flutter build apk --release
# 产物：build\app\outputs\flutter-apk\app-release.apk
```

安装后打开 App → **设置 → 内容服务 → 后端地址**，填写电脑的局域网地址，例如：

```
http://192.168.1.100:8000
```

保存后点“测试连接”。手机与电脑需在同一 Wi-Fi，Windows 防火墙需放行 8000 端口。

> Web 端默认后端地址是 `http://127.0.0.1:8000`；Android 模拟器是 `http://10.0.2.2:8000`。

---

## 五、模型说明

### 1. 文本模型（单词卡、语境、单词网络）

- 当前：阿里云百炼 `qwen-plus`，OpenAI 兼容模式
- 也可换成 DeepSeek、通义其他模型或自建 OpenAI 兼容服务，只改 `DEEPSEEK_BASE_URL` / `DEEPSEEK_MODEL`
- 输出统一走 JSON 模式，代码见 `backend/app/services/llm.py`

### 2. 云端生图（兜底）

- 模型：`qwen-image-3.0`（也支持 `qwen-image-3.0-pro`）
- 单张约 10–20 秒，需 `DASHSCOPE_API_KEY`
- 请求逻辑见 `backend/app/services/image_gen.py` 的 `_generate_cloud`

### 3. 本地生图（推荐，免费离线）

**模型**：NoobAI-XL v1.1（SDXL 动漫模型，约 6.6 GB）
下载地址（国内镜像）：

```powershell
mkdir sd-models
curl.exe -L -o sd-models/NoobAI-XL-v1.1.safetensors `
  https://hf-mirror.com/Laxhar/noobai-XL-1.1/resolve/main/NoobAI-XL-v1.1.safetensors
```

**运行环境**：Stable Diffusion WebUI Forge（A1111 兼容 API）
首次部署步骤：

1. 安装 Python 3.10.x（例如 `D:\dev\python310`），记住 `python.exe` 路径；
2. 下载 Forge（本项目验证版本 `f2.0.1`）解压到纯英文路径，例如 `D:\dev\sd-forge`；
3. 首次运行 `webui-user.bat`，让它自动创建 `venv310` 并安装依赖；国内可用清华 pip 源、阿里云 torch 轮子（CUDA 12.1）；
4. 修改 `webui-user.bat`：

```bat
set PYTHON=D:\dev\python310\python.exe
set VENV_DIR=venv310
set COMMANDLINE_ARGS=--api --listen --port 7860 --skip-install --ckpt-dir "d:/你的路径/WordLoop/sd-models"
```

5. 启动后访问 <http://127.0.0.1:7860/sdapi/v1/options> 能返回 JSON 即成功；
6. 后端 `.env` 设置 `LOCAL_SD_URL=http://127.0.0.1:7860`，重启后端。

**参数建议（8GB 显存）**

- 832×832、28 步、CFG 5、Euler a、CLIP skip 2
- 不建议 1024×1024，容易显存不足
- 单张约 15–19 秒（RTX 4060 Laptop）

**常见问题：生成时报下载 `vaeapprox-sdxl.pt` 失败**
Forge 的实时预览需要近似 VAE，国内下载不到。进入 Forge 设置，把进度预览改为 `Simple`（或关闭 Live previews），再重启 Forge。

> 本地失败且配置了 `DASHSCOPE_API_KEY` 时，后端会自动回退云端生图；两者都没有时接口返回错误。

---

## 六、数据库与词库

- SQLite 文件：`backend/data/app.db`（首次启动自动创建）
- 配图缓存：`backend/data/images/`
- 种子词库：`backend/app/data/words_seed.json`
- 重新导入 NGSL 词表：

```powershell
cd backend
python scripts/import_ngsl.py
```

重置数据：停止后端，删除 `backend/data/app.db` 与 `backend/data/images/` 后重启。

---

## 七、测试与检查

```powershell
# 客户端
cd app
flutter analyze
flutter test

# 后端
cd backend
.venv\Scripts\python.exe -m pytest
```

---

## 八、协作约定

1. 不要提交 `.env`、`backend/data/`、模型文件、APK、构建产物；
2. 新功能从 `main` 拉分支：`git checkout -b feat/xxx`，完成后提 PR；
3. 提交前至少跑通 `flutter analyze`、`flutter test`；
4. 接口字段变更要同步更新 `app/lib/services/api_client.dart` 与后端 schema；
5. 生图提示词规则改动时，递增 `LOCAL_PROMPT_VERSION`，旧缓存会自动重写。

---

## 九、常见问题

| 现象 | 处理 |
|---|---|
| 手机连不上后端 | 确认同一 Wi-Fi、后端监听 `0.0.0.0:8000`、防火墙放行、IP 未变化 |
| 8080 页面还是旧版本 | Flutter Web 有 Service Worker 缓存，`Ctrl+Shift+R` 强刷或换端口 |
| 生图很慢 | 使用本地 Forge；确认 `LOCAL_SD_URL` 生效；避免 1024 分辨率 |
| 图与单词不搭 | 本地模型对抽象词能力有限；可在 `.env` 关闭本地（清空 `LOCAL_SD_URL`）改用云端 |
| APK 打包失败且路径含中文 | 把 `app` 复制到纯英文路径再 `flutter build apk` |
| 单词发音无声 | 检查系统 TTS 语音包；Web 端受浏览器语音支持限制 |

---

## 十、主要接口

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/health` | 服务状态与模型模式 |
| GET | `/api/words` | 词库分页/筛选 |
| GET | `/api/words/{id}` | 单个单词详情 |
| POST | `/api/review/plan` | 提交掌握度并计算下次复习时间 |
| GET | `/api/review/policy` | 查询记忆算法参数 |
| GET | `/api/ai/words/{id}/card` | 读取已缓存的单词卡 |
| POST | `/api/ai/words/{id}/card` | 生成单词卡 |
| POST | `/api/ai/words/{id}/image` | 生成单词配图 |
| POST | `/api/ai/image-by-text` | 非词库词按文本生图 |
| POST | `/api/ai/context` | 生成语境短文/对话 |
| GET/POST | `/api/graph` | 单词网络 |

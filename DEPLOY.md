# GLM-5 部署指南

本文档包含 GLM-5 模型通过 llama.cpp 的完整部署流程。GLM-5 为纯文本 LLM，直接使用 llama-server 提供 OpenAI 兼容 API。

---

## 必须修改的配置

在开始部署之前，请确认以下路径配置：

| 变量 | 说明 | 示例值 |
|------|------|--------|
| `CPP_DIR` | llama.cpp 编译后的根目录 | `/path/to/glm-5-deploy/llama.cpp` |
| `MODEL_DIR` | GGUF 模型目录（含分片文件） | `/path/to/glm-5-deploy/models/GLM-5-GGUF/UD-IQ2_XXS` |

---

## 目录结构

### 本部署包（已包含）
```
./
├── deploy.sh              # 一键部署脚本
├── DEPLOY.md              # 本文档
├── download_models.sh     # 模型下载脚本
├── requirements.txt       # Python 依赖
├── .venv/                 # Python 虚拟环境（需创建）
├── docs/
│   └── architecture.md    # 架构说明
├── llama.cpp/             # 需 clone 并编译
└── models/                # 模型目录（需下载）
```

### 用户需要准备
```
<CPP_DIR>/
└── build/bin/llama-server   # 编译后的 C++ 服务端

<MODEL_DIR>/
└── GLM-5-UD-IQ2_XXS-00001-of-00006.gguf   # 分片文件（llama-server 自动加载同目录所有分片）
```

---

## 一、前置条件

### 1. 编译 C++ 推理服务

GLM-5 需要 **官方 llama.cpp** 并应用 **PR 19460**。

**方式一：使用脚本（推荐）**

```bash
cd /path/to/glm-5-deploy
./setup_llamacpp.sh
```

**方式二：手动执行**

```bash
cd /path/to/glm-5-deploy/llama.cpp

# 应用 PR 19460（GLM-5 支持，若获取失败可跳过，可能已合并）
git fetch origin pull/19460/head:MASTER
git checkout MASTER

# 编译（macOS 自动启用 Metal 加速）
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --target llama-server llama-cli -j

# 验证
ls -la build/bin/llama-server
```

### 2. 创建 Python 虚拟环境（用于模型下载）

```bash
cd /path/to/glm-5-deploy
python3 -m venv .venv
source .venv/bin/activate   # macOS/Linux
pip install -r requirements.txt
```

---

## 二、模型下载

```bash
cd /path/to/glm-5-deploy

# 使用 .venv
source .venv/bin/activate

# 下载 2-bit 量化版（约 241GB，推荐 512GB Apple Studio）
./download_models.sh

# 或指定 1-bit 版本（约 176GB）
QUANT=UD-TQ1_0 ./download_models.sh
```

---

## 三、服务部署

### 1. 设置环境变量

```bash
export CPP_DIR="/path/to/glm-5-deploy/llama.cpp"
export MODEL_DIR="/path/to/glm-5-deploy/models/GLM-5-GGUF/UD-IQ2_XXS"
```

### 2. 一键部署

```bash
./deploy.sh --cpp-dir "$CPP_DIR" --model-dir "$MODEL_DIR"
```

### 2.1 认证与局域网访问（可选）

启用 API Key 认证（推荐在局域网或公网暴露时使用）：

```bash
# 单 Key 认证
./deploy.sh --cpp-dir "$CPP_DIR" --model-dir "$MODEL_DIR" --api-key "sk-your-secret-key"

# 多 Key（密钥文件，每行一个）
echo -e "sk-key-1\nsk-key-2" > api-keys.txt
./deploy.sh --cpp-dir "$CPP_DIR" --model-dir "$MODEL_DIR" --api-key-file api-keys.txt

# 认证 + 局域网访问
./deploy.sh --cpp-dir "$CPP_DIR" --model-dir "$MODEL_DIR" --api-key "sk-xxx" --lan
```

客户端需在请求头中携带：`Authorization: Bearer <你的API-Key>`。

### 3. 手动启动

```bash
# 找到第一个分片文件
MODEL_FILE=$(ls "$MODEL_DIR"/*.gguf 2>/dev/null | head -1)

"$CPP_DIR/build/bin/llama-server" \
    --model "$MODEL_FILE" \
    --alias "unsloth/GLM-5" \
    --fit on \
    --temp 1.0 \
    --top-p 0.95 \
    --ctx-size 16384 \
    --port 8001 \
    --jinja
# 可选: --host 0.0.0.0 局域网访问, --api-key "sk-xxx" 或 --api-key-file PATH 认证
```

### 4. 后台运行

```bash
nohup "$CPP_DIR/build/bin/llama-server" \
    --model "$MODEL_FILE" \
    --alias "unsloth/GLM-5" \
    --fit on \
    --temp 1.0 \
    --top-p 0.95 \
    --ctx-size 16384 \
    --port 8001 \
    --jinja > /tmp/glm5_server.log 2>&1 &

# 查看日志（模型加载需数分钟）
tail -f /tmp/glm5_server.log
```

---

## 四、验证服务

```bash
# 健康检查（无认证时）
curl http://localhost:8001/health

# 健康检查（启用认证时）
curl -H "Authorization: Bearer sk-your-key" http://localhost:8001/health

# OpenAI 兼容 API 测试（无认证）
python3 -c "
from openai import OpenAI
client = OpenAI(base_url='http://127.0.0.1:8001/v1', api_key='sk-no-key-required')
r = client.chat.completions.create(model='unsloth/GLM-5', messages=[{'role':'user','content':'Hello'}])
print(r.choices[0].message.content)
"

# OpenAI 兼容 API 测试（启用认证时，api_key 填你的实际 key）
python3 -c "
from openai import OpenAI
client = OpenAI(base_url='http://127.0.0.1:8001/v1', api_key='sk-your-actual-key')
r = client.chat.completions.create(model='unsloth/GLM-5', messages=[{'role':'user','content':'Hello'}])
print(r.choices[0].message.content)
"
```

---

## 五、硬件与部署建议（Apple Silicon）

### 5.1 内存需求对照

| 量化版本 | 磁盘/内存占用 | 256GB Mac | 512GB Apple Studio |
|---------|----------------|-----------|---------------------|
| UD-IQ2_XXS (2-bit) | ~241GB | 可装 | 推荐，富余 |
| UD-TQ1_0 (1-bit) | ~176GB | 可装 | 推荐 |
| 8-bit | ~805GB RAM | 不可 | 不可 |

### 5.2 512GB Apple Studio 建议

- **量化版本**：UD-IQ2_XXS (2-bit)，约 241GB
- **结论**：512GB 统一内存大于 241GB，模型可完整载入内存，无需硬盘 offload，推理性能较好
- **编译**：macOS 使用默认 Metal 加速，`cmake -B build -DCMAKE_BUILD_TYPE=Release` 即可
- **启动参数**：`--fit on` 以充分利用 GPU/CPU

*参考：Unsloth 文档建议 VRAM + RAM 总和接近或大于量化模型大小，否则需硬盘 offload，推理会变慢。*

---

## 六、常用命令

### 推理服务管理
```bash
# 查看进程
ps aux | grep llama-server

# 停止服务
pkill -f "llama-server"

# 查看日志
tail -f /tmp/glm5_server.log
```

### 故障排查

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 模型加载超时 | 模型较大需数分钟 | 耐心等待，查看日志 |
| 端口被占用 | 8001 已被使用 | 使用 --port 指定其他端口 |
| 编译失败 | 缺少 PR 19460 | 确保 `git checkout MASTER` 已应用 |

---

## 七、关键配置

| 配置项 | GLM-5 值 |
|--------|----------|
| 默认端口 | 8001 |
| 模型路径 | `models/GLM-5-GGUF/UD-IQ2_XXS/*.gguf` |
| 推荐参数 | `--temp 1.0` `--top-p 0.95` `--ctx-size 16384` `--jinja` `--fit on` |
| 最大上下文 | 202752 |
| 认证 | `--api-key KEY` 或 `--api-key-file PATH` |
| 局域网访问 | `--host 0.0.0.0` 或 `--lan` |

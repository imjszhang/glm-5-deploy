#!/bin/bash
# GLM-5 GGUF 模型下载脚本
# 使用 huggingface_hub 下载 Unsloth 量化版本
# 支持断点续传

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODEL_DIR="${MODEL_DIR:-$SCRIPT_DIR/models/GLM-5-GGUF}"

# 量化版本：UD-IQ2_XXS (2-bit, ~241GB) 或 UD-TQ1_0 (1-bit, ~176GB)
QUANT="${QUANT:-UD-IQ2_XXS}"

# 使用项目 .venv 中的 Python（若存在）
if [ -f "$SCRIPT_DIR/.venv/bin/python" ]; then
    PYTHON_BIN="$SCRIPT_DIR/.venv/bin/python"
else
    PYTHON_BIN="${PYTHON_BIN:-$(which python3 2>/dev/null || which python 2>/dev/null)}"
fi

echo "========================================"
echo "GLM-5 GGUF 模型下载"
echo "========================================"
echo "目标目录: $MODEL_DIR"
echo "量化版本: $QUANT"
echo "Python:   $PYTHON_BIN"
echo "========================================"

# 确保 huggingface_hub 已安装
"$PYTHON_BIN" -c "import huggingface_hub" 2>/dev/null || {
    echo "正在安装 huggingface_hub 和 hf_transfer..."
    "$PYTHON_BIN" -m pip install -U huggingface_hub hf_transfer
}

# 创建目录
mkdir -p "$MODEL_DIR"

# 使用 huggingface_hub 下载（支持断点续传）
echo "开始下载 unsloth/GLM-5-GGUF (包含 *$QUANT*)..."
"$PYTHON_BIN" -c "
from huggingface_hub import snapshot_download
snapshot_download(
    repo_id='unsloth/GLM-5-GGUF',
    local_dir='$MODEL_DIR',
    allow_patterns=['*${QUANT}*'],
)
"

echo ""
echo "========================================"
echo "下载完成！文件列表："
echo "========================================"
find "$MODEL_DIR" -name "*.gguf" -exec ls -lh {} \;

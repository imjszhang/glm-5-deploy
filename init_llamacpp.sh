#!/bin/bash
# 克隆 llama.cpp 到项目目录（若尚未存在）
# 用于首次部署或从 GitHub 克隆本项目后的初始化

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CPP_DIR="${CPP_DIR:-$SCRIPT_DIR/llama.cpp}"

if [ -d "$CPP_DIR/.git" ]; then
    echo "llama.cpp 已存在，跳过克隆"
    exit 0
fi

echo "正在克隆 llama.cpp..."
git clone https://github.com/ggml-org/llama.cpp "$CPP_DIR"
echo "完成！可执行 ./setup_llamacpp.sh 进行编译"

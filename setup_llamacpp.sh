#!/bin/bash
# llama.cpp 编译脚本（含 GLM-5 所需 PR 19460）
# 若网络较慢，可分别执行各步骤

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CPP_DIR="${CPP_DIR:-$SCRIPT_DIR/llama.cpp}"

echo "========================================"
echo "llama.cpp 编译 (GLM-5 支持)"
echo "========================================"
echo "CPP_DIR: $CPP_DIR"
echo ""

cd "$CPP_DIR"

# 1. 应用 PR 19460（GLM-5 支持）
echo "[1/3] 获取 PR 19460..."
if git fetch origin pull/19460/head:MASTER 2>/dev/null; then
    git checkout MASTER
    echo "  已切换到 PR 19460 分支"
else
    echo "  警告: 获取 PR 19460 失败（可能已合并到 main 或网络问题）"
    echo "  将继续使用当前分支编译"
fi

# 2. 配置
echo "[2/3] CMake 配置..."
cmake -B build -DCMAKE_BUILD_TYPE=Release

# 3. 编译
echo "[3/3] 编译 llama-server..."
cmake --build build --target llama-server llama-cli -j

echo ""
echo "完成！llama-server: $CPP_DIR/build/bin/llama-server"

#!/bin/bash
# 启动前端静态服务（聊天 + 监控）
# 因 API Key 认证会拦截 llama-server 的静态文件，需单独启动
# 内置 /api 代理，自动读取 .api-key，无需手动输入密钥

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
exec python3 serve-ui.py

#!/bin/bash

# VoiceX FunASR Server 启动脚本 - 最终极简稳定版

set -e

# 定义offline和online模型路径
export model_dir="damo/speech_paraformer-large_asr_nat-zh-cn-16k-common-vocab8404-onnx"
export online_model_dir="damo/speech_paraformer-large_asr_nat-zh-cn-16k-common-vocab8404-online-onnx"
export download_model_dir="/workspace/models"

# 禁用SSL
export certfile=""
export keyfile=""

# 修正热词文件路径
export hotword="/workspace/FunASR/runtime/websocket/hotwords.txt"

# --- 服务器核心参数 ---
port=10095
decoder_thread_num=$(cat /proc/cpuinfo | grep "processor"|wc -l) || decoder_thread_num=8
io_thread_num=2
model_thread_num=1
cmd_path=/workspace/FunASR/runtime/websocket/build/bin
cmd=funasr-wss-server-2pass

echo "Starting FunASR WebSocket Server (Final Minimal Stable Version)..."

# --- 配置2pass模式：同时使用offline和online模型 ---
exec ${cmd_path}/${cmd} \
  --download-model-dir "${download_model_dir}" \
  --model-dir "${model_dir}" \
  --online-model-dir "${online_model_dir}" \
  --port ${port} \
  --certfile "${certfile}" \
  --keyfile "${keyfile}" \
  --hotword "${hotword}" \
  --decoder-thread-num ${decoder_thread_num} \
  --io-thread-num ${io_thread_num} \
  --model-thread-num ${model_thread_num}
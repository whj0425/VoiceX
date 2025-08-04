#!/bin/bash

# VoiceX FunASR Server 启动脚本 - 前台运行版本
# 基于原始run_server_2pass.sh，修改为前台运行

set -e

download_model_dir="/workspace/models"
model_dir="damo/speech_paraformer-large_asr_nat-zh-cn-16k-common-vocab8404-onnx"
online_model_dir="damo/speech_paraformer-large_asr_nat-zh-cn-16k-common-vocab8404-online-onnx"
vad_dir="damo/speech_fsmn_vad_zh-cn-16k-common-onnx"
punc_dir="damo/punc_ct-transformer_zh-cn-common-vad_realtime-vocab272727-onnx"
itn_dir="thuduj12/fst_itn_zh"
lm_dir="damo/speech_ngram_lm_zh-cn-ai-wesp-fst"
port=10095
certfile="$(pwd)/ssl_key/server.crt"
keyfile="$(pwd)/ssl_key/server.key"
hotword="$(pwd)/websocket/hotwords.txt"

# 设置线程数
decoder_thread_num=$(cat /proc/cpuinfo | grep "processor"|wc -l) || { echo "Get cpuinfo failed. Set decoder_thread_num = 32"; decoder_thread_num=32; }
multiple_io=16
io_thread_num=$(( (decoder_thread_num + multiple_io - 1) / multiple_io ))
model_thread_num=1
cmd_path=/workspace/FunASR/runtime/websocket/build/bin
cmd=funasr-wss-server-2pass

# 解析命令行参数
. /workspace/FunASR/runtime/tools/utils/parse_options.sh || exit 1;

# 如果设置certfile为0，则禁用SSL
if [ -z "$certfile" ] || [ "$certfile" = "0" ]; then
  certfile=""
  keyfile=""
fi

echo "Starting FunASR WebSocket Server..."
echo "Download model dir: $download_model_dir"
echo "Model dir: $model_dir"
echo "Online model dir: $online_model_dir"
echo "VAD dir: $vad_dir"
echo "Punc dir: $punc_dir"
echo "Port: $port"
echo "Decoder threads: $decoder_thread_num"

# 切换到二进制文件目录
cd $cmd_path

# 保存服务器配置
server_cmd="{\"server\":[{\"exec\":\"${cmd_path}/${cmd}\",\"--download-model-dir\":\"${download_model_dir}\",\"--model-dir\":\"${model_dir}\",\"--online-model-dir\":\"${online_model_dir}\",\"--vad-dir\":\"${vad_dir}\",\"--punc-dir\":\"${punc_dir}\",\"--itn-dir\":\"${itn_dir}\",\"--lm-dir\":\"${lm_dir}\",\"--decoder-thread-num\":\"${decoder_thread_num}\",\"--model-thread-num\":\"${model_thread_num}\",\"--io-thread-num\":\"${io_thread_num}\",\"--port\":\"${port}\",\"--certfile\":\"${certfile}\",\"--keyfile\":\"${keyfile}\",\"--hotword\":\"${hotword}\"}]}"
mkdir -p /workspace/.config
echo $server_cmd > /workspace/.config/server_config

# 前台运行服务器 - 移除后台运行的&符号
echo "Executing: ${cmd_path}/${cmd} with parameters..."
exec ${cmd_path}/${cmd} \
  --download-model-dir "${download_model_dir}" \
  --model-dir "${model_dir}" \
  --online-model-dir "${online_model_dir}" \
  --vad-dir "${vad_dir}" \
  --punc-dir "${punc_dir}" \
  --itn-dir "${itn_dir}" \
  --lm-dir "${lm_dir}" \
  --decoder-thread-num ${decoder_thread_num} \
  --model-thread-num ${model_thread_num} \
  --io-thread-num ${io_thread_num} \
  --port ${port} \
  --certfile "${certfile}" \
  --keyfile "${keyfile}" \
  --hotword "${hotword}"
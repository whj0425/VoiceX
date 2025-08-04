# VoiceX Worker - FunASR WebSocket 服务

基于阿里云FunASR的语音识别WebSocket服务，支持实时语音识别。

## 文件说明

### 核心文件
- `Dockerfile` - Docker镜像构建文件
- `start_server.sh` - 服务启动脚本（前台运行版本）
- `run_worker.sh` - 容器管理脚本

### 模型文件
- `models/` - 存储所有ASR模型文件
  - `damo/speech_fsmn_vad_zh-cn-16k-common-onnx/` - VAD语音活动检测模型
  - `damo/speech_paraformer-large_asr_nat-zh-cn-16k-common-vocab8404-onnx/` - 离线ASR模型
  - `damo/speech_paraformer-large_asr_nat-zh-cn-16k-common-vocab8404-online-onnx/` - 在线ASR模型
  - `damo/punc_ct-transformer_zh-cn-common-vad_realtime-vocab272727-onnx/` - 标点符号模型
  - `damo/speech_ngram_lm_zh-cn-ai-wesp-fst/` - 语言模型
  - `thuduj12/fst_itn_zh/` - 逆文本标准化模型

## 使用方法

### 启动服务
```bash
./run_worker.sh
```

### 其他操作
```bash
./run_worker.sh stop     # 停止服务
./run_worker.sh restart  # 重启服务
./run_worker.sh logs     # 查看日志
./run_worker.sh status   # 查看状态
./run_worker.sh clean    # 清理所有资源
```

## 服务信息

- **容器名称**: voicex-worker-container
- **端口映射**: localhost:10096 → 容器内10095
- **协议**: WebSocket over SSL/TLS
- **内存限制**: 32GB
- **CPU限制**: 8核

## 服务持久化

- 容器使用 `--restart=unless-stopped` 策略
- 关闭终端不会影响服务运行
- 关闭Docker Desktop也不会停止容器（除非设置了停止所有容器）
- 需要手动停止或重启系统才会终止服务

## 健康检查

服务包含自动健康检查：
- 检查间隔：30秒
- 启动宽限期：180秒
- 超时时间：10秒
- 重试次数：3次
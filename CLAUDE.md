# VoiceX 项目开发记录

## 项目概述
VoiceX 是一个基于 FunASR、Docker 和 `launchd` 的 macOS 实时听写应用，采用"Worker-Supervisor-Client"三层架构。

## 第一阶段：Worker 核心引擎 ✅ 完成 (2025-08-04)

### 核心配置
- **服务**: `funasr-wss-server-2pass` 
- **端口**: localhost:10096 → 容器10095
- **模型**: offline + online 双模型2pass模式
- **协议**: WebSocket + 2pass streaming

### 关键文件
```
/worker/
├── start_server.sh        # 2pass服务启动脚本
├── run_worker.sh          # 容器管理脚本  
└── Dockerfile             # 镜像构建

/tests/
├── test_streaming.py      # 流式识别测试客户端
└── test2.wav             # 测试音频(16k,16bit,mono)
```

### 技术要点
1. **2pass模式**: 同时配置`--model-dir`(offline)和`--online-model-dir`(online)
2. **客户端协议**: 使用`"mode": "2pass", "chunk_size": [5,10,5]`
3. **实时性能**: 每1-2秒返回中间结果，模式`2pass-online`

### 验证成功
```bash
cd tests && python3 test_streaming.py --audio_in test2.wav
# 结果: 97个实时中间结果 + 高精度最终结果
```

## 下一阶段计划

### 第二阶段：Supervisor 守护服务
**目标**: 使用macOS `launchd`实现容器自动化管理  
**任务**: 编写.plist配置，实现永不宕机的守护进程

### 第三阶段：Client 客户端应用  
**目标**: 开发macOS App，实现音频采集和WebSocket连接  
**任务**: AVFoundation音频处理 + Network框架连接

### 第四阶段：功能集成与优化
**目标**: 完成"隔空打字"功能和压力测试  
**任务**: CGEvent键盘模拟 + 稳定性验证

## 基本操作
```bash
cd /Users/CodeProjects/VoiceX/worker
./run_worker.sh              # 启动
./run_worker.sh restart      # 重启  
./run_worker.sh logs         # 查看日志
```
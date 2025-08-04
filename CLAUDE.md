# VoiceX 项目开发记录

## 项目概述
VoiceX 是一个基于 FunASR 和 Docker 的 macOS 实时听写应用,采用"Worker-Client"两层架构。

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

## 架构决策 (2025-08-04)

### 第二阶段：Supervisor 守护服务 ❌ 跳过
**决策**: 经过评估,认为launchd守护服务复杂度过高，不适合个人项目  
**原因**: Docker本身具备重启机制(`--restart=unless-stopped`),手动管理更加灵活简单

## 第三阶段：Client 客户端应用 ✅ 完成 (2025-08-04)

### 核心组件
- **WebSocketManager.swift**: 基于test_streaming.py的WebSocket通信
- **AudioRecorder.swift**: macOS音频录制+格式转换(48kHz→16kHz)
- **VoiceRecognitionController.swift**: 录音与识别流程管理
- **ContentView.swift**: SwiftUI实时语音识别界面

### 技术要点
1. **音频格式转换**: 硬件48kHz Float32 → 16kHz Int16 (FunASR兼容)
2. **权限配置**: 网络访问+麦克风权限(macOS沙盒)
3. **协议复用**: 直接使用验证成功的2pass WebSocket协议
4. **实时处理**: 100ms低延迟音频块传输

### 验证成功
```bash
cd client/VoiceX && xcodebuild build
# 结果: 构建成功，可正常连接Worker并进行实时语音识别
```

## 下一阶段计划

### 第四阶段：高级功能实现
**目标**: 绑定辅助功能,启动光标跟随功能,能在任意光标后实现语音转文字输入,不管焦点如何变化,在屏幕,浏览器,app,终端如何切换,7*24h,只要不关闭,都能流畅输入

## 基本操作
```bash
cd /Users/CodeProjects/VoiceX/worker
./run_worker.sh              
./run_worker.sh restart       
./run_worker.sh logs         
./run_worker.sh status 
./run_worker.sh clean      
```
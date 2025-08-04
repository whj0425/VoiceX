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

## 第四阶段：全局光标注入功能 ✅ 基本完成 (2025-08-05)

### 核心实现
- **TextInjectionManager.swift**: 基于CGEvent的跨应用文本注入引擎
- **辅助功能权限**: 禁用macOS沙盒，成功获取系统级文本输入权限
- **实时注入**: 语音识别结果直接注入到任意应用的光标位置

### 技术突破
1. **权限解决方案**: `app-sandbox = false` → 正常弹出辅助功能权限请求
2. **CGEvent文本注入**: UTF-16编码 + keyboardSetUnicodeString API
3. **实时流式处理**: 移除"最终结果"等待逻辑，直接处理中间结果

### 关键Debug过程 (2025-08-05)
**问题**: 文本注入功能失效
```
【中间】 识别结果: 注入
📝 识别结果处理:
   - isFinal: false
   - textInjectionManager存在: true  
   - 注入已启用: true
⏭️ 跳过注入 - 条件不满足
```

**根本原因**: 
- ❌ **错误逻辑**: 等待 `isFinal: true` 的最终结果
- ✅ **正确逻辑**: 实时流式24h语音识别本身没有"最终结果"概念

**解决方案**:
```swift
// 修改前：只注入最终结果
if textInjectionManager.isInjectionEnabled && isFinal {
    textInjectionManager.injectText(text)
}

// 修改后：注入所有结果但去重
if textInjectionManager.isInjectionEnabled && 
   text != lastInjectedText && !text.isEmpty {
    textInjectionManager.injectText(text)  
    lastInjectedText = text
}
```

### 当前状态
- ✅ 基本注入功能工作正常
- ⚠️ **遗留问题**: 仍有重复注入现象（注入两遍） !!!重要
- 🎯 **下次优化**: 进一步完善去重逻辑

### 验证成功
- 可在任意应用（浏览器、终端、编辑器）中进行语音转文字
- 辅助功能权限配置成功
- 跨应用文本注入技术验证通过

## 基本操作
```bash
cd /Users/CodeProjects/VoiceX/worker
./run_worker.sh              
./run_worker.sh restart       
./run_worker.sh logs         
./run_worker.sh status 
./run_worker.sh clean      
```
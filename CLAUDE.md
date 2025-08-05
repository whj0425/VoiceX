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
```

### 技术要点
1. **2pass模式**: 同时配置`--model-dir`(offline)和`--online-model-dir`(online)
2. **客户端协议**: 使用`"mode": "2pass", "chunk_size": [5,10,5]`

## 第三阶段：macOS 客户端应用 ✅ 完成 (2025-08-04)

### 核心组件
- **WebSocketManager.swift**: WebSocket通信
- **AudioRecorder.swift**: 音频录制+格式转换(48kHz→16kHz)
- **VoiceRecognitionController.swift**: 录音与识别流程管理
- **ContentView.swift**: SwiftUI界面

### 技术要点
1. **音频格式转换**: 硬件48kHz Float32 → 16kHz Int16 (FunASR兼容)
2. **权限配置**: 网络访问+麦克风权限
3. **实时处理**: 100ms低延迟音频块传输

## 第四阶段：应用情景感知的自适应文本注入策略 ✅ 完成 (2025-08-05)

### 核心实现
- **ApplicationDetector.swift**: 检测当前活动应用
- **TextInjectionManager.swift**: 增强型文本注入引擎
  - `delete()`: 模拟退格键删除字符
  - `replace()`: 删除旧文本→注入新文本
  - `injectText()`: 基本文本注入
- **VoiceRecognitionController.swift**: 自适应策略控制器
  - `handleStandardStrategy()`: 普通应用实时替换策略
  - `handleTerminalStrategy()`: 终端应用最终注入策略

### 技术突破
1. **权限解决方案**: `app-sandbox = false` → 辅助功能权限
2. **应用识别**: 自动检测Terminal.app等特殊应用
3. **策略切换**: 根据应用类型自动选择注入策略
4. **实时替换**: "你好"→"你好世"→"你好世界" 无重复累加

### 策略效果
- **普通应用**: 实时替换，流畅的修正体验
- **终端应用**: 仅注入最终结果，避免命令行干扰

## 第五阶段：菜单栏应用改造 ✅ 完成 (2025-08-05)

### 设计目标
将当前Dock栏应用改造为菜单栏应用，提供更简洁的用户体验。

### 核心功能
- **主开关**: 启动应用后菜单栏显示一个开关按钮
- **一键启用**: 开关打开 = 同时启用实时语音识别 + 光标注入
- **状态指示**: 菜单栏图标显示当前工作状态
- **设置面板**: 将当前界面内容转移到设置面板中


### 界面设计
```
菜单栏:
├── VoiceX 图标 (状态指示)
└── 下拉菜单:
    ├── [√] 启用语音识别     # 主开关
    ├── ────────────────
    ├── 设置...              # 打开设置窗口
    └── 退出
```


### 设置窗口内容
- 连接状态显示
- 重新连接功能
- 菜单栏使用说明

### Release构建和分发
- **构建脚本**: `build_release.sh` 一键构建Release版本
- **固定位置**: `./release/VoiceX.app` 总是最新构建版本
- **使用方法**: 
  ```bash
  ./build_release.sh    # 构建最新版本
  open ./release/VoiceX.app    # 双击运行
  cp -R ./release/VoiceX.app /Applications/    # 安装到系统
  ```
- **配置验证**: 自动检查LSUIElement等关键配置

## 基本操作

### Worker服务管理
```bash
cd /Users/CodeProjects/VoiceX/worker
./run_worker.sh              # 启动服务
./run_worker.sh restart       # 重启服务
./run_worker.sh logs         # 查看日志
./run_worker.sh status       # 检查状态
./run_worker.sh clean        # 清理容器
```

### 客户端应用构建
```bash
cd /Users/CodeProjects/VoiceX/client/VoiceX
./build_release.sh           # 构建Release版本
open ./release/VoiceX.app    # 运行应用
```

### 开发调试流程
1. 确保Worker服务运行: `./run_worker.sh status`
2. 修改客户端代码
3. 构建新版本: `./build_release.sh`
4. 测试菜单栏应用: `open ./release/VoiceX.app`
5. 验证功能: 语音识别 + 文本注入 + 应用检测
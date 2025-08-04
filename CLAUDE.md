# VoiceX 项目开发记录

## 项目概述

VoiceX 是一个基于 FunASR、Docker 和 `launchd` 的 macOS 实时听写应用，采用"Worker-Supervisor-Client"三层架构，具备 7x24 小时不间断运行能力。

## 第一阶段：Worker 核心引擎 ✅ 已完成

**目标**: 创建包含 FunASR 模型的 Docker 容器，支持 WebSocket 流式识别  
**完成时间**: 2025年8月4日  
**状态**: ✅ 成功完成并验证

### 实现成果

#### 1. 核心文件结构
```
/worker/
├── Dockerfile              # Docker镜像构建文件
├── README.md              # 使用说明文档  
├── run_worker.sh          # 容器管理脚本
├── start_server.sh        # 服务启动脚本（关键修复）
└── models/                # 模型文件目录
    ├── damo/             # 达摩院模型集合
    └── thuduj12/         # 清华大学ITN模型
```

#### 2. 服务配置
- **容器名称**: voicex-worker-container
- **端口映射**: localhost:10096 → 容器内10095
- **协议**: WebSocket over SSL/TLS
- **资源限制**: 32GB内存，8核CPU
- **重启策略**: unless-stopped（自动重启）

#### 3. 已加载模型
- ✅ VAD语音活动检测: `speech_fsmn_vad_zh-cn-16k-common-onnx`
- ✅ 在线ASR模型: `speech_paraformer-large_asr_nat-zh-cn-16k-common-vocab8404-online-onnx`  
- ✅ 离线ASR模型: `speech_paraformer-large_asr_nat-zh-cn-16k-common-vocab8404-onnx`
- ✅ 标点符号模型: `punc_ct-transformer_zh-cn-common-vad_realtime-vocab272727-onnx`
- ✅ 语言模型: `speech_ngram_lm_zh-cn-ai-wesp-fst`
- ✅ ITN模型: `fst_itn_zh`

### 关键技术突破

#### 问题1: 容器持续重启 
**原因**: 原始`run_server_2pass.sh`脚本使用后台运行(`&`)，导致主进程立即退出  
**解决**: 创建`start_server.sh`使用`exec`前台运行，确保容器主进程持续存在

#### 问题2: 健康检查配置冲突
**原因**: Dockerfile与run_worker.sh中健康检查时间参数不一致  
**解决**: 统一设置启动宽限期为180秒，匹配模型加载时间

#### 问题3: 模型路径错误
**原因**: 某些模型目录结构不匹配  
**解决**: 修正Dockerfile中的模型路径参数

### 服务验证结果

```bash
# 容器状态检查
docker ps
# 结果: Up X minutes (healthy) - 稳定运行

# 服务日志确认  
docker logs voicex-worker-container --tail 10
# 结果: 所有模型成功加载，服务监听10095端口
```

**最终状态**: 🟢 服务稳定运行，支持WebSocket连接，所有模型加载成功

## 使用方法

### 基本操作
```bash
cd /Users/CodeProjects/VoiceX/worker

# 启动服务
./run_worker.sh

# 管理服务  
./run_worker.sh stop      # 停止
./run_worker.sh restart   # 重启
./run_worker.sh logs      # 查看日志
./run_worker.sh status    # 检查状态
./run_worker.sh clean     # 清理资源
```

### 服务持久化特性
- ✅ 关闭终端不影响服务运行
- ✅ 系统重启后自动恢复运行  
- ✅ 异常退出时自动重启
- ❌ 仅手动停止才会终止服务

## 下一阶段计划

### 第二阶段：Supervisor 守护服务
**目标**: 使用macOS `launchd`实现容器自动化管理  
**预计完成**: 2025年8月8日  
**任务**: 编写.plist配置，实现永不宕机的守护进程

### 第三阶段：Client 客户端应用  
**目标**: 开发macOS App，实现音频采集和WebSocket连接  
**预计完成**: 2025年8月14日  
**任务**: AVFoundation音频处理 + Network框架TCP连接

### 第四阶段：功能集成与优化
**目标**: 完成"隔空打字"功能和压力测试  
**预计完成**: 2025年8月19日  
**任务**: CGEvent键盘模拟 + 稳定性验证

## 技术栈

- **容器化**: Docker + FunASR官方镜像
- **语音识别**: 阿里云FunASR（支持中文、实时、高精度）
- **通信协议**: WebSocket over SSL/TLS  
- **系统集成**: macOS launchd + AVFoundation + Network框架
- **版本控制**: Git

## 项目里程碑

- [x] **2025.08.04** - 第一阶段完成：Worker核心引擎稳定运行
- [ ] **2025.08.08** - 第二阶段：Supervisor守护服务
- [ ] **2025.08.14** - 第三阶段：Client客户端应用  
- [ ] **2025.08.19** - 第四阶段：功能集成完成

---

*本文档将在每个阶段完成后更新，记录关键技术决策和实现细节。*